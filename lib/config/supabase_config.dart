import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://ipwgvwmuhcfrdjkzzzdv.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlwd2d2d211aGNmcmRqa3p6emR2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE1MTYyMTcsImV4cCI6MjEwNzA5MjIxN30._X2iTDoaiwMBz8MU9MrFfOxYAn-JWkSrsegwj8Lts2k';

  // Verifica se o Supabase foi configurado com credenciais válidas
  static bool get isConfigured =>
      supabaseUrl != 'https://SEU-PROJETO.supabase.co' &&
      supabaseAnonKey != 'SUA-ANON-KEY-AQUI';

  static Future<void> initialize() async {
    if (isConfigured) {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
