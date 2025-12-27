import 'dart:async';
import 'package:flutter/material.dart';

import '../api/api_delete_send_code.dart';
import '../api/api_delete_verify_code.dart';
import '../api/api_delete_confirm.dart';
import 'login_page.dart';

class StoreAccountPage extends StatefulWidget {
  const StoreAccountPage({super.key});

  @override
  State<StoreAccountPage> createState() => _StoreAccountPageState();
}

class _StoreAccountPageState extends State<StoreAccountPage> {
  static const primary = Color.fromARGB(255, 255, 0, 0);

  int _step = 1;
  final int _stepCount = 3;

  bool _loading = false;
  String? _message;
  bool _success = false;

  final _passCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _showPassword = false;

  int _remainingSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _passCtrl.dispose();
    _codeCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // =====================================================
  // TIMER
  // =====================================================
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

  String _formatTime(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return "${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}";
  }

  // =====================================================
  // FLOW
  // =====================================================
  Future<void> _next() async {
    FocusScope.of(context).unfocus();

    switch (_step) {
      case 1:
        await _stepPassword();
        break;
      case 2:
        await _stepVerifyCode();
        break;
      case 3:
        await _stepConfirm();
        break;
    }
  }

  // ---------------- STEP 1 : PASSWORD ONLY ----------------
  Future<void> _stepPassword() async {
    final pass = _passCtrl.text.trim();

    if (pass.isEmpty) {
      _setMsg("Veuillez entrer votre mot de passe.", false);
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final expires = await apiDeleteSendCode(pass);

      _startTimer(expires);

      setState(() {
        _step = 2;
        _success = true;
        _message = "Un code de confirmation a été envoyé à votre email.";
      });
    } catch (e) {
      _setMsg(_clean(e), false);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------------- STEP 2 : VERIFY CODE ----------------
  Future<void> _stepVerifyCode() async {
    final code = _codeCtrl.text.trim();

    if (code.isEmpty) {
      _setMsg("Veuillez entrer le code reçu par email.", false);
      return;
    }

    if (_remainingSeconds <= 0) {
      _setMsg("Le code a expiré. Veuillez recommencer.", false);
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await apiDeleteVerifyCode(code);

      _timer?.cancel();

      setState(() {
        _step = 3;
        _success = true;
        _message = "Code vérifié. Dernière confirmation requise.";
      });
    } catch (e) {
      _setMsg(_clean(e), false);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------------- STEP 3 : CONFIRM ----------------
  Future<void> _stepConfirm() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await apiDeleteConfirm();

      if (!mounted) return;

      setState(() {
        _success = true;
        _message = "Votre compte a été supprimé définitivement.";
      });

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      _setMsg(_clean(e), false);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _setMsg(String msg, bool success) {
    setState(() {
      _message = msg;
      _success = success;
    });
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  // =====================================================
  // UI
  // =====================================================
  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _passwordUI();
      case 2:
        return _codeUI();
      case 3:
        return _confirmUI();
      default:
        return const SizedBox();
    }
  }

  Widget _passwordUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Confirmez votre mot de passe pour continuer.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        TextField(
          style: Theme.of(context).textTheme.bodyMedium,
          controller: _passCtrl,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: "Mot de passe",
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
      ],
    );
  }

  Widget _codeUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Entrez le code reçu par email."),
        const SizedBox(height: 10),
        if (_remainingSeconds > 0)
          Text(
            "Expire dans ${_formatTime(_remainingSeconds)}",
            style: const TextStyle(
              color: primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          style: Theme.of(context).textTheme.bodyMedium,
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Code de vérification",
            prefixIcon: Icon(Icons.verified_outlined),
          ),
        ),
      ],
    );
  }

  Widget _confirmUI() {
    return Column(
      children: [
        const Icon(Icons.warning_amber_rounded, color: primary, size: 60),
        const SizedBox(height: 14),
        Text(
          "Attention",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: primary,
              ),
        ),
        SizedBox(height: 10),
        Text(
          "Votre compte sera désactivé immédiatement.\n"
          "Vous aurez 7 jours pour le récupérer en vous reconnectant.\n\n"
          "Après ce délai, la suppression sera définitive.",
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // =====================================================
  // BUILD
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final progress = _step / _stepCount;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text("Désactivation du compte"),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Theme.of(context).dividerColor,
                  valueColor: const AlwaysStoppedAnimation(primary),
                ),
                const SizedBox(height: 16),
                if (_message != null)
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _success ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 16),
                _buildStep(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _next,
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
                            _step == 3 ? "Confirmer" : "Continuer",
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
