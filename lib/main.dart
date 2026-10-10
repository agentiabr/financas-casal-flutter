import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'config/supabase_config.dart';
import 'providers/finance_provider.dart';
import 'services/speech_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/biometric_lock_screen.dart';

import 'screens/dashboard_container_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => SpeechService()),
      ],
      child: const FinancasCasalApp(),
    ),
  );
}

class FinancasCasalApp extends StatelessWidget {
  const FinancasCasalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finanças Casal • Rodrigo & Márcia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      // Tela principal com alta fidelidade visual (exata da versão original)
      home: const DashboardContainerScreen(),
    );
  }
}
