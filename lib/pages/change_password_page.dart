import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/auth_change_password.dart';
import '../api/auth_forgot_send_code.dart';
import '../api/auth_forgot_verify_code.dart';
import '../api/auth_forgot_new_password.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  static const primary = Color.fromARGB(255, 255, 0, 0);

  int _step = 1;
  final int _stepCount = 3;

  bool _loading = false;
  String? _message;
  bool _successMsg = false;

  // Controllers
  final _oldCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _forgotMode = false; // 🔥 mode “mot de passe oublié ?”
  String? _pendingEmail;

  int _remainingSeconds = 0;
  Timer? _timer;

  bool _passHasUpper = false;
  bool _passHasDigit = false;
  bool _passHasSymbol = false;
  bool _passHasLength = false;
  bool _passMatch = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ===============================================================
  // TIMER (pour le reset via email)
  // ===============================================================
  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _remainingSeconds = seconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds <= 1) {
        t.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // ===============================================================
  // PASSWORD RULES (mêmes que ForgotPasswordPage)
  // ===============================================================
  void _updatePasswordRules() {
    final v = _passCtrl.text;

    _passHasUpper = RegExp(r'[A-Z]').hasMatch(v);
    _passHasDigit = RegExp(r'[0-9]').hasMatch(v);
    _passHasSymbol = RegExp(r'[\W]').hasMatch(v);
    _passHasLength = v.length >= 6;
    _passMatch = v == _confirmCtrl.text;
  }

  // ===============================================================
  // FLOW GLOBAL
  // ===============================================================
  Future<void> _nextOrSubmit() async {
    FocusScope.of(context).unfocus();

    if (_step == 1) {
      if (_forgotMode) {
        await _stepForgotSendCode();
      } else {
        await _stepCheckOldPassword();
      }
    } else if (_step == 2) {
      await _stepVerifyCode();
    } else if (_step == 3) {
      await _stepApplyNewPassword();
    }
  }

  // ---------------- STEP 1-A : Vérifier ancien mot de passe ----------------
  Future<void> _stepCheckOldPassword() async {
    final old = _oldCtrl.text.trim();

    if (old.isEmpty) {
      setState(() {
        _message = "Veuillez entrer votre ancien mot de passe.";
        _successMsg = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final ok = await apiCheckOldPassword(old);

      if (!ok) {
        setState(() {
          _message = "Ancien mot de passe incorrect.";
          _successMsg = false;
        });
        return;
      }

      setState(() {
        _step = 3; // 🔥 on va directement à l’étape nouveau mot de passe
        _message = "Ancien mot de passe vérifié ";
        _successMsg = true;
      });
    } catch (e) {
      setState(() {
        _message = e.toString().replaceFirst("Exception: ", "");
        _successMsg = false;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------------- STEP 1-B : Envoi code si “mot de passe oublié ?” ----------------
// ---------------- STEP 1-B : Envoi code si “mot de passe oublié ?” ----------------
  Future<void> _stepForgotSendCode() async {
    final email = _emailCtrl.text.trim();

    if (!RegExp(r'.+@.+\..+').hasMatch(email)) {
      setState(() {
        _message = "Veuillez entrer un email valide.";
        _successMsg = false;
      });
      return;
    }

    // =====================================================
    // 🔒 EMPÊCHER L'UTILISATEUR D'UTILISER UN AUTRE EMAIL
    // =====================================================
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');

    if (userData != null) {
      final user = jsonDecode(userData);
      final realEmail = (user['email'] ?? "").trim();

      if (email.toLowerCase() != realEmail.toLowerCase()) {
        setState(() {
          _message =
              "Adresse email incorrecte. Veuillez utiliser l'email lié à votre compte.";
          _successMsg = false;
        });
        return;
      }
    }

    // =====================================================
    // 🚀 ENVOI DU CODE
    // =====================================================
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final expiresIn = await apiForgotSendCode(email);

      setState(() {
        _pendingEmail = email;
        _step = 2;
        _message = "Un code a été envoyé à $email.";
        _successMsg = true;
      });

      _startTimer(expiresIn);
    } catch (e) {
      setState(() {
        _message = e.toString().replaceFirst("Exception: ", "");
        _successMsg = false;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------------- STEP 2 : Vérifier code reçu ----------------
  Future<void> _stepVerifyCode() async {
    final code = _codeCtrl.text.trim();

    if (code.isEmpty) {
      setState(() {
        _message = "Veuillez entrer le code reçu.";
        _successMsg = false;
      });
      return;
    }

    if (_remainingSeconds <= 0) {
      setState(() {
        _message = "Le code a expiré. Veuillez renvoyer un nouveau code.";
        _successMsg = false;
      });
      return;
    }

    if (_pendingEmail == null) {
      setState(() {
        _message = "Email introuvable, retour à l’étape 1.";
        _successMsg = false;
        _step = 1;
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await apiForgotVerifyCode(_pendingEmail!, code);

      _timer?.cancel();

      setState(() {
        _step = 3;
        _message = "Code vérifié avec succès 🎉";
        _successMsg = true;
      });
    } catch (e) {
      setState(() {
        _message = e.toString().replaceFirst("Exception: ", "");
        _successMsg = false;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------------- STEP 3 : Appliquer le nouveau mot de passe ----------------
  Future<void> _stepApplyNewPassword() async {
    final pass = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (!_passHasLength ||
        !_passHasUpper ||
        !_passHasDigit ||
        !_passHasSymbol ||
        !_passMatch) {
      setState(() {
        _message = "Le mot de passe ne respecte pas les exigences.";
        _successMsg = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      if (_forgotMode && _pendingEmail != null) {
        // 🔥 Cas “mot de passe oublié” → même logique que ForgotPasswordPage
        final code = _codeCtrl.text.trim();
        await apiForgotNewPassword(_pendingEmail!, code, pass);
        // (Le mail de sécurité est déjà envoyé par auth_forgot_new_password.php)
      } else {
        // 🔥 Cas normal : ancien mot de passe vérifié, on utilise auth_change_password.php
        await apiChangePassword(pass);
        // (Le mail de sécurité est envoyé par auth_change_password.php)
      }

      if (!mounted) return;

      setState(() {
        _message = "Mot de passe modifié avec succès ";
        _successMsg = true;
      });

      // Petit délai puis retour aux paramètres
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _message = e.toString().replaceFirst("Exception: ", "");
        _successMsg = false;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ===============================================================
  // UI – Étapes
  // ===============================================================
  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2Code();
      case 3:
        return _buildStep3NewPassword();
      default:
        return const SizedBox();
    }
  }

  // STEP 1 : ancien mot de passe OU email (mot de passe oublié)
  Widget _buildStep1() {
    if (!_forgotMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Entrez votre ancien mot de passe.\n"
            "Si vous l’avez oublié, utilisez l’option ci-dessous.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _oldCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Ancien mot de passe",
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _forgotMode = true;
                  _message = null;
                });
              },
              child: const Text("Mot de passe oublié ?"),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Vous avez oublié votre mot de passe ?\n"
            "Entrez l’email lié à votre compte pour recevoir un code.",
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _oldCtrl,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: const InputDecoration(
              labelText: "Email",
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      setState(() {
                        _forgotMode = false;
                        _pendingEmail = null;
                        _codeCtrl.clear();
                        _message = null;
                        _remainingSeconds = 0;
                        _timer?.cancel();
                      });
                    },
              child: const Text("Revenir à l’ancien mot de passe"),
            ),
          ),
        ],
      );
    }
  }

  // STEP 2 : code reçu
  Widget _buildStep2Code() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pendingEmail != null)
          Text(
            "Un code de vérification a été envoyé à :\n$_pendingEmail",
            style: const TextStyle(fontSize: 14),
          ),
        const SizedBox(height: 12),
        _remainingSeconds > 0
            ? Row(
                children: [
                  const Icon(Icons.timer, color: primary),
                  const SizedBox(width: 6),
                  Text(
                    "Expire dans ${_formatDuration(_remainingSeconds)}",
                    style: const TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : const Text(
                "Le code a expiré.",
                style: TextStyle(color: Colors.red),
              ),
        const SizedBox(height: 16),
        TextField(
          controller: _codeCtrl,
          decoration: const InputDecoration(
            labelText: "Code reçu",
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
                        _step = 1;
                        _forgotMode = true;
                        _codeCtrl.clear();
                        _remainingSeconds = 0;
                        _timer?.cancel();
                      });
                    },
              child: const Text("Modifier l’email"),
            ),
            const Spacer(),
            TextButton(
              onPressed: (_loading || _pendingEmail == null)
                  ? null
                  : () async {
                      await _stepForgotSendCode();
                    },
              child: const Text("Renvoyer le code"),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 3 : nouveau mot de passe
  Widget _buildStep3NewPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Choisissez un nouveau mot de passe."),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: !_showPassword,
          onChanged: (v) => setState(_updatePasswordRules),
          decoration: InputDecoration(
            labelText: "Nouveau mot de passe",
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon:
                  Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _confirmCtrl,
          obscureText: !_showPassword,
          onChanged: (v) => setState(_updatePasswordRules),
          decoration: const InputDecoration(
            labelText: "Confirmer le mot de passe",
            prefixIcon: Icon(Icons.lock_reset),
          ),
        ),
        const SizedBox(height: 12),
        _passwordRules(),
      ],
    );
  }

  Widget _passwordRules() {
    Widget rule(bool ok, String text) {
      return Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            color: ok ? Colors.green : Colors.grey,
            size: 17,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: ok
                  ? Colors.green
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        rule(_passHasLength, "6 caractères minimum"),
        rule(_passHasUpper, "1 majuscule"),
        rule(_passHasDigit, "1 chiffre"),
        rule(_passHasSymbol, "1 symbole"),
        rule(_passMatch, "Confirmation identique"),
      ],
    );
  }

  // ===============================================================
  // BUILD
  // ===============================================================
  @override
  Widget build(BuildContext context) {
    final progress = _step / _stepCount;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text("Changer le mot de passe"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock_outline, color: primary),
                    SizedBox(width: 8),
                    Text(
                      "Sécurité du compte",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primary,
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
                    valueColor: const AlwaysStoppedAnimation(primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Étape $_step / $_stepCount",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (_message != null)
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _successMsg ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 10),
                _buildStep(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _nextOrSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          )
                        : Text(
                            _step == 1
                                ? (_forgotMode
                                    ? "Envoyer le code"
                                    : "Continuer")
                                : _step == 2
                                    ? "Vérifier le code"
                                    : "Changer le mot de passe",
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
