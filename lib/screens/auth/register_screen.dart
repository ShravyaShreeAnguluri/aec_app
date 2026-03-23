import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import 'package:camera/camera.dart';

import '../attendance/camera_screen.dart';

class RegisterScreen extends StatefulWidget {

  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController facultyIdController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  // ADD THESE CONTROLLERS
  final TextEditingController designationController = TextEditingController();
  final TextEditingController qualificationController = TextEditingController();
  String? selectedDepartment;
  List<String> departments = [];
  XFile? faceImage;
  XFile? profileImage;

  final ImagePicker _picker = ImagePicker();
  bool _isPasswordVisible = false;
  bool isRegistering = false;

  @override
  void dispose() {
    nameController.dispose();
    facultyIdController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
    designationController.dispose();
    qualificationController.dispose();

  }

  void loadDepartments() async {
    try {
      final data = await ApiService.getDepartments();
      setState(() {
        departments = data;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load departments")),
      );
    }
  }
  @override
  void initState() {
    super.initState();
    loadDepartments();
  }

  // ================= FACE CAMERA =================
  void openCamera() async {
    final image = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );

    if (image != null) {
      setState(() => faceImage = image);
    }
  }

  // ================= PROFILE IMAGE PICK =================
  void pickProfileImage() async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Take Photo"),
                onTap: () async {
                  final image =
                  await _picker.pickImage(source: ImageSource.camera);
                  Navigator.pop(context);
                  if (image != null) {
                    setState(() => profileImage = image);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Choose from Gallery"),
                onTap: () async {
                  final image =
                  await _picker.pickImage(source: ImageSource.gallery);
                  Navigator.pop(context);
                  if (image != null) {
                    setState(() => profileImage = image);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= SUBMIT =================
  void submitForm() async {

    if (!_formKey.currentState!.validate()) return;

    if (selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a department")),
      );
      return;
    }

    if (faceImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please capture your face")),
      );
      return;
    }

    setState(() {
      isRegistering = true;
    });

    dynamic imageToSend;
    dynamic profileToSend;

    if (kIsWeb) {
      imageToSend = await faceImage!.readAsBytes();
      if (profileImage != null) {
        profileToSend = await profileImage!.readAsBytes();
      }
    } else {
      imageToSend = File(faceImage!.path);
      if (profileImage != null) {
        profileToSend = File(profileImage!.path);
      }
    }

    try {
      final response = await ApiService.registerFaculty(
        facultyId: facultyIdController.text.trim(),
        name: nameController.text.trim(),
        department: selectedDepartment!,
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        designation: designationController.text.trim().isEmpty
            ? null
            : designationController.text.trim(),

        qualification: qualificationController.text.trim().isEmpty
            ? null
            : qualificationController.text.trim(),
        faceImage: imageToSend,
        profileImage: profileToSend,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? "Registered Successfully"),
          backgroundColor: Colors.green,
        ),
      );

      _formKey.currentState!.reset();

      setState(() {
        faceImage = null;
        profileImage = null;
        isRegistering = false;
      });

      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {

      setState(() {
        isRegistering = false;
      });

      String errorMessage = e.toString();

      if (errorMessage.contains("already registered")) {
        errorMessage = "This face is already registered with another account.";
      }

      if (errorMessage.contains("Email already exists")) {
        errorMessage = "This email is already registered.";
      }

      if (errorMessage.contains("Faculty ID already exists")) {
        errorMessage = "Faculty ID already exists.";
      }

      if (errorMessage.startsWith("Exception: ")) {
        errorMessage = errorMessage.replaceFirst("Exception: ", "");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ================= FIELD BUILDER =================
  Widget buildPremiumField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isEmail = false,
    bool isOptional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? !_isPasswordVisible : false,
        keyboardType:
          isEmail ? TextInputType.emailAddress : TextInputType.text,
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF1E4D8F)),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              _isPasswordVisible
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: const Color(0xFF1E4D8F),
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.95),
          contentPadding:
          const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(40),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {

          if (isOptional) return null;

          if (value == null || value.trim().isEmpty) {
            return "$label cannot be empty";
          }
          if (isEmail && !value.contains("@")) {
            return "Enter a valid email";
          }
          return null;
        },
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB7D0E2), Color(0xFFA4C2D9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 70),

                // 🔥 PREMIUM LOGO
                // LOGO (Same as Login Page – No Circle)
                Image.asset(
                  "assets/images/adityaaa.png",
                  height: 120,
                ),

                const SizedBox(height: 20),

                const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E4D8F),
                  ),
                ),

                const SizedBox(height: 30),

                // PROFILE IMAGE
                GestureDetector(
                  onTap: pickProfileImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.white,
                        backgroundImage: profileImage != null
                            ? FileImage(File(profileImage!.path))
                            : null,
                        child: profileImage == null
                            ? const Icon(Icons.person,
                            size: 45, color: Color(0xFF1E4D8F))
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1E4D8F),
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                buildPremiumField(
                    controller: nameController,
                    label: "Faculty Name",
                    icon: Icons.person_outline),
                buildPremiumField(
                    controller: facultyIdController,
                    label: "Faculty ID",
                    icon: Icons.badge_outlined),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: DropdownButtonFormField<String>(
                    value: selectedDepartment,
                    decoration: InputDecoration(
                      hintText: "Department",
                      prefixIcon: const Icon(Icons.apartment_outlined, color: Color(0xFF1E4D8F)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.95),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(40),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: departments.map((dept) {
                      return DropdownMenuItem(
                        value: dept,
                        child: Text(dept),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDepartment = value;
                      });
                    },
                    validator: (value) =>
                    value == null ? "Select department" : null,
                  ),
                ),
                buildPremiumField(
                  controller: designationController,
                  label: "Designation (Optional)",
                  icon: Icons.work_outline,
                  isOptional: true,
                ),

                buildPremiumField(
                  controller: qualificationController,
                  label: "Qualification (Optional)",
                  icon: Icons.school_outlined,
                  isOptional: true,
                ),

                buildPremiumField(
                    controller: emailController,
                    label: "Email",
                    icon: Icons.email_outlined,
                    isEmail: true),
                buildPremiumField(
                    controller: passwordController,
                    label: "Password",
                    icon: Icons.lock_outline,
                    isPassword: true),

                const SizedBox(height: 25),

                // 🔥 CAPTURE FACE BUTTON
                SizedBox(
                  width: 240,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: openCamera,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(35),
                      ),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: faceImage == null
                              ? [Color(0xFF6C63FF), Color(0xFF8E7CFF)]
                              : [Color(0xFF00C853), Color(0xFF69F0AE)],
                        ),
                        borderRadius:
                        const BorderRadius.all(Radius.circular(35)),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              faceImage == null
                                  ? Icons.camera_alt
                                  : Icons.check_circle,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              faceImage == null
                                  ? "Capture Face"
                                  : "Face Captured",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // REGISTER BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isRegistering ? null : submitForm,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    child: Ink(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF1E4D8F),
                            Color(0xFFB87333),
                          ],
                        ),
                        borderRadius:
                        BorderRadius.all(Radius.circular(40)),
                      ),
                      child: Center(
                        child: isRegistering
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          "Register",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text(
                    "Already have an account? Login",
                    style: TextStyle(
                        color: Color(0xFF1E4D8F),
                        fontWeight: FontWeight.w500),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
