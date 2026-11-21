import 'package:flutter/material.dart';

import '../api/teledrive_api.dart';
import '../main.dart';
import '../models.dart';

/// Login Telegram via web API backend.
/// Alurnya sama seperti halaman /telegram-login di web:
/// minta kode OTP (10 menit) -> verifikasi -> kalau perlu password 2FA.
class TelegramLoginScreen extends StatefulWidget {
  const TelegramLoginScreen({super.key});
  @override
  State<TelegramLoginScreen> createState() => _TelegramLoginScreenState();
}

class _TelegramLoginScreenState extends State<TelegramLoginScreen> {
  final _phoneCtl = TextEditingController();
  final _codeCtl = TextEditingController();
  final _passCtl = TextEditingController();
  TelegramStatus? _status;
  bool _loading = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final st = await api.telegramStatus();
      if (mounted) setState(() => _status = st);
    } on AuthException {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestCode() async {
    final phone = _phoneCtl.text.trim();
    if (!phone.startsWith('+')) {
      setState(() => _error = 'Nomor HP harus format +62xxx.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.requestCode(phone);
      await _refresh();
      if (mounted) showInfo(context, 'Kode OTP dikirim ke Telegram.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.verifyCode(code: _codeCtl.text.trim(), password: _passCtl.text);
      // verify-code menjawab redirect; kebenaran dicek lewat status.
      await _refresh();
      final st = _status;
      if (st != null && st.connected) {
        if (mounted) {
          showInfo(context, 'Telegram terhubung.');
          Navigator.of(context).pushReplacementNamed('/home');
        }
        return;
      }
      if (st != null && st.needsPassword && _passCtl.text.isEmpty) {
        setState(() => _error = 'Akun ini butuh password 2FA. Isi lalu verifikasi lagi.');
      } else if (mounted) {
        setState(() => _error = 'Verifikasi belum berhasil. Cek kode OTP / password 2FA.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _phoneCtl.dispose();
    _codeCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = _status;
    final pending = st?.pending ?? false;
    final needsPassword = st?.needsPassword ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Telegram'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await api.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  (st?.connected ?? false) ? Icons.check_circle : Icons.warning,
                  color: (st?.connected ?? false) ? Colors.green : Colors.orange,
                ),
                title: Text((st?.connected ?? false)
                    ? 'Telegram terhubung'
                    : 'Telegram belum terhubung'),
                subtitle: Text(
                  st == null
                      ? 'Memeriksa status...'
                      : (st.detail.isNotEmpty
                          ? st.detail
                          : (st.account != null
                              ? 'Akun: ${st.account!['first_name'] ?? ''} @${st.account!['username'] ?? ''}'
                              : 'Login ulang diperlukan.')),
                ),
              ),
            ),
            if ((st?.connected ?? false)) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed('/home'),
                child: const Text('Lanjut ke Dashboard'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              const Text(
                'Kode OTP hanya dipakai sekali, berlaku 10 menit, dan tidak disimpan. Jangan kirim kode ke siapa pun.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneCtl,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP (+62xxx)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _requestCode,
                child: const Text('Kirim Kode OTP'),
              ),
              if (pending) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _codeCtl,
                  decoration: InputDecoration(
                    labelText: 'Kode OTP',
                    border: const OutlineInputBorder(),
                    helperText: st?.phoneMasked.isNotEmpty == true
                        ? 'Kode dikirim ke ${st!.phoneMasked}'
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                ),
                if (needsPassword) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password 2FA',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _verify,
                  child: const Text('Verifikasi'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await api.cancelTelegramLogin();
                          await _refresh();
                        },
                  child: const Text('Batalkan login Telegram'),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_loading) const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}
