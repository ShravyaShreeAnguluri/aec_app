// lib/config/app_config.dart
//
// ════════════════════════════════════════════════════════════
//  ⚠️  ONLY EDIT THIS ONE FILE WHEN YOUR NGROK URL CHANGES
//  Every new session: run ngrok → copy domain → paste below
// ════════════════════════════════════════════════════════════
//
//  Steps:
//  1. Terminal 1:  cd D:\backend && uvicorn main:app --host 0.0.0.0 --port 8000 --reload
//  2. Terminal 2:  ngrok http 8000
//  3. Copy the domain from the "Forwarding" line
//     e.g.  https://abc12-34def.ngrok-free.app  →  paste just: abc12-34def.ngrok-free.app
//  4. Paste below, hot-restart Flutter
//

class AppConfig {
  // 👇 PASTE YOUR CURRENT NGROK DOMAIN HERE (no https://, no trailing slash)
  static const String ngrokDomain = 'nongrievously-unpickable-araceli.ngrok-free.dev';

  // Derived URLs — do not edit
  static String get baseUrl => 'https://${ngrokDomain.trim()}';
  static String get apiUrl  => '$baseUrl/api';

  // Required header for ngrok free tier
  static const Map<String, String> ngrokHeaders = {
    'ngrok-skip-browser-warning': 'true',
    'Accept': 'application/json',
  };

  static const connectTimeout = Duration(seconds: 30);
  static const receiveTimeout = Duration(seconds: 60);
  static const uploadTimeout  = Duration(seconds: 300);
}