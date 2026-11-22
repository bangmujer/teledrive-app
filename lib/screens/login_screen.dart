import 'package:flutter/material.dart';

import '../api/teledrive_api.dart';
import '../main.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _baseCtl = TextEditingController(text: api.baseUrl);
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _doLogin() async {
    final username = _userCtl.text.trim();
    final password = _passCtl.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Isi username dan password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await api.setBaseUrl(_baseCtl.text);
      await api.login(username, password);
      if (!mounted) return;
      await goAfterWebLogin(context);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _baseCtl.dispose();
    _userCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: FadeSlideIn(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [TeleDriveTheme.mint, TeleDriveTheme.teal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: TeleDriveTheme.teal.withOpacity(0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.cloud_rounded,
                            size: 52, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const FadeSlideIn(
                    delay: Duration(milliseconds: 80),
                    child: Text(
                      'TeleDrive',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: TeleDriveTheme.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const FadeSlideIn(
                    delay: Duration(milliseconds: 140),
                    child: Text(
                      'File Telegram kamu, dengan gaya Google Drive.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: TeleDriveTheme.inkSoft, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 26),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Selamat datang kembali',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: TeleDriveTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Login dengan akun web TeleDrive yang sama seperti di browser.',
                          style: TextStyle(
                              color: TeleDriveTheme.inkSoft, fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _baseCtl,
                          decoration: const InputDecoration(
                            labelText: 'Alamat server',
                            helperText:
                                'Default: https://teledrive.mjr-dev.my.id',
                            prefixIcon: Icon(Icons.dns_rounded),
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _userCtl,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_rounded),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passCtl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          onSubmitted: (_) => _doLogin(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _loading ? null : _doLogin,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Login'),
                        ),
                      ],
                    ),
                  ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Login tersimpan 30 hari di perangkat ini. Jangan bagikan password ke siapa pun.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: TeleDriveTheme.inkSoft, fontSize: 12),
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
