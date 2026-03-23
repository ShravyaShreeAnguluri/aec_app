import 'dart:async';
import 'package:flutter/material.dart';
import '../../dashboards/admin/admin_dashboard_screen.dart';
import '../../dashboards/faculty/faculty_dashboard_screen.dart';
import '../../dashboards/hod/hod_dashboard_screen.dart';
import '../../main.dart'; // 🔥 IMPORTANT to access openedFromDeepLink
import '../../services/token_service.dart';
import '../operator/operator_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  Future<void> checkLogin() async {

    if (openedFromDeepLink) return;

    final user = await TokenService.getUserSession();
    final token = user["token"];
    final email = user["email"];

    if (!mounted) return;
    if (token != null &&
        token.isNotEmpty &&
        email != null &&
        email.isNotEmpty) {

      final role = user["role"] ?? "faculty";

      if (role == "admin") {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboardScreen(
              name: user["name"] ?? "",
            ),
          ),
        );

      }
      else if (role == "hod") {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HodDashboardScreen(
              name: user["name"] ?? "",
              department: user["department"] ?? "",
            ),
          ),
        );

      }
      else if (role == "operator") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OperatorDashboardScreen(
              name: user["name"] ?? "",
              department: user["department"] ?? "",
              token: user["access_token"] ?? "",
            ),
          ),
        );

      }
      else {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FacultyDashboardScreen(
              email: user["email"] ?? "",
              name: user["name"] ?? "",
              facultyId: user["facultyId"] ?? "",
              department: user["department"] ?? "",
              designation: user["designation"],
              qualification: user["qualification"],
              profileImage: user["profileImage"],
              role: user["role"] ?? "faculty",
            ),
          ),
        );

      }

    } else {

      Navigator.pushReplacementNamed(context, '/login');

    }

  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 4), () {
      checkLogin();
    });

  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF8F9FF),
              Color(0xFFE3E9FF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [

            // 🌊 Large Top Decorative Circle
            Positioned(
              top: -150,
              right: -100,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3F51B5).withOpacity(0.07),
                ),
              ),
            ),

            // 🌊 Bottom Decorative Shape
            Positioned(
              bottom: -120,
              left: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF5C6BC0).withOpacity(0.06),
                ),
              ),
            ),

            // 🌟 Radial Glow Behind Logo
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white,
                              const Color(0xFFE8EDFF),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/aditya_no.png',
                            width: 150,
                            height: 150,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 50),

                      const Text(
                        "Welcome",
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: Color(0xFF2F3E9E),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        "ADITYA UNIVERSITY",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                          color: Color(0xFF3F51B5),
                        ),
                      ),

                      const SizedBox(height: 45),

                      Container(
                        width: 80,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF3F51B5),
                              Color(0xFF5C6BC0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}