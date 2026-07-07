import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'screens/sign_in_screen.dart';
import 'state/auth_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instance.init();
  await initializeDateFormatting('vi');

  final auth = AuthState();
  await auth.restore();

  runApp(
    ChangeNotifierProvider.value(
      value: auth,
      child: const AnonWorkApp(),
    ),
  );
}

class AnonWorkApp extends StatelessWidget {
  const AnonWorkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnonWork',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthState>().isLoggedIn;
    return isLoggedIn ? const HomeShell() : const SignInScreen();
  }
}
