import 'package:flutter/material.dart';
import '../../dashboards/admin/admin_dashboard_screen.dart';
import '../../dashboards/dean/dean_dashboard_screen.dart';
import '../../dashboards/faculty/faculty_dashboard_screen.dart';
import '../../dashboards/hod/hod_dashboard_screen.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../operator/operator_dashboard_screen.dart';

class OTPLoginScreen extends StatefulWidget {
  final String email;

  const OTPLoginScreen({super.key, required this.email});

  @override
  State<OTPLoginScreen> createState() => _OTPLoginScreenState();
}

class _OTPLoginScreenState extends State<OTPLoginScreen> {
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;

  void verifyOtp() async {
    if (otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid 6-digit OTP")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final result =
      await ApiService.verifyOtp(widget.email, otpController.text);

      if (!mounted) return;
      setState(() => isLoading = false);

      // ✅ SAVE JWT TOKEN
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", result["access_token"]);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Login successful")),
      );

      final role = result["role"];

      if (role == "admin") {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboardScreen(
              name: result["name"],
            ),
          ),
        );

      }
      else if (role == "hod") {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HodDashboardScreen(
              name: result["name"],
              department: result["department"],
            ),
          ),
        );

      }
      else if (role == "dean") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DeanDashboardScreen(
              name: result["name"],
              email: result["email"] ?? widget.email,
            ),
          ),
        );
      }

      else if (role == "operator") {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OperatorDashboardScreen(
              name: result["name"],
              department: result["department"],
              token: result["access_token"],
              ),
            ),
        );

      }

      else {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FacultyDashboardScreen(
              email: result["email"],
              name: result["name"],
              facultyId: result['faculty_id'],
              department: result["department"],
              designation: result["designation"],
              qualification: result["qualification"],
              profileImage: result["profile_image"],
              role: result["role"],
            ),
          ),
        );

      }

    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
  Widget buildOtpField() {
    return TextField(
      controller: otpController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 22,
        letterSpacing: 8,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        hintText: "------",
        counterText: "",
        prefixIcon: const Icon(Icons.lock_outline,
            color: Color(0xFF0D47A1)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE3F2FD),
              Color(0xFFBBDEFB),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              children: [
                /// 🔵 LOGO
                Image.asset(
                  "assets/images/adityaaa.png",
                  height: 120,
                ),

                const SizedBox(height: 20),

                const Text(
                  "OTP Verification",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "OTP sent to\n${widget.email}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16, // optional for better visibility
                  ),
                ),


                const SizedBox(height: 45),

                /// 🔵 OTP FIELD
                buildOtpField(),

                const SizedBox(height: 30),

                /// 🔵 VERIFY BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : verifyOtp,
                    style: ElevatedButton.styleFrom(
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.zero,
                      backgroundColor:
                      Colors.transparent,
                    ),
                    child: Ink(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF0D47A1),
                            Color(0xFFB87333),
                          ],
                        ),
                        borderRadius:
                        BorderRadius.all(
                            Radius.circular(30)),
                      ),
                      child: Center(
                        child: isLoading
                            ? const CircularProgressIndicator(
                            color: Colors.white)
                            : const Text(
                          "Verify OTP",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                            FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Back to Login",
                    style: TextStyle(
                      color: Color(0xFF0D47A1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
