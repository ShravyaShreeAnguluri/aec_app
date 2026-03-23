import 'dart:convert';
import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';
import '../../services/api_service.dart';
import 'package:faculty_app/services/token_service.dart';

class ProfileScreen extends StatefulWidget {
  final String name;
  final String email;
  final String department;
  final String facultyId;
  final String? designation;
  final String? qualification;
  final String? profileImage;

  const ProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.department,
    required this.facultyId,
    this.designation,
    this.qualification,
    this.profileImage,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD), // OTP theme background

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    name: widget.name,
                    designation: widget.designation,
                    qualification: widget.qualification,
                  ),
                ),
              );
            },
          )
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [

            const SizedBox(height: 10),

            /// PROFILE IMAGE
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              backgroundImage:
              (widget.profileImage != null &&
                  widget.profileImage!.isNotEmpty)
                  ? MemoryImage(base64Decode(widget.profileImage!))
                  : const AssetImage("assets/images/aditya_logo.jpeg")
              as ImageProvider,
            ),

            const SizedBox(height: 15),

            /// NAME
            Text(
              widget.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            /// INFO CARD
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Column(
                children: [

                  buildTile(Icons.badge_outlined,
                      "Faculty ID", widget.facultyId),

                  buildTile(Icons.email_outlined,
                      "Email", widget.email),

                  buildTile(Icons.apartment_outlined,
                      "Department", widget.department),

                  if (widget.designation != null &&
                      widget.designation!.isNotEmpty)
                    buildTile(Icons.work_outline,
                        "Designation", widget.designation!),

                  if (widget.qualification != null &&
                      widget.qualification!.isNotEmpty)
                    buildTile(Icons.school_outlined,
                        "Qualification", widget.qualification!),
                ],
              ),
            ),

            const SizedBox(height: 35),

            /// LOGOUT BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text(
                  "Logout",
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                  onPressed: () async {

                    await TokenService.clearToken();

                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                          (route) => false,
                    );


                  }
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// REUSABLE TILE
  static Widget buildTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1E4D8F)),
      title: Text(title),
      subtitle: Text(value),
    );
  }
}
