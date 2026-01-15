import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../api/auth_signup.dart';
import '../api/auth_email_verif.dart'; // 🔥 nouveau
import 'feed_page.dart';
import 'signup_user_page.dart';

class SignupProPage extends StatefulWidget {
  const SignupProPage({super.key});

  @override
  State<SignupProPage> createState() => _SignupProPageState();
}

class _SignupProPageState extends State<SignupProPage> {
  static const primary = Color.fromARGB(255, 255, 0, 0);

  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _data = {};

  int _step = 1;
  bool _loading = false;
  String? _message;
  bool _showPassword = false;
  bool _returnToSummary = false;

  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  // Pays & catégories
  List<String> _countries = [];
  List<String> _categories = [];
  String? _selectedCountry;
  String? _selectedCategory;
  bool _loadingCountries = false;
  bool _loadingCategories = false;
  bool _termsAccepted = false;

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
    _loadCountries();
    _loadCategories();
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
      print('⚠️ Erreur pays.json: $e');
    } finally {
      setState(() => _loadingCountries = false);
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final raw = await rootBundle.loadString('assets/categories.json');
      final List<dynamic> list = jsonDecode(raw);
      setState(() {
        _categories = list.map((e) => e.toString()).toList();
      });
    } catch (e) {
      print('⚠️ Erreur categories.json: $e');
    } finally {
      setState(() => _loadingCategories = false);
    }
  }

  void _updatePasswordRules() {
    final v = _passCtrl.text;
    _passHasUpper = RegExp(r'[A-Z]').hasMatch(v);
    _passHasDigit = RegExp(r'[0-9]').hasMatch(v);
    _passHasSymbol = RegExp(r'[\W]').hasMatch(v);
    _passHasLength = v.length >= 6;
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

    if (_step == 6) {
      await _submit();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // Validations custom
    if (_step == 2) {
      if (_selectedCountry == null || _selectedCountry!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veuillez sélectionner un pays."),
          ),
        );
        return;
      }
    }

    if (_step == 1) {
      if (_selectedCategory == null || _selectedCategory!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veuillez sélectionner une catégorie."),
          ),
        );
        return;
      }
    }

    _formKey.currentState!.save();

    if (_step == 4) {
      // 🔥 après mot de passe → envoyer code email
      await _sendEmailCodeStep();
      return;
    }

    if (_returnToSummary) {
      setState(() {
        _step = 6;
        _returnToSummary = false;
      });
    } else {
      setState(() => _step++);
    }
  }

  // ============================================================
  // 🔥 ENVOI CODE EMAIL (étape 4 terminée)
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

      if (!mounted) return;

      setState(() {
        _pendingEmail = email;
        _emailCodeSent = true;
        _message = "Un code a été envoyé à $email.";
        _step = 5;
      });

      _startTimer(120);
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
  // 🔥 VERIFICATION CODE EMAIL (étape 5)
  // ============================================================
  Future<void> _verifyEmailStep() async {
    if (_pendingEmail == null || _pendingEmail!.isEmpty) {
      setState(() {
        _message = "Email introuvable, veuillez revenir à l’étape 3.";
        _step = 3;
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
      await apiVerifyEmailCode(_pendingEmail!, code);
      _timer?.cancel();

      setState(() {
        _emailVerified = true;
        _message = "Email vérifié avec succès";
        _step = 6;
      });
    } catch (e) {
      setState(() {
        _message = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // ============================================================
  // SOUMISSION FINALE
  // ============================================================
  Future<void> _submit() async {
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

    if (_selectedCountry == null || _selectedCountry!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner un pays."),
        ),
      );
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner une catégorie."),
        ),
      );
      return;
    }

    _formKey.currentState!.save();

    _data['type'] = 'pro';
    _data['pays'] = _selectedCountry;
    _data['categorie'] = _selectedCategory;

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await apiSignup(_data);

      if (!mounted) return;

      setState(() {
        _message = "Compte entreprise créé avec succès";
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
        return _buildStep1Entreprise();
      case 2:
        return _buildStep2PaysTel();
      case 3:
        return _buildStep3Email();
      case 4:
        return _buildStep4Password();
      case 5:
        return _buildStep5VerifyEmail();
      case 6:
        return _buildStep6Resume();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1Entreprise() {
    return Column(
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: "Nom de l'entreprise",
            prefixIcon: Icon(Icons.business),
          ),
          textInputAction: TextInputAction.next,
          onSaved: (v) => _data['nom'] = v?.trim(),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
        ),
        const SizedBox(height: 10),
        if (_loadingCategories && _categories.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            ),
          )
        else
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Catégorie',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            value: _selectedCategory,
            items: _categories
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(c),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() => _selectedCategory = v);
            },
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Sélectionnez une catégorie' : null,
          ),
      ],
    );
  }

  Widget _buildStep2PaysTel() {
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

  Widget _buildStep3Email() {
    return TextFormField(
      decoration: const InputDecoration(
        labelText: 'Email professionnel',
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
    );
  }

  Widget _buildStep4Password() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    const Icon(Icons.timer_outlined,
                        size: 16, color: Colors.red),
                    const SizedBox(width: 6),
                    Text(
                      "Expire dans ${_formatDuration(_remainingSeconds)}",
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.red,
                          fontWeight: FontWeight.w600),
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
                      setState(() {
                        _step = 3; // revenir à l’email
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
              onPressed: _loading || _pendingEmail == null
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
                color: ok ? Colors.green : Colors.grey.shade700,
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
    final nom = (_data['nom'] ?? '') as String? ?? '';
    final email = (_data['email'] ?? '') as String? ?? '';
    final tel = (_data['telephone'] ?? '') as String? ?? '';
    final pays = _selectedCountry ?? '';
    final categorie = _selectedCategory ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Vérifiez les informations de votre entreprise :",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _resumeTile(
          title: "Nom de l'entreprise",
          value: nom.isEmpty ? "Non renseigné" : nom,
          onEdit: () {
            setState(() {
              _step = 1;
              _returnToSummary = true;
            });
          },
        ),
        _resumeTile(
          title: "Catégorie",
          value: categorie.isEmpty ? "Non renseigné" : categorie,
          onEdit: () {
            setState(() {
              _step = 1;
              _returnToSummary = true;
            });
          },
        ),
        _resumeTile(
          title: "Pays",
          value: pays.isEmpty ? "Non renseigné" : pays,
          onEdit: () {
            setState(() {
              _step = 2;
              _returnToSummary = true;
            });
          },
        ),
        _resumeTile(
          title: "Téléphone",
          value: tel.isEmpty ? "Non renseigné" : tel,
          onEdit: () {
            setState(() {
              _step = 2;
              _returnToSummary = true;
            });
          },
        ),
        _resumeTile(
          title: "Email",
          value: email.isEmpty ? "Non renseigné" : email,
          onEdit: () {
            setState(() {
              _step = 3;
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
                alignment: WrapAlignment.start,
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
                        color: primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Text(
                    " et la ",
                    style: TextStyle(fontSize: 13),
                  ),
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
                        color: primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Text(
                    ".",
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Text(
          "Si tout est correct, cliquez sur « Créer le compte entreprise » pour continuer.",
          style: TextStyle(fontSize: 13),
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
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _codeCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const stepCount = 6;
    final progress = _step / stepCount;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 0, 0),
        foregroundColor: Colors.white,
        title: const Text('Compte professionnel'),
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
                      Icon(Icons.business_center, color: colorScheme.primary),
                      SizedBox(width: 8),
                      Text(
                        'Compte Entreprise / Pro',
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
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Étape $_step / $stepCount',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
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
                              if (_step == 5) {
                                await _verifyEmailStep(); // 👈 UNIQUE appel
                              } else {
                                await _nextOrSubmit();
                              }
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
                                  ? 'Créer le compte entreprise'
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
                      'Vous avez déjà un compte ? Se connecter',
                      style: TextStyle(color: primary),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignupUserPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Créer un compte utilisateur',
                      style: TextStyle(color: primary),
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
