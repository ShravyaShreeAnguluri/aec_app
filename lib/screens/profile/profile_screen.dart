import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:faculty_app/services/token_service.dart';

import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String  name;
  final String  email;
  final String  department;
  final String  facultyId;
  final String? designation;
  final String? qualification;
  final String? profileImage;
  final String  role; // 'faculty' | 'operator' | etc.

  const ProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.department,
    required this.facultyId,
    this.designation,
    this.qualification,
    this.profileImage,
    this.role = 'faculty',
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {

  // ── Colours ──────────────────────────────────────────────────────────────
  static const _navy       = Color(0xFF0A2342);
  static const _navyLight  = Color(0xFF1E4D8F);
  static const _teal       = Color(0xFF0077B6);
  static const _gold       = Color(0xFFD4A017);
  static const _purple     = Color(0xFF6D28D9);
  static const _green      = Color(0xFF0A7953);
  static const _orange     = Color(0xFFB45309);
  static const _bg         = Color(0xFFF3F7FC);
  static const _card       = Colors.white;
  static const _border     = Color(0xFFE2E8F0);
  static const _danger     = Color(0xFFDC2626);
  static const _textPri    = Color(0xFF0F172A);
  static const _textMuted  = Color(0xFF64748B);

  // ── Mutable state ─────────────────────────────────────────────────────────
  late String  _name;
  late String  _designation;
  late String  _qualification;
  late String? _profileImage;

  // ── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _name          = widget.name;
    _designation   = widget.designation  ?? '';
    _qualification = widget.qualification ?? '';
    _profileImage  = widget.profileImage;

    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade     = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide    = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _initials(String name) {
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  ImageProvider _avatar() {
    if (_profileImage != null && _profileImage!.isNotEmpty) {
      try { return MemoryImage(base64Decode(_profileImage!)); } catch (_) {}
    }
    return const AssetImage('assets/images/aditya_logo.jpeg');
  }

  String _roleLabel() {
    switch (widget.role.toLowerCase()) {
      case 'hod':      return 'Head of Department';
      case 'dean':     return 'Dean';
      case 'operator': return 'Operator';
      default:         return 'Faculty';
    }
  }

  Color _roleColor() {
    switch (widget.role.toLowerCase()) {
      case 'hod':      return _gold;
      case 'dean':     return _teal;
      case 'operator': return _orange;
      default:         return _green;
    }
  }

  // ── Edit profile ──────────────────────────────────────────────────────────
  Future<void> _openEditProfile() async {
    final result = await Navigator.push<Map>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          name: _name,
          email: widget.email,
          designation:   _designation.isEmpty   ? null : _designation,
          qualification: _qualification.isEmpty ? null : _qualification,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _name          = result['name']          as String? ?? _name;
        _designation   = result['designation']   as String? ?? _designation;
        _qualification = result['qualification'] as String? ?? _qualification;
      });
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await TokenService.clearToken();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final hasDesig  = _designation.trim().isNotEmpty;
    final hasQual   = _qualification.trim().isNotEmpty;
    final initials  = _initials(_name);
    final roleLabel = _roleLabel();
    final roleColor = _roleColor();

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [

              // ─── Collapsible header ──────────────────────────────────────
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                stretch: true,
                automaticallyImplyLeading: false,
                elevation: 0,
                backgroundColor: _navy,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0A2342), Color(0xFF163B6F), Color(0xFF1E88E5)],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // decorative circles
                        Positioned(top: -40, right: -20,
                            child: _decorCircle(180, Colors.white.withOpacity(0.07))),
                        Positioned(top: 80, left: -40,
                            child: _decorCircle(140, Colors.white.withOpacity(0.05))),
                        Positioned(bottom: -30, right: 60,
                            child: _decorCircle(100, Colors.white.withOpacity(0.04))),

                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Back + Edit row
                                Row(
                                  children: [
                                    _glassButton(
                                      icon: Icons.arrow_back_ios_new_rounded,
                                      onTap: () => Navigator.pop(context),
                                    ),
                                    const Spacer(),
                                    _glassButton(
                                      icon: Icons.edit_rounded,
                                      onTap: _openEditProfile,
                                    ),
                                  ],
                                ),
                                const Spacer(),

                                // Avatar + name
                                Center(
                                  child: Column(
                                    children: [
                                      // Avatar ring
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: _gold.withOpacity(0.75), width: 2.5),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 24, offset: const Offset(0, 8))],
                                        ),
                                        child: CircleAvatar(
                                          radius: 52,
                                          backgroundColor: Colors.white,
                                          backgroundImage: _avatar(),
                                          child: (_profileImage == null || _profileImage!.isEmpty)
                                              ? Text(initials, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _navy))
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        _name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                                      ),
                                      const SizedBox(height: 8),
                                      // Role / dept badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(30),
                                          border: Border.all(color: Colors.white.withOpacity(0.18)),
                                        ),
                                        child: Text(
                                          hasDesig ? _designation : widget.department,
                                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Body content ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      children: [

                        // ── Glass summary strip ──────────────────────────
                        _glassSummary(roleLabel, roleColor),
                        const SizedBox(height: 18),

                        // ── Profile details card ─────────────────────────
                        _sectionCard(
                          title: 'Profile Details',
                          subtitle: 'Your academic and account information',
                          icon: Icons.person_outline_rounded,
                          iconColor: _navy,
                          children: [
                            _infoTile(icon: Icons.badge_outlined,         label: 'Faculty ID',    value: widget.facultyId,  color: _navyLight),
                            const _Div(),
                            _infoTile(icon: Icons.email_outlined,          label: 'Email',         value: widget.email,      color: _teal),
                            const _Div(),
                            _infoTile(icon: Icons.apartment_outlined,      label: 'Department',    value: widget.department, color: _purple),
                            if (hasDesig) ...[
                              const _Div(),
                              _infoTile(icon: Icons.work_outline_rounded,  label: 'Designation',   value: _designation,      color: _orange),
                            ],
                            if (hasQual) ...[
                              const _Div(),
                              _infoTile(icon: Icons.school_outlined,       label: 'Qualification', value: _qualification,    color: _green),
                            ],
                            const _Div(),
                            _infoTile(
                              icon: Icons.verified_user_rounded,
                              label: 'Role',
                              value: roleLabel,
                              color: roleColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // ── Edit profile action card ──────────────────────
                        _editActionCard(),
                        const SizedBox(height: 18),

                        // ── Stats strip ───────────────────────────────────
                        _statsStrip(),
                        const SizedBox(height: 24),

                        // ── Logout button ─────────────────────────────────
                        _logoutButton(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Glass summary strip ──────────────────────────────────────────────────
  Widget _glassSummary(String roleLabel, Color roleColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.90)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              Expanded(
                child: _summaryItem(
                  icon: Icons.perm_identity_rounded,
                  label: 'Faculty ID',
                  value: widget.facultyId,
                  color: _navy,
                ),
              ),
              Container(width: 1, height: 50, color: _border),
              Expanded(
                child: _summaryItem(
                  icon: Icons.apartment_rounded,
                  label: 'Department',
                  value: widget.department,
                  color: _teal,
                ),
              ),
              Container(width: 1, height: 50, color: _border),
              Expanded(
                child: _summaryItem(
                  icon: Icons.verified_user_rounded,
                  label: 'Role',
                  value: roleLabel,
                  color: roleColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryItem({required IconData icon, required String label, required String value, required Color color}) {
    return Column(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: _textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, textAlign: TextAlign.center,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: _textPri, fontWeight: FontWeight.w800)),
      ],
    );
  }

  // ── Section card ──────────────────────────────────────────────────────────
  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: iconColor, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textPri)),
                      Text(subtitle, style: const TextStyle(fontSize: 11, color: _textMuted, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({required IconData icon, required String label, required String value, required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 11, color: _textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 14.5, color: _textPri, fontWeight: FontWeight.w700, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Edit action card ──────────────────────────────────────────────────────
  Widget _editActionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0A2342), Color(0xFF163B6F)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.22), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.13), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Update your details', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text('Edit name, designation, qualification & photo',
                    style: TextStyle(color: Color(0xFFD7E6FA), fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _openEditProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _navy,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ── Stats strip ───────────────────────────────────────────────────────────
  Widget _statsStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(child: _statItem(icon: Icons.fingerprint_rounded, label: 'Attendance', color: _teal)),
          _vDiv(),
          Expanded(child: _statItem(icon: Icons.event_note_rounded,  label: 'Leaves',     color: _green)),
          _vDiv(),
          Expanded(child: _statItem(icon: Icons.schedule_rounded,    label: 'Schedule',   color: _purple)),
        ],
      ),
    );
  }

  Widget _statItem({required IconData icon, required String label, required Color color}) {
    return Column(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11.5, color: _textMuted, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _vDiv() => Container(width: 1, height: 60, color: _border);

  // ── Logout button ─────────────────────────────────────────────────────────
  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Logout', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _danger,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  // ── Glass action button (appbar) ──────────────────────────────────────────
  Widget _glassButton({required IconData icon, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              width: 42, height: 42,
              child: Icon(icon, color: Colors.white, size: 19),
            ),
          ),
        ),
      ),
    );
  }

  Widget _decorCircle(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

// ── Thin divider inside card ──
class _Div extends StatelessWidget {
  const _Div();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 53),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
    );
  }
}