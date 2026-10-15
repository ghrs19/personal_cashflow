import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/lock_screen.dart';
import 'screens/root_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await initializeDateFormatting('en_US');
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const PersonalCashflowApp(),
    ),
  );
}

class PersonalCashflowApp extends StatefulWidget {
  const PersonalCashflowApp({super.key});

  @override
  State<PersonalCashflowApp> createState() => _PersonalCashflowAppState();
}

class _PersonalCashflowAppState extends State<PersonalCashflowApp> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'Personal Cashflow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: state.themeMode,
      home: _home(state),
    );
  }

  Widget _home(AppState state) {
    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.lockEnabled && !_unlocked) {
      return LockScreen(onUnlocked: () => setState(() => _unlocked = true));
    }
    return const RootShell();
  }
}
