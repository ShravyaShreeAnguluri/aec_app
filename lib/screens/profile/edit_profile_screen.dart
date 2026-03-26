import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String name;
  final String email; // kept for display only
  final String? designation;
  final String? qualification;

  const EditProfileScreen({
    super.key,
    required this.name,
    required this.email,
    this.designation,
    this.qualification,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {

  late TextEditingController nameController;
  late TextEditingController designationController;
  late TextEditingController qualificationController;
  late TextEditingController currentPasswordController;
  late TextEditingController newPasswordController;
  late TextEditingController confirmPasswordController;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  bool _isChangingPassword = false;
  File? _selectedImage;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  static const _navy = Color(0xFF0A2342);
  static const _navyLight = Color(0xFF2E5FA3);
  static const _teal = Color(0xFF0077B6);
  static const _bg = Color(0xFFF2F5FB);
  static const _card = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4EAF4);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF94A3B8);
  static const _danger = Color(0xFFB91C1C);
  static const _success = Color(0xFF0A7953);

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.name);
    designationController = TextEditingController(text: widget.designation ?? '');
    qualificationController = TextEditingController(text: widget.qualification ?? '');
    currentPasswordController = TextEditingController();
    newPasswordController = TextEditingController();
    confirmPasswordController = TextEditingController();

    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    nameController.dispose();
    designationController.dispose();
    qualificationController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 20),
            const Text('Update Profile Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textPrimary)),
            const SizedBox(height: 16),
            _BottomSheetOption(icon: Icons.camera_alt_rounded, label: 'Take a photo', color: _teal, onTap: () async {
              Navigator.pop(context);
              final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
              if (img != null && mounted) setState(() => _selectedImage = File(img.path));
            }),
            const SizedBox(height: 10),
            _BottomSheetOption(icon: Icons.photo_library_rounded, label: 'Choose from gallery', color: _navyLight, onTap: () async {
              Navigator.pop(context);
              final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
              if (img != null && mounted) setState(() => _selectedImage = File(img.path));
            }),
            const SizedBox(height: 10),
            if (_selectedImage != null)
              _BottomSheetOption(icon: Icons.delete_rounded, label: 'Remove photo', color: _danger, onTap: () {
                Navigator.pop(context);
                setState(() => _selectedImage = null);
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final name = nameController.text.trim();
    if (name.isEmpty) { _showSnack('Name cannot be empty', isError: true); return; }
    setState(() => _isSaving = true);
    try {
      // FIX: No longer passing email — backend identifies user from JWT token
      await ApiService.updateProfile(
        name: name,
        designation: designationController.text.trim(),
        qualification: qualificationController.text.trim(),
        profileImage: _selectedImage,
      );
      if (!mounted) return;
      _showSnack('Profile updated successfully!');
      Navigator.pop(context, {
        'name': name,
        'designation': designationController.text.trim(),
        'qualification': qualificationController.text.trim(),
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to update profile: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    final current = currentPasswordController.text;
    final newPass = newPasswordController.text;
    final confirm = confirmPasswordController.text;
    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) { _showSnack('All password fields are required', isError: true); return; }
    if (newPass != confirm) { _showSnack('New passwords do not match', isError: true); return; }
    if (newPass.length < 6) { _showSnack('Password must be at least 6 characters', isError: true); return; }
    final passRegex = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#$%^&*(),.?\":{}|<>]).{6,}$');
    if (!passRegex.hasMatch(newPass)) { _showSnack('Password must have uppercase, lowercase, number & special character', isError: true); return; }

    setState(() => _isChangingPassword = true);
    try {
      await ApiService.post('/change-password', body: {'current_password': current, 'new_password': newPass});
      if (!mounted) return;
      _showSnack('Password changed successfully!');
      currentPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _danger : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Profile Photo ──
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: _navy.withOpacity(0.08),
                        backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                        child: _selectedImage == null
                            ? Text(
                          widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _navy),
                        )
                            : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 28, height: 28,
                          decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(widget.email,
                    style: const TextStyle(fontSize: 13, color: _textMuted, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 24),

              // ── Profile Info ──
              const _SectionLabel(label: 'Profile Information', icon: Icons.person_rounded),
              const SizedBox(height: 10),
              _buildCard(children: [
                _buildField(controller: nameController, label: 'Full Name', icon: Icons.badge_rounded, color: _navy, hint: 'Enter your name'),
                const _FieldDivider(),
                _buildField(controller: designationController, label: 'Designation', icon: Icons.work_rounded, color: _teal, hint: 'e.g. Assistant Professor'),
                const _FieldDivider(),
                _buildField(controller: qualificationController, label: 'Qualification', icon: Icons.school_rounded, color: _navyLight, hint: 'e.g. M.Tech, PhD'),
              ]),
              const SizedBox(height: 24),

              // Save Profile Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    disabledBackgroundColor: _teal.withOpacity(0.55),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.save_rounded, size: 20), SizedBox(width: 10),
                    Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.3)),
                  ]),
                ),
              ),
              const SizedBox(height: 32),

              // ── Change Password ──
              const _SectionLabel(label: 'Change Password', icon: Icons.lock_rounded),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Password must contain uppercase, lowercase, number & special character.',
                    style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.w500, height: 1.4),
                  )),
                ]),
              ),
              _buildCard(children: [
                _buildPasswordField(controller: currentPasswordController, label: 'Current Password', obscure: _obscureCurrent, onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent)),
                const _FieldDivider(),
                _buildPasswordField(controller: newPasswordController, label: 'New Password', obscure: _obscureNew, onToggle: () => setState(() => _obscureNew = !_obscureNew)),
                const _FieldDivider(),
                _buildPasswordField(controller: confirmPasswordController, label: 'Confirm New Password', obscure: _obscureConfirm, onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm)),
              ]),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChangingPassword ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    disabledBackgroundColor: _navy.withOpacity(0.55),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isChangingPassword
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.lock_reset_rounded, size: 18), SizedBox(width: 8),
                    Text('Update Password', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ]),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextField(
            controller: controller, keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary),
            decoration: InputDecoration(
              hintText: hint, hintStyle: const TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w400),
              isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none, enabledBorder: InputBorder.none,
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: color.withOpacity(0.40), width: 1.5)),
            ),
          ),
        ])),
      ]),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: _navy.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.lock_rounded, color: _navy, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextField(
            controller: controller, obscureText: obscure,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary),
            decoration: InputDecoration(
              hintText: '••••••••', hintStyle: const TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w400),
              isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none, enabledBorder: InputBorder.none,
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0A2342), width: 1.5)),
              suffixIcon: GestureDetector(onTap: onToggle, child: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: _textMuted, size: 18)),
            ),
          ),
        ])),
      ]),
    );
  }
}

// ── Helper widgets ──

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: const Color(0xFF0A2342).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFF0A2342), size: 15),
      ),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.1)),
    ]);
  }
}

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFE4EAF4), indent: 64);
  }
}

class _BottomSheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BottomSheetOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}