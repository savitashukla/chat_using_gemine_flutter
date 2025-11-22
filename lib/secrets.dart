// Development secret file - do NOT commit to source control.
// For real projects, keep API keys on a backend or use secure storage.

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Returns the Google Generative API key.
///
/// Priority:
/// 1. dotenv (load a .env file during development)
/// 2. Compile-time dart-define: --dart-define=GOOGLE_GENERATIVE_API_KEY=your_key
/// 3. Empty string if none provided
String getGoogleGenerativeApiKey() {
  final dotenvKey = dotenv.env['GOOGLE_GENERATIVE_API_KEY'];
  final compileTime = const String.fromEnvironment('GOOGLE_GENERATIVE_API_KEY');
  return dotenvKey ?? compileTime;
}
