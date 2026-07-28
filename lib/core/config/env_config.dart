import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads and validates public Supabase environment values from `.env`.
///
/// Never place service_role or other secret keys in this configuration.
abstract final class EnvConfig {
  static const String supabaseUrlKey = 'SUPABASE_URL';
  static const String supabasePublishableKeyKey = 'SUPABASE_PUBLISHABLE_KEY';

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
    // Validate eagerly so startup fails clearly before Supabase.initialize.
    supabaseUrl;
    supabasePublishableKey;
  }

  static String get supabaseUrl => _required(supabaseUrlKey);

  static String get supabasePublishableKey =>
      _required(supabasePublishableKeyKey);

  static String _required(String key) {
    final value = dotenv.env[key]?.trim() ?? '';
    if (value.isEmpty) {
      throw StateError(
        '$key is missing or empty. Copy .env.example to .env and set the value.',
      );
    }
    return value;
  }
}
