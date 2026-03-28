import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../screens/holidays/holiday_list_screen.dart';
import '../../services/token_service.dart';
import '../../services/api_service.dart';
import 'admin_faculty_screen.dart';
import 'admin_reports_screen.dart';

class _C {
  static const navy = Color(0xFF0A2342);
  static const navyMid = Color(0xFF1B3F72);
  static const navyLight = Color(0xFF2E5FA3);
  static const teal = Color(0xFF0077B6);
  static const bg = Color(0xFFF2F5FB);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4EAF4);
  static const success = Color(0xFF0A7953);
  static const successBg = Color(0xFFE6F4EF);
  static const danger = Color(0xFFB91C1C);
  static const dangerBg = Color(0xFFFEE2E2);
  static const gold = Color(0xFFB45309);
  static const goldBg = Color(0xFFFEF3C7);
  static const purple = Color(0xFF5B21B6);
  static const purpleBg = Color(0xFFEDE9FE);
  static const textPrimary = Color(0xFF0F172A);
  static const textSub = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
}

class AdminDashboardScreen extends StatefulWidget {
  final String name;

  const AdminDashboardScreen({
    super.key,
    required this.name,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  bool _loading = true;

  Map<String, dynamic> _summary = {};
  List<dynamic> _deptStatus = [];
  Map<String, dynamic> _roleSummary = {};
  Map<String, dynamic> _leaveSummary = {};

  late AnimationController _headerCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerFade;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic),
    );
    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _headerCtrl, curve: Curves.easeIn),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear),
    );

    _headerCtrl.forward();
    _loadAdminData();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        ApiService.getAdminDashboardSummary(),
        ApiService.getAdminDepartmentStatus(),
        ApiService.getAdminRoleSummary(),
        ApiService.getAdminLeaveSummary(),
      ]);

      if (!mounted) return;

      setState(() {
        _summary = Map<String, dynamic>.from(results[0] as Map);
        _deptStatus = List<dynamic>.from(results[1] as List);
        _roleSummary = Map<String, dynamic>.from(results[2] as Map);
        _leaveSummary = Map<String, dynamic>.from(results[3] as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _C.textSub),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TokenService.clearToken();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    }
  }

  String _safe(dynamic value, {String fallback = '0'}) {
    if (value == null) return fallback;
    return value.toString();
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _todayLabel() {
    final n = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]}';
  }

  bool get _hasDean => _asInt(_summary['dean_assigned']) > 0 || _asInt(_roleSummary['dean']) > 0;

  int get _needsAttention => _asInt(_summary['departments_needing_attention']);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _C.navy,
          onRefresh: _loadAdminData,
          child: _loading
              ? _buildShimmer()
              : CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _shimBlock(190),
          const SizedBox(height: 18),
          _shimBlock(28),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _shimBlock(96)),
              const SizedBox(width: 12),
              Expanded(child: _shimBlock(96)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _shimBlock(96)),
              const SizedBox(width: 12),
              Expanded(child: _shimBlock(96)),
            ],
          ),
          const SizedBox(height: 18),
          _shimBlock(120),
          const SizedBox(height: 18),
          _shimBlock(86),
          const SizedBox(height: 10),
          _shimBlock(86),
          const SizedBox(height: 10),
          _shimBlock(86),
          const SizedBox(height: 18),
          _shimBlock(150),
        ],
      ),
    );
  }

  Widget _shimBlock(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment(-1.5 + _shimmer.value, 0),
          end: Alignment(1.5 + _shimmer.value, 0),
          colors: const [
            Color(0xFFE7EDF4),
            Color(0xFFF9FBFD),
            Color(0xFFE7EDF4),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SlideTransition(
            position: _headerSlide,
            child: FadeTransition(
              opacity: _headerFade,
              child: _buildHeroHeader(),
            ),
          ),
          const SizedBox(height: 22),

          _SectionHeader(
            title: 'Institution Overview',
            subtitle: 'Today’s real-time college administration snapshot',
            icon: Icons.dashboard_rounded,
            color: _C.navy,
          ),
          const SizedBox(height: 12),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.26,
            children: [
              _StatTile(
                icon: Icons.groups_rounded,
                label: 'Total Staff',
                value: _safe(_summary['total_faculty']),
                color: _C.navyLight,
              ),
              _StatTile(
                icon: Icons.apartment_rounded,
                label: 'Departments',
                value: _safe(_summary['total_departments']),
                color: _C.teal,
              ),
              _StatTile(
                icon: Icons.how_to_reg_rounded,
                label: 'Present Today',
                value: _safe(_summary['present_today']),
                color: _C.success,
              ),
              _StatTile(
                icon: Icons.event_busy_rounded,
                label: 'On Leave Today',
                value: _safe(_summary['on_leave_today']),
                color: _C.gold,
              ),
            ],
          ),

          const SizedBox(height: 24),

          _SectionHeader(
            title: 'Administrative Monitoring',
            subtitle: 'What an actual college admin should watch',
            icon: Icons.monitor_heart_rounded,
            color: _C.purple,
          ),
          const SizedBox(height: 12),
          _buildMonitoringCard(),

          const SizedBox(height: 24),

          _SectionHeader(
            title: 'Administrative Controls',
            subtitle: 'Core admin operations for staffing and institution control',
            icon: Icons.bolt_rounded,
            color: _C.teal,
          ),
          const SizedBox(height: 12),
          _buildActionTile(
            icon: Icons.manage_accounts_rounded,
            iconBg: const Color(0xFFEFF6FF),
            iconColor: _C.navyLight,
            title: 'Faculty Management',
            subtitle: 'Department-wise staff control, HOD, Dean and Operator assignment',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminFacultyScreen()),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildActionTile(
            icon: Icons.analytics_rounded,
            iconBg: _C.successBg,
            iconColor: _C.success,
            title: 'Reports & Analytics',
            subtitle: 'Attendance overview, working hours and institutional metrics',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminReportsScreen()),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildActionTile(
            icon: Icons.event_available_rounded,
            iconBg: _C.goldBg,
            iconColor: _C.gold,
            title: 'Holiday Management',
            subtitle: 'Manage holiday calendar and academic closures',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HolidayListScreen(isAdmin: true),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          _SectionHeader(
            title: 'Department Status',
            subtitle: 'Department-wise staffing, attendance and operational readiness',
            icon: Icons.corporate_fare_rounded,
            color: _C.teal,
          ),
          const SizedBox(height: 12),
          if (_deptStatus.isEmpty)
            _Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No department data available.',
                    style: TextStyle(color: _C.textSub),
                  ),
                ),
              ),
            )
          else
            ..._deptStatus.map((item) {
              final dept = Map<String, dynamic>.from(item as Map);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDeptCard(dept),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    final attendancePercent = _asDouble(_summary['today_attendance_percent']);
    final departments = _safe(_summary['total_departments']);
    final attention = _safe(_summary['departments_needing_attention']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.navy, _C.navyMid, _C.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _C.navy.withOpacity(0.22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    _initials(widget.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _HeaderBtn(
                icon: Icons.refresh_rounded,
                onTap: _loadAdminData,
              ),
              const SizedBox(width: 10),
              _HeaderBtn(
                icon: Icons.logout_rounded,
                onTap: _logout,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _greeting(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.76),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'College Admin • ${_todayLabel()}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.66),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Control staffing, monitor departments, and maintain institutional readiness.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.86),
              fontSize: 13.2,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(
                icon: Icons.apartment_rounded,
                label: '$departments Departments',
              ),
              _HeroPill(
                icon: Icons.verified_user_rounded,
                label: '${attendancePercent.toStringAsFixed(1)}% Attendance',
              ),
              _HeroPill(
                icon: Icons.warning_amber_rounded,
                label: '$attention Need Attention',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringCard() {
    final deanAssigned = _hasDean ? 'Yes' : 'No';
    final hods = _safe(_roleSummary['hod']);
    final operators = _safe(_roleSummary['operator']);
    final onLeave = _safe(_leaveSummary['on_leave_today'], fallback: _safe(_summary['on_leave_today']));
    final needsAttention = _safe(_summary['departments_needing_attention']);

    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniStatTile(
                  label: 'Dean Assigned',
                  value: deanAssigned,
                  icon: Icons.school_rounded,
                  color: _C.purple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatTile(
                  label: 'HODs Assigned',
                  value: hods,
                  icon: Icons.supervisor_account_rounded,
                  color: _C.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniStatTile(
                  label: 'Operators',
                  value: operators,
                  icon: Icons.badge_rounded,
                  color: _C.gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatTile(
                  label: 'On Leave Today',
                  value: onLeave,
                  icon: Icons.event_busy_rounded,
                  color: _C.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _needsAttention > 0 ? _C.dangerBg : _C.successBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _needsAttention > 0
                    ? _C.danger.withOpacity(0.18)
                    : _C.success.withOpacity(0.18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _needsAttention > 0
                        ? _C.danger.withOpacity(0.12)
                        : _C.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _needsAttention > 0
                        ? Icons.priority_high_rounded
                        : Icons.check_circle_rounded,
                    color: _needsAttention > 0 ? _C.danger : _C.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _needsAttention > 0
                        ? '$needsAttention department${needsAttention == "1" ? '' : 's'} need role assignment attention.'
                        : 'All departments look operationally assigned today.',
                    style: TextStyle(
                      color: _needsAttention > 0 ? _C.danger : _C.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _C.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _C.textPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _C.textSub,
                          fontSize: 12.8,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _C.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: _C.textSub,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeptCard(Map<String, dynamic> dept) {
    final needsAttention = (dept['needs_attention'] ?? false) == true;
    final missingRoles = List<dynamic>.from(dept['missing_roles'] ?? []);
    final attendance = _asDouble(dept['attendance_percent']);

    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_C.navy, _C.navyLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _safe(dept['department'], fallback: 'Department'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _C.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_safe(dept['total_staff'])} staff • ${attendance.toStringAsFixed(1)}% present',
                      style: const TextStyle(
                        fontSize: 12.8,
                        color: _C.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: needsAttention ? _C.dangerBg : _C.successBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: needsAttention
                        ? _C.danger.withOpacity(0.18)
                        : _C.success.withOpacity(0.18),
                  ),
                ),
                child: Text(
                  needsAttention ? 'Needs Attention' : 'Ready',
                  style: TextStyle(
                    color: needsAttention ? _C.danger : _C.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DeptStat(
                  label: 'Present',
                  value: _safe(dept['present_today']),
                  color: _C.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DeptStat(
                  label: 'Absent',
                  value: _safe(dept['absent_today']),
                  color: _C.danger,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DeptStat(
                  label: 'On Leave',
                  value: _safe(dept['on_leave_today']),
                  color: _C.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                label: 'HOD: ${_safe(dept['hod_name'], fallback: 'Not Assigned')}',
                color: _C.teal,
                icon: Icons.supervisor_account_rounded,
              ),
              _InfoPill(
                label: 'Operator: ${_safe(dept['operator_name'], fallback: 'Not Assigned')}',
                color: _C.gold,
                icon: Icons.badge_rounded,
              ),
              if (missingRoles.isNotEmpty)
                _InfoPill(
                  label: 'Missing: ${missingRoles.join(', ')}',
                  color: _C.danger,
                  icon: Icons.warning_amber_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderBtn({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _C.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _C.textSub,
                  fontSize: 12.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _C.textSub,
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeptStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DeptStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _InfoPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}