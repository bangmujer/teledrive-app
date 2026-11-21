import 'package:flutter/material.dart';

import 'api/teledrive_api.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/telegram_login_screen.dart';

final api = TeleDriveApi();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await api.init();
  runApp(const TeleDriveApp());
}

class TeleDriveApp extends StatelessWidget {
  const TeleDriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeleDrive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: api.hasSession ? const HomeScreen() : const LoginScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/telegram': (_) => const TelegramLoginScreen(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}

/// Pindah ke layar yang benar setelah login web:
/// Telegram terhubung -> Home, belum -> TelegramLogin.
Future<void> goAfterWebLogin(BuildContext context) async {
  try {
    final st = await api.telegramStatus();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(st.connected ? '/home' : '/telegram');
  } catch (_) {
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }
}

void showError(BuildContext context, Object e, {String prefix = ''}) {
  final msg = e.toString().replaceFirst('Exception: ', '');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(prefix.isEmpty ? msg : '$prefix: $msg')),
  );
}

void showInfo(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
