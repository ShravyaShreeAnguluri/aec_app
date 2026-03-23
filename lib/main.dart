import 'dart:async';
import 'package:faculty_app/providers/certificate_provider.dart';
import 'package:faculty_app/providers/document_provider.dart';
import 'package:faculty_app/providers/holiday_import_provider.dart';
import 'package:faculty_app/screens/auth/login_screen.dart';
import 'package:faculty_app/screens/auth/register_screen.dart';
import 'package:faculty_app/screens/auth/reset_password_screen.dart';
import 'package:faculty_app/screens/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'theme/app_theme.dart';
import 'dashboards/faculty/faculty_dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'providers/holiday_provider.dart';
import 'providers/holiday_import_provider.dart';

/// 🔥 Global flag to prevent Splash override
bool openedFromDeepLink = false;

/// 🔑 Global navigator key (used for session expiration redirect)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HolidayProvider()),
        ChangeNotifierProvider(create: (_) => HolidayImportProvider()),
        ChangeNotifierProvider(create: (_) => CertificateProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // ✅ Handle cold start
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint("Initial link error: $e");
    }

    // ✅ Handle app already running
    _linkSubscription = _appLinks.uriLinkStream.listen(
          (Uri uri) {
        _handleUri(uri);
      },
      onError: (err) {
        debugPrint("Deep link stream error: $err");
      },
    );
  }

  void _handleUri(Uri uri) {
    debugPrint("Deep link received: $uri");

    // ✅ MATCH THIS WITH BACKEND
    if (uri.scheme == "facultyapp" &&
        uri.host == "reset-password" &&
        uri.queryParameters.containsKey('token')) {

      openedFromDeepLink = true;

      final String token = uri.queryParameters['token']!;

      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(token: token),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Faculty Face App',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const FacultyDashboardScreen(
          email: "",
          name: "",
          facultyId: "",
          department: "",
          role: "faculty",
        ),
      },
    );
  }
}