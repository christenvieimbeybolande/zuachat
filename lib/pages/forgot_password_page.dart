import 'dart:async';
import 'package:flutter/material.dart';

import '../api/auth_forgot_send_code.dart';
import '../api/auth_forgot_verify_code.dart';
import '../api/auth_forgot_new_password.dart';
import '../api/auth_login.dart';
import 'feed_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // ===============================================================
  // CONFIG
  // ===============================================================
  static const primary = Color.fromARGB(255, 255, 0, 0);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get bgColor =>
      isDark ? const Color(0xFF18191A) : const Color(0xFFF0F2F5);
  Color get cardColor => isDark ? const Color(0xFF242526) : Colors.white;
  Color get inputBg => isDark ? const Color(0xFF2A2B2E) : Colors.white;
  Color get textColor => isDark ? Colors.white : Colors.black87;
  Color get hintColor => isDark ? Colors.white60 : Colors.grey;

  final _formKey = GlobalKey<FormState>();

  // ===============================================================
  // STATE
  // ===============================================================
  int _step = 1;
  final int _stepCount = 3;

  bool _loading = false;
  String? _message;
  bool _successMsg = false;

  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String? _pendingEmail;

  int _remainingSeconds = 0;
  Timer? _timer;

  bool _passHasUpper = false;
  bool _passHasDigit = false;
  bool _passHasSymbol = false;
  bool _passHasLength = false;
  bool _passMatch = false;
  bool _showPassword = false;

  // ===============================================================
  // DISPOSE
  // ===============================================================
  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ===============================================================
  // TIMER
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
  // PASSWORD RULES
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
  // FLOW
  // ===============================================================
  Future<void> _nextOrSubmit() async {
    FocusScope.of(context).unfocus();

    switch (_step) {
      case 1:
        await _step1RequestCode();
        break;
      case 2:
        await _step2VerifyCode();
        break;
      case 3:
        await _step3SetNewPassword();
        break;
    }
  }

  // ---------------- STEP 1 ----------------
  Future<void> _step1RequestCode() async {
    final email = _emailCtrl.text.trim();

    if (!RegExp(r'.+@.+\..+').hasMatch(email)) {
      setState(() {
        _message = "Veuillez entrer un email valide.";
        _successMsg = false;
      });
      return;
    }

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

  // ---------------- STEP 2 ----------------
  Future<void> _step2VerifyCode() async {
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
        _message = "Email introuvable, retour à l'étape 1.";
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

  // ---------------- STEP 3 ----------------
  Future<void> _step3SetNewPassword() async {
    final pass = _passCtrl.text.trim();

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

    if (_pendingEmail == null) {
      setState(() {
        _message = "Email introuvable, retour à l'étape 1.";
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
      final code = _codeCtrl.text.trim();

      await apiForgotNewPassword(_pendingEmail!, code, pass);
      await apiLogin(_pendingEmail!, pass);

      if (!mounted) return;

      setState(() {
        _message = "Mot de passe mis à jour 🎉";
        _successMsg = true;
      });

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FeedPage()),
      );
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
  // UI STEPS
  // ===============================================================
  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _buildStep1Email();
      case 2:
        return _buildStep2Code();
      case 3:
        return _buildStep3NewPassword();
      default:
        return const SizedBox();
    }
  }

  // ---------------- STEP 1 UI ----------------
  Widget _buildStep1Email() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Entrez l'adresse email liée à votre compte ZuaChat.",
          style: TextStyle(color: textColor),
        ),
        const SizedBox(height: 16),
        _input(
          controller: _emailCtrl,
          label: "Email",
          icon: Icons.email_outlined,
          keyboard: TextInputType.emailAddress,
        ),
      ],
    );
  }

  // ---------------- STEP 2 UI ----------------
  Widget _buildStep2Code() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Un code a été envoyé à :\n$_pendingEmail",
          style: TextStyle(color: textColor),
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
                        color: primary, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : const Text("Le code a expiré.",
                style: TextStyle(color: Colors.red)),
        const SizedBox(height: 16),
        _input(
          controller: _codeCtrl,
          label: "Code reçu",
          icon: Icons.verified_outlined,
          keyboard: TextInputType.number,
        ),
      ],
    );
  }

  // ---------------- STEP 3 UI ----------------
  Widget _buildStep3NewPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Choisissez un nouveau mot de passe.",
            style: TextStyle(color: textColor)),
        const SizedBox(height: 12),
        _passwordInput(_passCtrl, "Nouveau mot de passe"),
        const SizedBox(height: 10),
        _passwordInput(_confirmCtrl, "Confirmer le mot de passe"),
        const SizedBox(height: 12),
        _passwordRules(),
      ],
    );
  }

  // ===============================================================
  // WIDGETS
  // ===============================================================
  Widget _input({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hintColor),
        prefixIcon: Icon(icon, color: hintColor),
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _passwordInput(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      obscureText: !_showPassword,
      onChanged: (_) => setState(_updatePasswordRules),
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hintColor),
        prefixIcon: Icon(Icons.lock_outline, color: hintColor),
        suffixIcon: IconButton(
          icon: Icon(
            _showPassword ? Icons.visibility_off : Icons.visibility,
            color: hintColor,
          ),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _passwordRules() {
    Widget rule(bool ok, String text) {
      return Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
              color: ok ? Colors.green : Colors.grey, size: 17),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: ok ? Colors.green : hintColor, fontSize: 13)),
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
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text("Réinitialiser le mot de passe"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor:
                        isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(primary),
                  ),
                  const SizedBox(height: 12),
                  if (_message != null)
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _successMsg ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildStep(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _nextOrSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)
                          : Text(
                              _step == 1
                                  ? "Envoyer le code"
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
      ),
    );
  }
}
