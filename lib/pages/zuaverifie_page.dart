import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../api/client.dart';
import '../widgets/zua_loader.dart';
import '../widgets/zua_loader_mini.dart';
import '../widgets/verified_badge.dart';

import 'profile_page.dart';
import 'help_page.dart';

class ZuaVerifiePage extends StatefulWidget {
  const ZuaVerifiePage({super.key});

  @override
  State<ZuaVerifiePage> createState() => _ZuaVerifiePageState();
}

class _ZuaVerifiePageState extends State<ZuaVerifiePage>
    with SingleTickerProviderStateMixin {
  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  static const Color red = Color(0xFFFF0000);
  static const Color bg = Color(0xFFF0F2F5);

  // --------------------------------------------------
  // STATE GLOBAL
  // --------------------------------------------------
  bool loading = true;
  bool sending = false;

  Map<String, dynamic> user = {};
  Map<String, dynamic>? badgeRequest;

  bool alreadyVerified = false;
  bool pending = false;

  // --------------------------------------------------
  // ÉTAPES
  // --------------------------------------------------
  int step = 1; // 1=progress,2=checks,3=conditions,4=justif,5=lien,6=piece
  int progress = 0;
  Timer? progressTimer;
  int progressMsgIndex = 0;

  final List<String> progressMessages = [
    'Vérification de votre compte…',
    'Vérification de votre âge…',
    'Vérification de votre numéro…',
    'Analyse de votre profil…',
    'Contrôle des informations…',
  ];

  // --------------------------------------------------
  // RULES CHECK
  // --------------------------------------------------
  bool ageOk = false;
  bool phoneOk = false;
  bool photoOk = false;
  bool coverOk = false;

  bool conditionsAccepted = false;

  // --------------------------------------------------
  // FORM
  // --------------------------------------------------
  final TextEditingController justificationCtrl = TextEditingController();
  final TextEditingController linkCtrl = TextEditingController();
  File? pieceFile;
  String pieceType = 'passport';

  final ImagePicker picker = ImagePicker();

  // --------------------------------------------------
  // INIT
  // --------------------------------------------------
  @override
  void initState() {
    super.initState();
    _startProgress();
    _loadStatus();
  }

  @override
  void dispose() {
    progressTimer?.cancel();
    justificationCtrl.dispose();
    linkCtrl.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // PROGRESS 0 → 100 (≈10s)
  // --------------------------------------------------
  void _startProgress() {
    progressTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (progress >= 100) {
        t.cancel();
        _runChecks();
        setState(() => step = 2);
      } else {
        setState(() {
          progress++;
          if (progress % 20 == 0) {
            progressMsgIndex =
                (progressMsgIndex + 1) % progressMessages.length;
          }
        });
      }
    });
  }

  // --------------------------------------------------
  // LOAD STATUS (GET zuaverifie.php)
  // --------------------------------------------------
  Future<void> _loadStatus() async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.get('/zuaverifie.php');

      if (res.data['success'] == true) {
        user = Map<String, dynamic>.from(res.data['data']['user']);
        badgeRequest = res.data['data']['badge_request'];

        alreadyVerified = user['badge_verified'] == 1;
        pending = badgeRequest != null &&
            badgeRequest!['status'] == 'pending';
      }
    } catch (_) {
      _toast('Erreur chargement vérification', true);
    } finally {
      setState(() => loading = false);
    }
  }

  // --------------------------------------------------
  // CHECK RULES
  // --------------------------------------------------
  void _runChecks() {
    _checkAge();
    _checkPhone();
    _checkPhotos();
  }

  void _checkAge() {
    try {
      final dob = DateTime.parse(user['date_naissance']);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      ageOk = age >= 18;
    } catch (_) {
      ageOk = false;
    }
  }

  void _checkPhone() {
    final raw = (user['telephone'] ?? '').toString();
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    phoneOk = digits.length >= 10;
  }

  void _checkPhotos() {
    photoOk = !user['photo'].toString().contains('default');
    coverOk = !user['couverture'].toString().contains('default');
  }

  bool get allChecksOk => ageOk && phoneOk && photoOk && coverOk;
  bool get isRdc => user['pays'] == 'Congo (RDC)';

  // --------------------------------------------------
  // PICK FILE
  // --------------------------------------------------
  Future<void> _pickFile() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (picked == null) return;
    setState(() => pieceFile = File(picked.path));
  }

  // --------------------------------------------------
  // SUBMIT (POST zuaverifie.php)
  // --------------------------------------------------
  Future<void> _submit() async {
    if (sending) return;

    if (!conditionsAccepted) {
      _toast('Veuillez accepter les conditions', true);
      return;
    }

    if (justificationCtrl.text.trim().length < 120) {
      _toast('120 caractères minimum requis', true);
      return;
    }

    if (linkCtrl.text.isNotEmpty &&
        !linkCtrl.text.startsWith('https://')) {
      _toast('Lien invalide (https:// requis)', true);
      return;
    }

    if (pieceFile == null) {
      _toast('Veuillez joindre une pièce', true);
      return;
    }

    setState(() => sending = true);

    try {
      final dio = await ApiClient.authed();
      final form = FormData.fromMap({
        'nom_complet':
            '${user['prenom'] ?? ''} ${user['nom'] ?? ''}'.trim(),
        'username': user['username'],
        'categorie': user['categorie'] ?? '',
        'justification': justificationCtrl.text.trim(),
        'liens': linkCtrl.text.trim(),
        'pays': user['pays'],
        'piece': await MultipartFile.fromFile(pieceFile!.path),
      });

      final res = await dio.post('/zuaverifie.php', data: form);

      if (res.data['success'] == true) {
        setState(() => pending = true);
      } else {
        _toast(res.data['message'] ?? 'Erreur serveur', true);
      }
    } catch (_) {
      _toast('Erreur envoi demande', true);
    } finally {
      setState(() => sending = false);
    }
  }

  // --------------------------------------------------
  // TOAST
  // --------------------------------------------------
  void _toast(String msg, bool error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  // --------------------------------------------------
  // UI SCREENS
  // --------------------------------------------------
  Widget _progressView() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(value: progress / 100, color: red),
            const SizedBox(height: 12),
            Text('${progressMessages[progressMsgIndex]}'),
            const SizedBox(height: 6),
            Text('$progress %'),
          ],
        ),
      );

  Widget _pendingView() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            VerifiedBadge(isVerified: false, size: 80),
            SizedBox(height: 12),
            Text(
              'Votre demande est en cours de vérification (48h)',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  // --------------------------------------------------
  // BUILD
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: red,
        title: const Text('Zua Vérifie',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: loading
          ? const ZuaLoader(looping: true)
          : alreadyVerified
              ? const Center(
                  child: VerifiedBadge(isVerified: true, size: 100))
              : pending
                  ? _pendingView()
                  : step == 1
                      ? _progressView()
                      : step == 2
                          ? _checksView()
                          : step == 3
                              ? _conditionsView()
                              : step == 4
                                  ? _justificationView()
                                  : step == 5
                                      ? _linkView()
                                      : _pieceView(),
    );
  }

  // --------------------------------------------------
  // STEP VIEWS
  // --------------------------------------------------
  Widget _checksView() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _rule('Âge ≥ 18 ans', ageOk),
          _rule('Téléphone ≥ 10 chiffres', phoneOk),
          _rule('Photo de profil valide', photoOk),
          _rule('Photo de couverture valide', coverOk),
          const SizedBox(height: 16),
          if (!allChecksOk)
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: red),
              child: const Text('Modifier mon profil'),
            )
          else
            ElevatedButton(
              onPressed: () => setState(() => step = 3),
              style: ElevatedButton.styleFrom(backgroundColor: red),
              child: const Text('Continuer'),
            ),
        ],
      );

  Widget _conditionsView() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Conditions', style: TextStyle(fontSize: 18)),
          CheckboxListTile(
            value: conditionsAccepted,
            onChanged: (v) => setState(() => conditionsAccepted = v ?? false),
            title: const Text('J’accepte les conditions de vérification'),
          ),
          ElevatedButton(
            onPressed: conditionsAccepted
                ? () => setState(() => step = 4)
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: red),
            child: const Text('Continuer'),
          ),
        ],
      );

  Widget _justificationView() => _simpleForm(
        'Justification (${justificationCtrl.text.length}/120)',
        justificationCtrl,
        () => setState(() => step = 5),
      );

  Widget _linkView() => _simpleForm(
        'Lien officiel (https://)',
        linkCtrl,
        () => setState(() => step = 6),
      );

  Widget _pieceView() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isRdc)
            DropdownButtonFormField<String>(
              value: pieceType,
              items: const [
                DropdownMenuItem(value: 'passport', child: Text('Passeport')),
                DropdownMenuItem(value: 'carte', child: Text('Carte identité')),
              ],
              onChanged: (v) => setState(() => pieceType = v!),
            ),
          ElevatedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Choisir la pièce'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: sending ? null : _submit,
            icon: sending ? const ZuaLoaderMini() : const Icon(Icons.send),
            label: const Text('Envoyer la demande'),
            style: ElevatedButton.styleFrom(backgroundColor: red),
          ),
        ],
      );

  Widget _rule(String label, bool ok) => ListTile(
        leading: Icon(ok ? Icons.check_circle : Icons.cancel,
            color: ok ? Colors.green : Colors.red),
        title: Text(label),
      );

  Widget _simpleForm(
    String label,
    TextEditingController ctrl,
    VoidCallback next,
  ) =>
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: ctrl,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration:
                InputDecoration(labelText: label, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: next,
            style: ElevatedButton.styleFrom(backgroundColor: red),
            child: const Text('Continuer'),
          ),
        ],
      );
}
