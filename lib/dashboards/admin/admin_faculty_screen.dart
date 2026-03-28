import 'package:flutter/material.dart';

import '../../services/api_service.dart';

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

class AdminFacultyScreen extends StatefulWidget {
  const AdminFacultyScreen({super.key});

  @override
  State<AdminFacultyScreen> createState() => _AdminFacultyScreenState();
}

class _AdminFacultyScreenState extends State<AdminFacultyScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String _search = '';
  List<dynamic> _facultyList = [];

  final Set<String> _expandedDepts = {};

  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear),
    );
    _loadFaculty();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFaculty() async {
    setState(() => _loading = true);

    try {
      final data = await ApiService.getAdminFacultyList();

      if (!mounted) return;

      final grouped = _groupByDepartment(List<dynamic>.from(data));

      setState(() {
        _facultyList = List<dynamic>.from(data);
        _expandedDepts
          ..clear()
          ..addAll(grouped.keys);
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

  Map<String, List<dynamic>> _groupByDepartment(List<dynamic> list) {
    final Map<String, List<dynamic>> grouped = {};

    for (final item in list) {
      final dept = (item['department'] ?? 'Unknown').toString().trim().isEmpty
          ? 'Unknown'
          : item['department'].toString();
      grouped.putIfAbsent(dept, () => []).add(item);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return {
      for (final key in sortedKeys)
        key: grouped[key]!..sort((a, b) {
          final roleA = (a['role'] ?? '').toString().toLowerCase();
          final roleB = (b['role'] ?? '').toString().toLowerCase();

          int rank(String role) {
            switch (role) {
              case 'hod':
                return 0;
              case 'operator':
                return 1;
              case 'dean':
                return 2;
              case 'faculty':
                return 3;
              case 'admin':
                return 4;
              default:
                return 5;
            }
          }

          final diff = rank(roleA).compareTo(rank(roleB));
          if (diff != 0) return diff;

          return (a['name'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo((b['name'] ?? '').toString().toLowerCase());
        }),
    };
  }

  List<dynamic> get _filtered {
    if (_search.trim().isEmpty) return _facultyList;

    final q = _search.toLowerCase();
    return _facultyList.where((item) {
      return (item['name'] ?? '').toString().toLowerCase().contains(q) ||
          (item['email'] ?? '').toString().toLowerCase().contains(q) ||
          (item['faculty_id'] ?? '').toString().toLowerCase().contains(q) ||
          (item['department'] ?? '').toString().toLowerCase().contains(q) ||
          (item['role'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'hod':
        return _C.teal;
      case 'dean':
        return _C.purple;
      case 'operator':
        return _C.gold;
      case 'admin':
        return _C.navy;
      default:
        return _C.success;
    }
  }

  Color _roleBg(String role) {
    switch (role.toLowerCase()) {
      case 'hod':
        return const Color(0xFFE0F2FE);
      case 'dean':
        return _C.purpleBg;
      case 'operator':
        return _C.goldBg;
      case 'admin':
        return const Color(0xFFE2E8F0);
      default:
        return _C.successBg;
    }
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'hod':
        return Icons.supervisor_account_rounded;
      case 'dean':
        return Icons.school_rounded;
      case 'operator':
        return Icons.badge_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'hod':
        return 'HOD';
      case 'dean':
        return 'Dean';
      case 'operator':
        return 'Operator';
      case 'admin':
        return 'Admin';
      default:
        return 'Faculty';
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _doAction({
    required Future<void> Function() action,
    required String success,
  }) async {
    try {
      await action();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success),
          backgroundColor: _C.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      await _loadFaculty();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: _C.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required Color color,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message),
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
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Map<String, dynamic> _deptStats(List<dynamic> members) {
    String hod = 'Not Assigned';
    String operator = 'Not Assigned';
    int facultyCount = 0;
    int deanCount = 0;

    for (final m in members) {
      final role = (m['role'] ?? '').toString().toLowerCase();
      final name = (m['name'] ?? 'Unknown').toString();

      if (role == 'hod') hod = name;
      if (role == 'operator') operator = name;
      if (role == 'faculty') facultyCount++;
      if (role == 'dean') deanCount++;
    }

    return {
      'hod': hod,
      'operator': operator,
      'facultyCount': facultyCount,
      'deanCount': deanCount,
      'needsAttention': hod == 'Not Assigned' || operator == 'Not Assigned',
    };
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDepartment(_filtered);

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _C.navy,
          onRefresh: _loadFaculty,
          child: _loading
              ? _buildShimmer()
              : CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(grouped)),
              if (grouped.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: _C.textMuted,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No faculty found.',
                          style: TextStyle(
                            color: _C.textSub,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final entry = grouped.entries.elementAt(index);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildDeptSection(entry.key, entry.value),
                        );
                      },
                      childCount: grouped.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, List<dynamic>> grouped) {
    final totalFaculty = _facultyList.length;
    final totalDepts = grouped.length;
    final hodCount = _facultyList
        .where((f) => (f['role'] ?? '').toString().toLowerCase() == 'hod')
        .length;
    final operatorCount = _facultyList
        .where((f) => (f['role'] ?? '').toString().toLowerCase() == 'operator')
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _C.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.border),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: _C.navy,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Faculty Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _C.navy,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Department-wise staff administration',
                      style: TextStyle(
                        fontSize: 13,
                        color: _C.textSub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_C.navy, _C.navyMid, _C.navyLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _C.navy.withOpacity(0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Real College Admin View',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Manage staff structure department-wise. Assign HOD, Dean and Operator roles from one place.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.86),
                    fontSize: 12.8,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SummaryPill(
                      label: 'Total',
                      value: '$totalFaculty',
                      color: Colors.white,
                      darkBg: true,
                    ),
                    _SummaryPill(
                      label: 'Departments',
                      value: '$totalDepts',
                      color: Colors.white,
                      darkBg: true,
                    ),
                    _SummaryPill(
                      label: 'HODs',
                      value: '$hodCount',
                      color: Colors.white,
                      darkBg: true,
                    ),
                    _SummaryPill(
                      label: 'Operators',
                      value: '$operatorCount',
                      color: Colors.white,
                      darkBg: true,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Container(
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _C.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              style: const TextStyle(
                color: _C.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _C.textMuted,
                ),
                hintText: 'Search name, ID, email, department, role…',
                hintStyle: const TextStyle(
                  color: _C.textMuted,
                  fontSize: 13.5,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 15,
                ),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    color: _C.textMuted,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _search = ''),
                )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeptSection(String dept, List<dynamic> members) {
    final isExpanded = _expandedDepts.contains(dept);
    final stats = _deptStats(members);
    final needsAttention = stats['needsAttention'] == true;

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedDepts.remove(dept);
              } else {
                _expandedDepts.add(dept);
              }
            }),
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(22))
                : BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
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
                              dept,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _C.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${members.length} member${members.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: _C.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
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
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _C.bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _C.textSub,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniPill(
                        icon: Icons.supervisor_account_rounded,
                        label: 'HOD: ${stats['hod']}',
                        color: _C.teal,
                      ),
                      _MiniPill(
                        icon: Icons.badge_rounded,
                        label: 'Operator: ${stats['operator']}',
                        color: _C.gold,
                      ),
                      _MiniPill(
                        icon: Icons.person_rounded,
                        label: '${stats['facultyCount']} Faculty',
                        color: _C.navyLight,
                      ),
                      if ((stats['deanCount'] as int) > 0)
                        _MiniPill(
                          icon: Icons.school_rounded,
                          label: '${stats['deanCount']} Dean',
                          color: _C.purple,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState:
            isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                Divider(height: 1, color: _C.border),
                ...members.asMap().entries.map((entry) {
                  final index = entry.key;
                  final user = entry.value;
                  return _FacultyTile(
                    user: user,
                    isLast: index == members.length - 1,
                    onAction: _doAction,
                    onConfirm: _confirmDialog,
                    roleColor: _roleColor,
                    roleBg: _roleBg,
                    roleIcon: _roleIcon,
                    roleLabel: _roleLabel,
                    initials: _initials,
                  );
                }),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: List.generate(
          4,
              (_) => Container(
            margin: const EdgeInsets.only(bottom: 14),
            height: 170,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
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
          ),
        ),
      ),
    );
  }
}

class _FacultyTile extends StatelessWidget {
  final dynamic user;
  final bool isLast;
  final Future<void> Function({
  required Future<void> Function() action,
  required String success,
  }) onAction;
  final Future<bool> Function({
  required String title,
  required String message,
  required Color color,
  }) onConfirm;
  final Color Function(String) roleColor;
  final Color Function(String) roleBg;
  final IconData Function(String) roleIcon;
  final String Function(String) roleLabel;
  final String Function(String) initials;

  const _FacultyTile({
    required this.user,
    required this.isLast,
    required this.onAction,
    required this.onConfirm,
    required this.roleColor,
    required this.roleBg,
    required this.roleIcon,
    required this.roleLabel,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final role = (user['role'] ?? '').toString();
    final name = (user['name'] ?? '').toString();
    final facultyId = (user['faculty_id'] ?? '').toString();
    final email = (user['email'] ?? '').toString();
    final department = (user['department'] ?? '').toString();

    final rColor = roleColor(role);
    final rBg = roleBg(role);
    final rIcon = roleIcon(role);
    final rLabel = roleLabel(role);

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
          bottom: BorderSide(color: Color(0xFFE4EAF4)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: rBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      initials(name),
                      style: TextStyle(
                        color: rColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _C.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            size: 12,
                            color: _C.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            facultyId,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _C.textSub,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            size: 12,
                            color: _C.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              email,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _C.textSub,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.apartment_rounded,
                            size: 12,
                            color: _C.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              department,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _C.textSub,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: rBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: rColor.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(rIcon, color: rColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        rLabel,
                        style: TextStyle(
                          color: rColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (role.toLowerCase() != 'admin') ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (role.toLowerCase() != 'hod')
                    _ActionBtn(
                      label: 'Make HOD',
                      icon: Icons.supervisor_account_rounded,
                      color: _C.teal,
                      onTap: () async {
                        final ok = await onConfirm(
                          title: 'Assign as HOD',
                          message:
                          'Make $name the HOD of their department? The current HOD will be reverted to Faculty.',
                          color: _C.teal,
                        );
                        if (ok) {
                          await onAction(
                            action: () => ApiService.upgradeToHod(facultyId),
                            success: '$name is now the HOD',
                          );
                        }
                      },
                    ),
                  if (role.toLowerCase() != 'dean')
                    _ActionBtn(
                      label: 'Make Dean',
                      icon: Icons.school_rounded,
                      color: _C.purple,
                      onTap: () async {
                        final ok = await onConfirm(
                          title: 'Promote to Dean',
                          message:
                          'Promote $name to Dean? The existing Dean will be reverted to Faculty.',
                          color: _C.purple,
                        );
                        if (ok) {
                          await onAction(
                            action: () => ApiService.upgradeToDean(facultyId),
                            success: '$name promoted to Dean',
                          );
                        }
                      },
                    ),
                  if (role.toLowerCase() != 'operator' &&
                      role.toLowerCase() != 'dean')
                    _ActionBtn(
                      label: 'Assign Operator',
                      icon: Icons.badge_rounded,
                      color: _C.gold,
                      onTap: () async {
                        final ok = await onConfirm(
                          title: 'Assign as Operator',
                          message:
                          'Assign $name as the Operator for their department?',
                          color: _C.gold,
                        );
                        if (ok) {
                          await onAction(
                            action: () => ApiService.assignOperator(facultyId),
                            success: '$name assigned as Operator',
                          );
                        }
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool darkBg;

  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
    this.darkBg = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = darkBg ? Colors.white.withOpacity(0.14) : color.withOpacity(0.10);
    final borderColor =
    darkBg ? Colors.white.withOpacity(0.16) : color.withOpacity(0.20);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: darkBg ? Colors.white : color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: darkBg ? _C.navy : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
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

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}