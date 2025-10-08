// lib/config.dart

/// Centralized app configuration.
/// Supply secrets via --dart-define on run/build:
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class AppConfig {
  static const String supabaseUrl = 'https://kntrzuiotxxugvmkrbzm.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtudHJ6dWlvdHh4dWd2bWtyYnptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk4MTMwMzYsImV4cCI6MjA3NTM4OTAzNn0.nFZCTS5-_6GiS8sa-RhBnBwLOHuvLb8ROKJiZzX9AXc';

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}