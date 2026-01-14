import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../api/auth_signup.dart';
import '../api/auth_email_verif.dart'; // 🔥 nouveau
import 'feed_page.dart';
import 'signup_pro_page.dart';

class SignupUserPage extends StatefulWidget {
  const SignupUserPage({super.key});

  @override
  State<SignupUserPage> createState() => _SignupUserPageState();
}

class _SignupUserPageState extends State<SignupUserPage> {
  static const primary = Color(0xFF1877F2);

  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _data = {};

  bool _isAtLeast13YearsOld(String dateStr) {
    try {
      final birth = DateTime.parse(dateStr);
      final now = DateTime.now();

      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }

      return age >= 13;
    } catch (_) {
      return false;
    }
  }

  int _step = 1;
  bool _loading = false;
  String? _message;
  bool _showPassword = false;
  bool _returnToSummary = false; // 🔁 revenir auto à l’étape résumé
  bool _termsAccepted = false;

  // Controllers
  final _birthCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _codeCtrl = TextEditingController(); // 🔥 code de vérification

  // Sexe
  String? _selectedSexe;
  bool _sexError = false;

  // Pays
  List<String> _countries = [];
  String? _selectedCountry;
  bool _loadingCountries = false;

  // Password rules
  bool _passHasUpper = false;
  bool _passHasDigit = false;
  bool _passHasSymbol = false;
  bool _passHasLength = false;
  bool _passMatch = false;

  // 🔥 Vérification email
  bool _emailVerified = false;
  bool _emailCodeSent = false;
  String? _pendingEmail;
  int _remainingSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initBirthDefault();
    _loadCountries();
  }

  void _initBirthDefault() {
    final now = DateTime.now();
    _birthCtrl.text = _formatDate(now);
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadCountries() async {
    setState(() => _loadingCountries = true);
    try {
      final raw = await rootBundle.loadString('assets/pays.json');
      final List<dynamic> list = jsonDecode(raw);
      setState(() {
        _countries = list.map((e) => e.toString()).toList();
      });
    } catch (e) {
      print('⚠️ Erreur lecture pays.json: $e');
    } finally {
      setState(() => _loadingCountries = false);
    }
  }

  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();

    // 🔒 Date maximale autorisée = aujourd’hui - 13 ans
    final lastAllowedDate = DateTime(
      now.year - 13,
      now.month,
      now.day,
    );

    final date = await showDatePicker(
      context: context,
      initialDate: lastAllowedDate, // 👈 logique et UX propre
      firstDate: DateTime(1900, 1, 1),
      lastDate: lastAllowedDate, // 🔥 BLOQUAGE VISUEL < 13 ans
    );

    if (date != null) {
      _birthCtrl.text = _formatDate(date);
      setState(() {});
    }
  }

  void _updatePasswordRules() {
    final v = _passCtrl.text;
    _passHasUpper = RegExp(r'[A-Z]').hasMatch(v);
    _passHasDigit = RegExp(r'[0-9]').hasMatch(v);
    _passHasSymbol = RegExp(r'[\W]').hasMatch(v);
    _passHasLength = v.length >= 6; // tu peux mettre 8 si tu veux
    _passMatch = v.isNotEmpty && v == _confirmCtrl.text;
  }

  // ===========================
  // 🔥 TIMER EMAIL (2 minutes)
  // ===========================
  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = seconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds <= 1) {
        t.cancel();
        setState(() {
          _remainingSeconds = 0;
        });
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // ===========================
  // NAVIGATION / BOUTON SUIVANT
  // ===========================
  Future<void> _nextOrSubmit() async {
    FocusScope.of(context).unfocus();

    // Étape finale = création compte
    if (_step == 6) {
      await _submit();
      return;
    }

    // Étape spéciale 5 = vérification code email
    if (_step == 5) {
      await _verifyEmailStep();
      return;
    }

    // Pour les autres étapes : validation formulaire
    if (!_formKey.currentState!.validate()) return;

    // Validations custom par étape
    if (_step == 2) {
      final birth = _birthCtrl.text;

      if (!_isAtLeast13YearsOld(birth)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Vous devez avoir au moins 13 ans pour créer un compte ZuaChat.",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (_step == 3) {
      if (_selectedCountry == null || _selectedCountry!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veuillez sélectionner un pays."),
          ),
        );
        return;
      }
    }

    _formKey.currentState!.save();

    // Gestion des étapes
    if (_step == 4) {
      // 🔥 Étape 4 : email + mot de passe → envoyer le code + passer à 5
      await _sendEmailCodeStep();
      return;
    }

    // Étapes 1 → 3 : avancer simplement
    if (_returnToSummary) {
      setState(() {
        _step = 6; // retour direct au résumé après corrections
        _returnToSummary = false;
      });
    } else {
      setState(() => _step++);
    }
  }

  // ============================================================
  // 🔥 ENVOI DU CODE (après remplissage email + mdp - étape 4)
  // ============================================================
  Future<void> _sendEmailCodeStep() async {
    final email = (_data['email'] ?? '') as String? ?? '';

    if (email.isEmpty) {
      setState(() {
        _message = "Email obligatoire.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
      _emailVerified = false;
      _emailCodeSent = false;
    });

    try {
      await apiSendEmailCode(email).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception(
            "Temps d’attente dépassé. Vérifiez votre connexion internet.",
          );
        },
      );

      setState(() {
        _pendingEmail = email;
        _emailCodeSent = true;
        _message = "Un code a été envoyé à $email.";
        _step = 5; // aller à l’étape de vérification
      });

      _startTimer(120); // 2 minutes
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _message = e.toString().replaceFirst('Exception: ', '');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_message!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // 🔥 VÉRIFICATION DU CODE (étape 5)
  // ============================================================
Future<void> _verifyEmailStep() async {
  if (_pendingEmail == null || _pendingEmail!.isEmpty) {
    if (!mounted) return;
    setState(() {
      _message = "Email introuvable, veuillez revenir à l’étape précédente.";
      _step = 4;
    });
    return;
  }

  final code = _codeCtrl.text.trim();
  if (code.isEmpty) {
    setState(() {
      _message = "Veuillez entrer le code reçu par email.";
    });
    return;
  }

  if (_remainingSeconds == 0) {
    setState(() {
      _message = "Le code a expiré, veuillez renvoyer un nouveau code.";
    });
    return;
  }

  setState(() {
    _loading = true;
    _message = null;
  });

  try {
    await apiVerifyEmailCode(_pendingEmail!, code).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw Exception(
          "Impossible de vérifier le code. Vérifiez votre connexion.",
        );
      },
    );

    if (!mounted) return;
    _timer?.cancel();

    setState(() {
      _loading = false;
      _emailVerified = true;
      _message = "Email vérifié avec succès";
      _step = 6;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _loading = false;
      _message = e.toString().replaceFirst('Exception: ', '');
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_message!),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  // ============================================================
  // SOUMISSION FINALE
  // ============================================================
  Future<void> _submit() async {
    // Ici, on est en étape 6 (résumé)
    // On vérifie quand même l’email
    if (!_termsAccepted) {
      setState(() {
        _message =
            "Vous devez accepter les Conditions d’utilisation et la Politique de confidentialité.";
      });
      return;
    }

    if (!_emailVerified) {
      setState(() {
        _message = "Veuillez vérifier votre email avant de créer le compte.";
        _step = 5;
      });
      return;
    }

    _data['type'] = 'simple';
    _data['date_naissance'] = _birthCtrl.text;
    _data['sexe'] = _selectedSexe;
    _data['pays'] = _selectedCountry;

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await apiSignup(_data);

      if (!mounted) return;

      setState(() {
        _message = "Compte créé avec succès";
      });

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const FeedPage()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _message = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ============================================================
  // UI - Étapes
  // ============================================================
  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _buildStep1Identite();
      case 2:
        return _buildStep2NaissanceSexe();
      case 3:
        return _buildStep3PaysTel();
      case 4:
        return _buildStep4EmailPassword();
      case 5:
        return _buildStep5VerifyEmail();
      case 6:
        return _buildStep6Resume();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1Identite() {
    return Column(
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Prénom',
          ),
          textInputAction: TextInputAction.next,
          onSaved: (v) => _data['prenom'] = v?.trim(),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Nom',
          ),
          textInputAction: TextInputAction.next,
          onSaved: (v) => _data['nom'] = v?.trim(),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Post-nom (optionnel)',
          ),
          textInputAction: TextInputAction.done,
          onSaved: (v) => _data['postnom'] = v?.trim(),
        ),
      ],
    );
  }

  Widget _buildStep2NaissanceSexe() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _birthCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Date de naissance',
            hintText: 'AAAA-MM-JJ',
            suffixIcon: Icon(Icons.calendar_today_outlined),
          ),
          onTap: _pickBirthDate,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Date obligatoire' : null,
        ),
        const SizedBox(height: 16),
        const Text(
          "Sexe (optionnel)",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Homme'),
              selected: _selectedSexe == 'Homme',
              selectedColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.15),
              onSelected: (sel) {
                setState(() {
                  _selectedSexe = sel ? 'Homme' : null;
                  _sexError = false;
                });
              },
              avatar: Icon(
                Icons.male,
                color: _selectedSexe == 'Homme'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).iconTheme.color,
              ),
            ),
            ChoiceChip(
              label: const Text('Femme'),
              selected: _selectedSexe == 'Femme',
              selectedColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.15),
              onSelected: (sel) {
                setState(() {
                  _selectedSexe = sel ? 'Femme' : null;
                  _sexError = false;
                });
              },
              avatar: Icon(
                Icons.female,
                color: _selectedSexe == 'Femme'
                    ? const Color.fromARGB(255, 255, 0, 0)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3PaysTel() {
    if (_loadingCountries && _countries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Pays',
            prefixIcon: Icon(Icons.public),
          ),
          value: _selectedCountry,
          items: _countries
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(c),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() => _selectedCountry = v);
          },
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Sélectionnez un pays' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Téléphone (optionnel)',
            prefixIcon: Icon(Icons.phone_iphone),
          ),
          keyboardType: TextInputType.phone,
          onSaved: (v) => _data['telephone'] = v?.trim(),
        ),
      ],
    );
  }

  Widget _buildStep4EmailPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          onSaved: (v) => _data['email'] = v?.trim(),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Email obligatoire';
            }
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
              return 'Email invalide';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passCtrl,
          obscureText: !_showPassword,
          onChanged: (v) {
            setState(() {
              _updatePasswordRules();
            });
          },
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() => _showPassword = !_showPassword);
              },
            ),
          ),
          onSaved: (v) => _data['password'] = v,
          validator: (v) {
            final value = v ?? '';
            if (value.length < 6) {
              return '6 caractères minimum';
            }
            if (!RegExp(r'[A-Z]').hasMatch(value)) {
              return 'Au moins 1 majuscule';
            }
            if (!RegExp(r'[0-9]').hasMatch(value)) {
              return 'Au moins 1 chiffre';
            }
            if (!RegExp(r'[\W]').hasMatch(value)) {
              return 'Au moins 1 symbole';
            }
            return null;
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _confirmCtrl,
          obscureText: !_showPassword,
          onChanged: (v) {
            setState(() {
              _updatePasswordRules();
            });
          },
          decoration: const InputDecoration(
            labelText: 'Confirmer le mot de passe',
            prefixIcon: Icon(Icons.lock_reset),
          ),
          validator: (v) {
            if (v != _passCtrl.text) {
              return 'Les mots de passe ne correspondent pas';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _buildPasswordRulesWidget(),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildStep5VerifyEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pendingEmail != null)
          Text(
            "Un code de vérification a été envoyé à :\n$_pendingEmail",
            style: const TextStyle(fontSize: 14),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_remainingSeconds > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    Text(
                      "Expire dans ${_formatDuration(_remainingSeconds)}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text(
                "Le code a expiré, renvoyez un nouveau code.",
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _codeCtrl,
          decoration: const InputDecoration(
            labelText: 'Code reçu par email',
            prefixIcon: Icon(Icons.verified_outlined),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      // 👉 Retour pour changer l'email
                      setState(() {
                        _step = 4;
                        _emailCodeSent = false;
                        _emailVerified = false;
                        _timer?.cancel();
                        _remainingSeconds = 0;
                        _codeCtrl.clear();
                      });
                    },
              child: const Text("Modifier l'email"),
            ),
            const Spacer(),
            TextButton(
              onPressed: (_loading || _pendingEmail == null)
                  ? null
                  : () async {
                      if (_pendingEmail == null) return;
                      await _sendEmailCodeStep();
                    },
              child: const Text("Renvoyer le code"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordRulesWidget() {
    Widget buildRow(bool ok, String text) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                ok ? Icons.check_circle : Icons.radio_button_unchecked,
                key: ValueKey<bool>(ok),
                size: 18,
                color: ok ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: ok
                    ? Colors.green
                    : Theme.of(context).textTheme.bodySmall!.color,
                fontWeight: ok ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Le mot de passe doit contenir :",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        buildRow(_passHasLength, "6 caractères minimum"),
        buildRow(_passHasUpper, "1 majuscule"),
        buildRow(_passHasDigit, "1 chiffre"),
        buildRow(_passHasSymbol, "1 symbole"),
        buildRow(_passMatch, "Confirmation identique"),
      ],
    );
  }

  Widget _buildStep6Resume() {
    final prenom = (_data['prenom'] ?? '') as String;
    final nom = (_data['nom'] ?? '') as String? ?? '';
    final postnom = (_data['postnom'] ?? '') as String? ?? '';
    final fullName =
        [prenom, nom, postnom].where((e) => e.trim().isNotEmpty).join(' ');

    final email = (_data['email'] ?? '') as String? ?? '';
    final tel = (_data['telephone'] ?? '') as String? ?? '';
    final dn = _birthCtrl.text;
    final sexe = _selectedSexe ?? '';
    final pays = _selectedCountry ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Vérifiez vos informations avant de créer le compte :",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _resumeTile(
          title: "Nom complet",
          value: fullName.isEmpty ? "Non renseigné" : fullName,
          onEdit: () {
            setState(() {
              _step = 1;
              _returnToSummary = true;
            });
          },
        ),
        _resumeTile(
          title: "Date de naissance",
          value: dn,
          onEdit: () {
            setState(() {
              _step = 2;
              _returnToSummary = true;
            });
          },
        ),
        _resumeTile(
          title: "Sexe",
          value: sexe.isEmpty ? "Non renseigné" : sexe,
          onEdit: () {
            setState(() {
              _step = 2;
              _returnToSummary = true;
            });
          },
        ),
        _resumeTile(
          title: "Pays",
          value: pays.isEmpty ? "Non renseigné" : pays,
          onEdit: () {
            setState(() {
              _step = 3;
              _returnToSummary = true;
            });
          },
        ),
        _resumeTile(
          title: "Téléphone",
          value: tel.isEmpty ? "Non renseigné" : tel,
          onEdit: () {
            setState(() {
              _step = 3;
              _returnToSummary = true;
            });
          },
        ),
        _resumeTile(
          title: "Email",
          value: email.isEmpty ? "Non renseigné" : email,
          onEdit: () {
            setState(() {
              _step = 4;
              _returnToSummary = true;
              _emailVerified = false;
              _emailCodeSent = false;
              _timer?.cancel();
              _remainingSeconds = 0;
              _codeCtrl.clear();
            });
          },
        ),
        _resumeTile(
          title: "Mot de passe",
          value: "********",
          onEdit: () {
            setState(() {
              _step = 4;
              _returnToSummary = true;
            });
          },
        ),
        const SizedBox(height: 12),
        const Text(
          "Si tout est correct, cliquez sur « Créer mon compte » pour continuer.",
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _termsAccepted,
              onChanged: (v) {
                setState(() {
                  _termsAccepted = v ?? false;
                });
              },
            ),
            Expanded(
              child: Wrap(
                children: [
                  const Text(
                    "J’accepte les ",
                    style: TextStyle(fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(
                        "https://aide.zuachat.com/conditions.php",
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: const Text(
                      "Conditions d’utilisation",
                      style: TextStyle(
                        fontSize: 13,
                        color: Color.fromARGB(255, 255, 0, 0),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Text(" et la ", style: TextStyle(fontSize: 13)),
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(
                        "https://aide.zuachat.com/politique.php",
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: const Text(
                      "Politique de confidentialité",
                      style: TextStyle(
                        fontSize: 13,
                        color: Color.fromARGB(255, 255, 0, 0),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Text(".", style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resumeTile({
    required String title,
    required String value,
    required VoidCallback onEdit,
  }) {
    return Card(
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 13),
        ),
        trailing: TextButton(
          onPressed: onEdit,
          child: const Text(
            "Modifier",
            style: TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  void dispose() {
    _birthCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _codeCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const stepCount = 6; // 🔥 maintenant 6 étapes
    final progress = _step / stepCount;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 0, 0),
        title: const Text('Créer un compte'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Compte utilisateur',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 255, 0, 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Theme.of(context).dividerColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color.fromARGB(255, 255, 0, 0)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Étape $_step / $stepCount',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _message!.contains('succès') ||
                                  _message!.contains('réussi') ||
                                  _message!.contains('vérifié')
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  _buildStep(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading || (_step == 6 && !_termsAccepted)
                          ? null
                          : () async {
                              await _nextOrSubmit();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 255, 0, 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _step == 6
                                  ? 'Créer mon compte'
                                  : _step == 5
                                      ? 'Vérifier le code'
                                      : 'Suivant',
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Déjà inscrit ? Se connecter',
                      style: TextStyle(color: Color.fromARGB(255, 255, 0, 0)),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignupProPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Créer un compte professionnel',
                      style: TextStyle(color: Color.fromARGB(255, 255, 0, 0)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
