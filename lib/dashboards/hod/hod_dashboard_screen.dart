import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../faculty_docs_screens/certificates_screen.dart';
import '../../faculty_docs_screens/home_screen.dart';
import '../../providers/certificate_provider.dart';
import '../../providers/document_provider.dart';
import '../../screens/attendance/attendance_menu_screen.dart';
import '../../screens/holidays/holiday_list_screen.dart';
import '../../screens/leave/leave_approval_screen.dart';
import '../../screens/leave/leave_history_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/schedule/schedule_screen.dart';
import '../../services/api_service.dart';
import '../../services/app_config.dart';
import '../../services/token_service.dart';
import 'department_faculty_section.dart';

// ─── Colour Palette ────────────────────────────────────────────────────────────
class _C {
  static const navy      = Color(0xFF0A2342);
  static const navyMid   = Color(0xFF1B3F72);
  static const navyLight = Color(0xFF2E5FA3);
  static const teal      = Color(0xFF0077B6);
  static const tealLight = Color(0xFF00B4D8);
  static const bg        = Color(0xFFF2F5FB);
  static const card      = Color(0xFFFFFFFF);
  static const border    = Color(0xFFE4EAF4);
  static const success   = Color(0xFF0A7953);
  static const successBg = Color(0xFFE6F4EF);
  static const danger    = Color(0xFFB91C1C);
  static const dangerBg  = Color(0xFFFEE2E2);
  static const gold      = Color(0xFFB45309);
  static const goldBg    = Color(0xFFFEF3C7);
  static const purple    = Color(0xFF6D28D9);
  static const orange    = Color(0xFFE65100);
  static const textPrimary = Color(0xFF0F172A);
  static const textSub     = Color(0xFF64748B);
  static const textMuted   = Color(0xFF94A3B8);
}

Color _slotColor(String type) {
  switch (type.toUpperCase()) {
    case 'LAB':    return const Color(0xFF4F46E5);
    case 'THEORY': return _C.navy;
    case 'FIP':    return _C.success;
    case 'THUB':   return _C.gold;
    case 'PSA':    return const Color(0xFF6A1B9A);
    default:       return _C.textSub;
  }
}

// ─── Main Widget ───────────────────────────────────────────────────────────────
class HodDashboardScreen extends StatefulWidget {
  final String name;
  final String department;
  final String email;
  final String facultyId;
  final String? designation;
  final String? qualification;
  final String? profileImage;

  const HodDashboardScreen({
    super.key,
    required this.name,
    required this.department,
    this.email      = '',
    this.facultyId  = '',
    this.designation,
    this.qualification,
    this.profileImage,
  });

  @override
  State<HodDashboardScreen> createState() => _HodDashboardScreenState();
}

class _HodDashboardScreenState extends State<HodDashboardScreen>
    with TickerProviderStateMixin {

  // ── nav ──
  int _currentIndex = 0;

  // ── state ──
  DateTime _today = DateTime.now();

  Map<String, dynamic> _leaveBalance       = {};
  bool _loadingBalance                     = true;

  Map<String, dynamic>? _todayAttendance;
  bool _loadingAttendance                  = true;

  List<Map<String, dynamic>> _todaySlots   = [];
  bool _loadingSchedule                    = true;

  List<dynamic> _todayLeaves               = [];
  bool _loadingLeaves                      = true;

  Map<String, dynamic> _leaveStats         = {};
  bool _loadingStats                       = true;

  // Dept faculty — used on Home tab
  List<dynamic> _deptFaculty               = [];
  bool _loadingDeptFaculty                 = true;

  // ── animations ──
  late final AnimationController _headerCtrl;
  late final AnimationController _staggerCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _shimmerCtrl;

  late final Animation<Offset> _headerSlide;
  late final Animation<double>  _headerFade;
  late final Animation<double>  _pulse;
  late final Animation<double>  _shimmer;

  Timer? _refreshTimer;

  // ── period time labels ──
  static const _periodTimes = [
    '09:30','10:20','11:10','12:00',
    '13:00','13:50','14:40','15:30',
  ];

  // ── today weekday index (Mon=0 … Sat=5) ──
  int get _todayDayIndex {
    final w = DateTime.now().weekday;
    return w >= 1 && w <= 6 ? w - 1 : 0;
  }

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));
    _headerFade  = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeIn));

    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.82, end: 1.18)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 1.5)
        .animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear));

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _staggerCtrl.forward();
    });

    _refresh();

    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _loadStats();
      _loadTodayLeaves();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _headerCtrl.dispose();
    _staggerCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ─── Data loaders ──────────────────────────────────────────────────────────
  Future<void> _refresh() async {
    await Future.wait([
      _loadAttendance(),
      _loadBalance(),
      _loadTodayLeaves(),
      _loadStats(),
      _loadTodaySchedule(),
      _loadDeptFaculty(),
    ]);
  }

  Future<void> _loadBalance() async {
    try {
      final d = await ApiService.getLeaveBalance();
      if (!mounted) return;
      setState(() { _leaveBalance = Map<String, dynamic>.from(d); _loadingBalance = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _loadAttendance() async {
    try {
      final d = await ApiService.getTodayAttendanceStatus();
      if (!mounted) return;
      setState(() { _todayAttendance = Map<String, dynamic>.from(d); _loadingAttendance = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingAttendance = false;
        _todayAttendance = {
          'status': 'ERROR',
          'message': 'Unable to load',
          'clock_in_time': null,
          'clock_out_time': null,
          'working_hours': 0,
        };
      });
    }
  }

  Future<void> _loadStats() async {
    try {
      final d = await ApiService.getLeaveStats();
      if (!mounted) return;
      setState(() { _leaveStats = Map<String, dynamic>.from(d); _loadingStats = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _loadTodayLeaves() async {
    try {
      final d = await ApiService.getTodayDepartmentLeaves();
      if (!mounted) return;
      setState(() { _todayLeaves = List<dynamic>.from(d); _loadingLeaves = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingLeaves = false);
    }
  }

  Future<void> _loadTodaySchedule() async {
    if (widget.facultyId.trim().isEmpty) {
      if (mounted) setState(() => _loadingSchedule = false);
      return;
    }
    try {
      final token = await TokenService.getToken();
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/timetable/faculty/${widget.facultyId.trim()}/schedule'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final all = (data['schedule'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) {
          final t = (e['slot_type'] ?? '').toString().toUpperCase();
          return t != 'LUNCH' && t != 'BLOCKED';
        })
            .where((e) => (e['day_index'] ?? e['day']) == _todayDayIndex)
            .toList()
          ..sort((a, b) => (a['period'] as int? ?? 0).compareTo(b['period'] as int? ?? 0));
        setState(() { _todaySlots = all; _loadingSchedule = false; });
      } else {
        setState(() => _loadingSchedule = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSchedule = false);
    }
  }

  /// Uses /faculty-list — HOD gets dept-filtered list from the backend
  Future<void> _loadDeptFaculty() async {
    try {
      final data = await ApiService.getFacultyList();
      if (!mounted) return;
      setState(() {
        _deptFaculty = List<dynamic>.from(data);
        _loadingDeptFaculty = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDeptFaculty = false);
    }
  }

  // ─── Navigation helpers ────────────────────────────────────────────────────
  void _openDocs() => Navigator.push(context, MaterialPageRoute(
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ChangeNotifierProvider(create: (_) => CertificateProvider()),
      ],
      child: HomeScreen(facultyName: widget.name),
    ),
  ));

  void _openCerts() => Navigator.push(context, MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider(
      create: (_) => CertificateProvider(),
      child: CertificatesScreen(facultyName: widget.name),
    ),
  ));

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              TokenService.clearToken();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // ─── Stagger animation helper ──────────────────────────────────────────────
  Animation<double> _stag(int i) {
    final s = (i * 0.10).clamp(0.0, 0.75);
    final e = (s + 0.35).clamp(s + 0.01, 1.0);
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerCtrl, curve: Interval(s, e, curve: Curves.easeOutCubic)),
    );
  }

  Widget _sw(int i, Widget child) => AnimatedBuilder(
    animation: _staggerCtrl,
    builder: (_, __) => Transform.translate(
      offset: Offset(0, 36 * (1 - _stag(i).value)),
      child: Opacity(opacity: _stag(i).value, child: child),
    ),
  );

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _homeTab(),
      AttendanceMenuScreen(email: widget.email),
      _leavesTab(),
      ScheduleScreen(facultyId: widget.facultyId),
      _profileTab(),
    ];

    return Scaffold(
      backgroundColor: _C.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(key: ValueKey(_currentIndex), child: pages[_currentIndex]),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── Bottom Nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      {'icon': Icons.home_rounded,              'label': 'Home'},
      {'icon': Icons.fingerprint_rounded,        'label': 'Attendance'},
      {'icon': Icons.event_note_rounded,         'label': 'Leaves'},
      {'icon': Icons.calendar_view_week_rounded, 'label': 'Schedule'},
      {'icon': Icons.person_rounded,             'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: _C.navy.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final sel = _currentIndex == i;
              return GestureDetector(
                onTap: () async {
                  setState(() => _currentIndex = i);
                  if (i == 0) await _refresh();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  padding: sel
                      ? const EdgeInsets.symmetric(horizontal: 16, vertical: 9)
                      : const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: sel ? const LinearGradient(colors: [_C.navy, _C.navyLight]) : null,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(items[i]['icon']! as IconData, color: sel ? Colors.white : _C.textMuted, size: 22),
                      if (sel) ...[
                        const SizedBox(width: 6),
                        Text(items[i]['label']! as String,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  HOME TAB
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _homeTab() {
    return SafeArea(
      child: RefreshIndicator(
        color: _C.navy,
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: Column(
            children: [
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _headerCtrl,
                builder: (_, __) => SlideTransition(
                  position: _headerSlide,
                  child: FadeTransition(opacity: _headerFade, child: _buildHero()),
                ),
              ),
              const SizedBox(height: 22),
              _sw(0, _buildCalendarCard()),
              const SizedBox(height: 18),
              _sw(1, _buildScheduleCard()),
              const SizedBox(height: 18),
              _sw(2, _buildLogsCard()),
              const SizedBox(height: 18),
              _sw(3, _buildLeaveBalanceCard()),
              const SizedBox(height: 18),
              // ── Department Faculty List (HOD — moved from profile to home) ──
              _sw(4, _buildDeptFacultyCard()),
              const SizedBox(height: 18),
              // ── Faculty on Leave Today ──
              _sw(5, _buildTodayLeavesCard()),
              const SizedBox(height: 18),
              _sw(6, _buildHolidaysBanner()),
              const SizedBox(height: 18),
              _sw(7, _buildResourcesSection()),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Hero Header ───────────────────────────────────────────────────────────
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.navy, _C.navyMid, _C.navyLight],
        ),
        boxShadow: [BoxShadow(color: _C.navy.withOpacity(0.45), blurRadius: 28, offset: const Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Positioned(top: -28, right: -18,  child: _circle(120, Colors.white.withOpacity(0.05))),
          Positioned(bottom: -35, right: 50, child: _circle(85,  Colors.white.withOpacity(0.04))),
          Positioned(top: 12,  left: -28,   child: _circle(75,  Colors.white.withOpacity(0.04))),
          Positioned(top: -20, left: 80,    child: _circle(55,  const Color(0xFFD4A017).withOpacity(0.07))),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Online dot
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Transform.scale(
                        scale: _pulse.value,
                        child: Container(
                          width: 9, height: 9,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF34D399)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text('Online',
                        style: TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                    const Spacer(),
                    // Notification-style refresh icon
                    GestureDetector(
                      onTap: _refresh,
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.18)),
                        ),
                        child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Good ${_greeting()}, 👋',
                    style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 13, letterSpacing: 0.2)),
                const SizedBox(height: 5),
                Text(widget.name,
                    style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3, height: 1.2)),
                const SizedBox(height: 4),
                if (widget.department.isNotEmpty)
                  Text(widget.department, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
                const SizedBox(height: 16),
                // HOD shimmer badge
                AnimatedBuilder(
                  animation: _shimmer,
                  builder: (_, __) => ShaderMask(
                    shaderCallback: (b) => LinearGradient(
                      colors: const [Colors.white, Color(0xFFFFD68A), Colors.white],
                      stops: [
                        (_shimmer.value - 0.3).clamp(0.0, 1.0),
                        (_shimmer.value).clamp(0.0, 1.0),
                        (_shimmer.value + 0.3).clamp(0.0, 1.0),
                      ],
                    ).createShader(b),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.11),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: const Color(0xFFD4A017).withOpacity(0.40)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.domain_rounded, color: Colors.white, size: 13),
                          SizedBox(width: 6),
                          Text('HEAD OF DEPARTMENT',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.3)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Quick stats row
                Row(
                  children: [
                    _heroStat(
                      icon: Icons.groups_rounded,
                      label: 'Faculty',
                      value: _loadingDeptFaculty ? '—' : '${_deptFaculty.length}',
                      color: _C.tealLight,
                    ),
                    const SizedBox(width: 10),
                    _heroStat(
                      icon: Icons.event_busy_rounded,
                      label: 'On Leave',
                      value: _loadingLeaves ? '—' : '${_todayLeaves.length}',
                      color: const Color(0xFFFC9D3A),
                    ),
                    const SizedBox(width: 10),
                    _heroStat(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pending',
                      value: _loadingStats ? '—' : '${_leaveStats['pending'] ?? 0}',
                      color: const Color(0xFFA78BFA),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat({required IconData icon, required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 5),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ─── Calendar Card ─────────────────────────────────────────────────────────
  Widget _buildCalendarCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(title: 'Calendar', icon: Icons.calendar_month_rounded, color: _C.teal),
          const SizedBox(height: 10),
          TableCalendar(
            focusedDay: _today,
            firstDay: DateTime.utc(2020),
            lastDay:  DateTime.utc(2030),
            calendarFormat: CalendarFormat.week,
            headerVisible: false,
            selectedDayPredicate: (d) => isSameDay(d, _today),
            onDaySelected: (sel, foc) => setState(() => _today = sel),
            calendarStyle: CalendarStyle(
              todayDecoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: _C.teal,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _C.teal.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              weekendTextStyle: const TextStyle(color: Color(0xFFDC2626)),
              defaultTextStyle: const TextStyle(color: _C.textPrimary, fontWeight: FontWeight.w500),
              todayTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: _C.textSub, fontSize: 12, fontWeight: FontWeight.w600),
              weekendStyle: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Today's Classes Card ──────────────────────────────────────────────────
  Widget _buildScheduleCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Header(title: "Today's Classes", icon: Icons.class_rounded, color: _C.teal),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _currentIndex = 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _C.teal.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Text('Full Schedule', style: TextStyle(fontSize: 11, color: _C.teal, fontWeight: FontWeight.w700)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _C.teal),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingSchedule)
            _shimmerRows(3, 56)
          else if (_todaySlots.isEmpty)
            _noClasses()
          else
            ..._todaySlots.map((slot) {
              final period = slot['period'] as int? ?? 0;
              final time   = period < _periodTimes.length ? _periodTimes[period] : '—';
              final subj   = slot['subject']?.toString() ?? slot['subject_abbr']?.toString() ?? 'Class';
              final room   = slot['room']?.toString() ?? '—';
              final section = slot['section_name']?.toString() ?? '';
              final type   = slot['slot_type']?.toString() ?? 'THEORY';
              final color  = _slotColor(type);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.12)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(width: 4, height: 50, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(time, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                          const SizedBox(height: 4),
                          Text(subj, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _C.textPrimary)),
                          if (section.isNotEmpty)
                            Text(section, style: const TextStyle(fontSize: 11, color: _C.textSub, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
                          child: Text(room, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                          child: Text(type, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _noClasses() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: _C.teal.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.free_breakfast_rounded, color: _C.teal, size: 22),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No classes today', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _C.textPrimary)),
              SizedBox(height: 2),
              Text('Enjoy your free day', style: TextStyle(fontSize: 12, color: _C.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Today's Logs (Attendance) Card ───────────────────────────────────────
  Widget _buildLogsCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(title: "Today's Logs", icon: Icons.receipt_long_rounded, color: _C.gold),
          const SizedBox(height: 14),
          _loadingAttendance ? _shimmerRows(1, 80) : _logsContent(),
        ],
      ),
    );
  }

  Widget _logsContent() {
    final status    = _todayAttendance?['status'] ?? 'UNKNOWN';
    final isPresent = status == 'PRESENT' || status == 'CHECKED_IN';
    final sColor    = isPresent ? _C.success : _C.danger;
    final sBg       = isPresent ? _C.successBg : _C.dangerBg;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: sBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sColor.withOpacity(0.20)),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Transform.scale(
                  scale: isPresent ? _pulse.value : 1.0,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: sColor.withOpacity(0.12)),
                    child: Icon(isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded, color: sColor, size: 26),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: sColor)),
                    const SizedBox(height: 2),
                    Text((_todayAttendance?['message'] ?? '-').toString(),
                        style: const TextStyle(fontSize: 12, color: _C.textSub)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _TimeChip(label: 'Clock In',   value: (_todayAttendance?['clock_in_time']  ?? '--').toString(), icon: Icons.login_rounded,  color: _C.success)),
            const SizedBox(width: 10),
            Expanded(child: _TimeChip(label: 'Clock Out',  value: (_todayAttendance?['clock_out_time'] ?? '--').toString(), icon: Icons.logout_rounded, color: _C.danger)),
            const SizedBox(width: 10),
            Expanded(child: _TimeChip(label: 'Hrs Worked', value: '${_todayAttendance?['working_hours'] ?? 0}h', icon: Icons.timer_rounded, color: _C.teal)),
          ],
        ),
      ],
    );
  }

  // ─── Leave Balance Card ────────────────────────────────────────────────────
  Widget _buildLeaveBalanceCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(title: 'My Leave Balance', icon: Icons.event_note_rounded, color: _C.purple),
          const SizedBox(height: 16),
          _loadingBalance
              ? _shimmerRows(1, 70)
              : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DonutStat(label: 'Allowed',   value: int.tryParse(_leaveBalance['total_allowed']?.toString() ?? '0') ?? 0, color: _C.navyLight),
              _DonutStat(label: 'Used',       value: int.tryParse(_leaveBalance['used']?.toString()          ?? '0') ?? 0, color: _C.danger),
              _DonutStat(label: 'Remaining',  value: int.tryParse(_leaveBalance['remaining']?.toString()     ?? '0') ?? 0, color: _C.success),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Department Faculty Card (HOME TAB — compact summary with navigation) ──
  Widget _buildDeptFacultyCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Header(title: 'Department Faculty', icon: Icons.groups_rounded, color: _C.navyMid),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.navyMid.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFD4A017))),
                    const SizedBox(width: 5),
                    const Text('HOD View', style: TextStyle(fontSize: 10, color: _C.navyMid, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingDeptFaculty)
            _shimmerRows(1, 72)
          else if (_deptFaculty.isEmpty)
            _emptyRow(Icons.person_off_rounded, 'No faculty found')
          else ...[
              Row(
                children: [
                  SizedBox(
                    width: _deptFaculty.take(5).length * 30.0 + 12,
                    height: 44,
                    child: Stack(
                      children: List.generate(
                        _deptFaculty.take(5).length,
                            (i) {
                          final name = (_deptFaculty[i]['name'] ?? '').toString();
                          final initials = _initials(name);
                          return Positioned(
                            left: i * 28.0,
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [
                                  _C.navyMid.withOpacity(0.85), _C.navyLight,
                                ]),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Text(initials,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_deptFaculty.length} Members',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _C.textPrimary)),
                        Text(widget.department,
                            style: const TextStyle(fontSize: 12, color: _C.textMuted, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildRoleBreakdown(),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DepartmentFacultyScreen(
                      facultyList: _deptFaculty,
                      departmentName: widget.department,
                    ),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_C.navy, _C.navyLight],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: _C.navy.withOpacity(0.28), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_alt_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 9),
                      Text('See Faculty Details',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 13),
                    ],
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildRoleBreakdown() {
    final counts = <String, int>{};
    for (final f in _deptFaculty) {
      final role = (f['role'] ?? 'faculty').toString().toLowerCase();
      String label;
      switch (role) {
        case 'hod':      label = 'HOD';      break;
        case 'dean':     label = 'Dean';     break;
        case 'operator': label = 'Operator'; break;
        default:         label = 'Faculty';
      }
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final pairs = counts.entries.toList();
    final colors = <String, Color>{
      'HOD': _C.navy, 'Dean': _C.teal, 'Operator': _C.gold, 'Faculty': _C.success,
    };
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: pairs.map((e) {
        final color = colors[e.key] ?? _C.success;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${e.key}  ${e.value}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Faculty on Leave Today Card ───────────────────────────────────────────
  Widget _buildTodayLeavesCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Header(
                title: 'Faculty on Leave Today',
                icon: Icons.event_busy_rounded,
                color: _todayLeaves.isEmpty ? _C.success : _C.danger,
              ),
              const Spacer(),
              if (!_loadingLeaves && _todayLeaves.isNotEmpty)
                _countBadge(_todayLeaves.length, _C.danger),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingLeaves)
            _shimmerRows(2, 52)
          else if (_todayLeaves.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _C.successBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.success.withOpacity(0.20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _C.success.withOpacity(0.12)),
                    child: const Icon(Icons.check_circle_rounded, color: _C.success, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('All faculty present today',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.success)),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _todayLeaves.map<Widget>((leave) {
                final name      = (leave['faculty_name'] ?? '').toString();
                final leaveType = (leave['leave_type']   ?? '').toString();
                final start     = (leave['start_date']   ?? '').toString();
                final end       = (leave['end_date']     ?? '').toString();
                final initials  = _initials(name);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _C.dangerBg.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.danger.withOpacity(0.13)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _C.danger.withOpacity(0.12),
                        child: Text(initials, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _C.danger)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _C.textPrimary)),
                            if (start.isNotEmpty && end.isNotEmpty)
                              Text('$start → $end', style: const TextStyle(fontSize: 11, color: _C.textSub, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _C.goldBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(leaveType,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.gold)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ─── Holidays Banner ───────────────────────────────────────────────────────
  Widget _buildHolidaysBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HolidayListScreen(isAdmin: false))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0A4F7A), Color(0xFF0077B6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _C.teal.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 7))],
        ),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.celebration_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Holidays', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  SizedBox(height: 3),
                  Text('View holiday list & calendar', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Resources Section ─────────────────────────────────────────────────────
  Widget _buildResourcesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text('Resources', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.textPrimary)),
        ),
        Row(
          children: [
            Expanded(child: _ResourceCard(
              title: 'Faculty Docs', subtitle: 'Notes, Assignments\n& Study Material',
              icon: Icons.folder_open_rounded,
              gradient: const [Color(0xFF0A2342), Color(0xFF2E5FA3)],
              glowColor: _C.navy,
              onTap: _openDocs,
            )),
            const SizedBox(width: 14),
            Expanded(child: _ResourceCard(
              title: 'Certificates', subtitle: 'Achievements &\nTraining Records',
              icon: Icons.workspace_premium_rounded,
              gradient: const [Color(0xFF5B21B6), Color(0xFF7C3AED)],
              glowColor: const Color(0xFF7C3AED),
              onTap: _openCerts,
            )),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  LEAVES TAB
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _leavesTab() {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leaves',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _C.textPrimary, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            const Text('Manage your leaves & approve requests',
                style: TextStyle(fontSize: 13, color: _C.textSub)),
            const SizedBox(height: 24),

            // My Leaves
            _LeaveActionCard(
              title: 'My Leaves',
              subtitle: 'View your leave history,\nstatus & applied leaves',
              icon: Icons.event_note_rounded,
              gradient: const [Color(0xFF0A7953), Color(0xFF0D9A69)],
              glowColor: const Color(0xFF0A7953),
              badgeLabel: 'History', badgeColor: const Color(0xFFE6F4EF), badgeTextColor: const Color(0xFF0A7953),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveHistoryScreen())),
            ),
            const SizedBox(height: 16),

            // Leave Requests (HOD approval)
            _LeaveActionCard(
              title: 'Leave Requests',
              subtitle: 'Review & approve faculty\nleave applications',
              icon: Icons.assignment_turned_in_rounded,
              gradient: const [Color(0xFF9A3412), Color(0xFFEA580C)],
              glowColor: const Color(0xFFEA580C),
              badgeLabel: 'Approvals', badgeColor: const Color(0xFFFFF7ED), badgeTextColor: const Color(0xFFE65100),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveApprovalScreen(role: 'hod'))),
            ),
            const SizedBox(height: 24),

            // Faculty Leave Request Stats
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Header(title: 'Faculty Leave Request Stats', icon: Icons.bar_chart_rounded, color: _C.purple),
                  const SizedBox(height: 4),
                  const Text('Department-wide faculty leave request overview',
                      style: TextStyle(fontSize: 11, color: _C.textMuted, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  _loadingStats
                      ? _shimmerRows(1, 70)
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _DonutStat(label: 'Pending',  value: int.tryParse(_leaveStats['pending']?.toString()  ?? '0') ?? 0, color: _C.gold),
                      _DonutStat(label: 'Approved', value: int.tryParse(_leaveStats['approved']?.toString() ?? '0') ?? 0, color: _C.success),
                      _DonutStat(label: 'Rejected', value: int.tryParse(_leaveStats['rejected']?.toString() ?? '0') ?? 0, color: _C.danger),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  PROFILE TAB  (no dept faculty list — moved to home)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _profileTab() {
    final initials = _initials(widget.name);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Column(
          children: [
            // ── Profile Hero Card ──────────────────────────────────────────
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF0A1929), Color(0xFF0D2B4E), Color(0xFF1B4080)],
                    ),
                    boxShadow: [BoxShadow(color: _C.navy.withOpacity(0.45), blurRadius: 28, offset: const Offset(0, 10))],
                  ),
                  child: Stack(
                    children: [
                      Positioned(top: -20, right: -10, child: _circle(90, Colors.white.withOpacity(0.04))),
                      Positioned(bottom: -30, left: 20, child: _circle(70, Colors.white.withOpacity(0.03))),
                      Column(
                        children: [
                          // Avatar
                          Container(
                            width: 92, height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)]),
                              border: Border.all(color: const Color(0xFFD4A017).withOpacity(0.55), width: 2.5),
                              boxShadow: [BoxShadow(color: const Color(0xFF0D47A1).withOpacity(0.40), blurRadius: 18, offset: const Offset(0, 6))],
                            ),
                            child: Center(
                              child: widget.profileImage != null && widget.profileImage!.isNotEmpty
                                  ? ClipOval(
                                child: (() {
                                  try {
                                    return Image.memory(
                                      base64Decode(widget.profileImage!),
                                      width: 92, height: 92, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Text(initials,
                                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                                    );
                                  } catch (_) {
                                    return Text(initials,
                                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white));
                                  }
                                })(),
                              )
                                  : Text(initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(widget.name, textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2)),
                          const SizedBox(height: 4),
                          if (widget.facultyId.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.18)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.badge_rounded, color: Colors.white.withOpacity(0.65), size: 12),
                                  const SizedBox(width: 5),
                                  Text(widget.facultyId,
                                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.80), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                          const SizedBox(height: 6),
                          if (widget.department.isNotEmpty)
                            Text(widget.department,
                                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.58))),
                          if (widget.designation != null && widget.designation!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(widget.designation!,
                                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.48))),
                          ],
                          const SizedBox(height: 14),
                          // HOD badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4A017).withOpacity(0.16),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFD4A017).withOpacity(0.42)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.domain_rounded, color: Color(0xFFD4A017), size: 13),
                                SizedBox(width: 6),
                                Text('Head of Department',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD4A017), letterSpacing: 0.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Edit button
                Positioned(
                  top: 14, right: 14,
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        name: widget.name, email: widget.email,
                        designation: widget.designation, qualification: widget.qualification,
                      ),
                    )),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.22)),
                      ),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 17),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Profile Info Card ──────────────────────────────────────────
            _ProfileInfoCard(rows: [
              _ProfileRow(icon: Icons.person_rounded,       label: 'Full Name',    value: widget.name,         color: _C.navy),
              _ProfileRow(icon: Icons.business_rounded,     label: 'Department',   value: widget.department,   color: _C.teal),
              if (widget.email.isNotEmpty)
                _ProfileRow(icon: Icons.email_rounded,      label: 'Email',        value: widget.email,        color: _C.purple),
              if (widget.facultyId.isNotEmpty)
                _ProfileRow(icon: Icons.badge_rounded,      label: 'Faculty ID',   value: widget.facultyId,    color: _C.navyLight),
              if (widget.designation != null && widget.designation!.isNotEmpty)
                _ProfileRow(icon: Icons.work_rounded,       label: 'Designation',  value: widget.designation!, color: _C.gold),
              if (widget.qualification != null && widget.qualification!.isNotEmpty)
                _ProfileRow(icon: Icons.school_rounded,     label: 'Qualification',value: widget.qualification!,color: _C.success),
              const _ProfileRow(icon: Icons.verified_user_rounded, label: 'Role', value: 'Head of Department (HOD)', color: Color(0xFFE65100)),
            ]),
            const SizedBox(height: 16),

            // ── Quick Links Card ───────────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Header(title: 'Quick Links', icon: Icons.grid_view_rounded, color: _C.navy),
                  const SizedBox(height: 14),
                  _ProfileLinkRow(icon: Icons.fingerprint_rounded,         label: 'My Attendance',  color: _C.teal,    onTap: () => setState(() => _currentIndex = 1)),
                  const _Divider(),
                  _ProfileLinkRow(icon: Icons.event_note_rounded,          label: 'My Leaves',      color: _C.success, onTap: () => setState(() => _currentIndex = 2)),
                  const _Divider(),
                  _ProfileLinkRow(icon: Icons.calendar_view_week_rounded,  label: 'My Schedule',    color: _C.teal,    onTap: () => setState(() => _currentIndex = 3)),
                  const _Divider(),
                  _ProfileLinkRow(
                    icon: Icons.assignment_turned_in_rounded,
                    label: 'Leave Requests', color: _C.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveApprovalScreen(role: 'hod'))),
                  ),
                  const _Divider(),
                  _ProfileLinkRow(
                    icon: Icons.celebration_rounded,
                    label: 'Holidays', color: const Color(0xFF6A1B9A),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HolidayListScreen(isAdmin: false))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Logout Button ──────────────────────────────────────────────
            _PressCard(
              onTap: _confirmLogout,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7F1D1D), Color(0xFFB91C1C)]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: _C.danger.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Logout', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Shared helpers ────────────────────────────────────────────────────────
  Widget _shimmerRows(int count, double h) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) => Column(
        children: List.generate(count, (_) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + _shimmer.value, 0),
              end:   Alignment( 1.5 + _shimmer.value, 0),
              colors: const [Color(0xFFE7EDF4), Color(0xFFF9FBFD), Color(0xFFE7EDF4)],
            ),
          ),
        )),
      ),
    );
  }

  Widget _emptyRow(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _C.textMuted.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: _C.textMuted, size: 20),
          ),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 13, color: _C.textMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _countBadge(int count, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
    child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
  );

  Widget _roleBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.20)),
    ),
    child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
  );

  Widget _circle(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  String _initials(String name) {
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED STATELESS WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 5))],
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _Header({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _C.textPrimary)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1, color: _C.border);
}

// ── Press scale card ──
class _PressCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressCard({required this.child, required this.onTap});

  @override
  State<_PressCard> createState() => _PressCardState();
}

class _PressCardState extends State<_PressCard> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _s = Tween<double>(begin: 1, end: 0.95).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _s,
        builder: (_, child) => Transform.scale(scale: _s.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ── Time chip ──
class _TimeChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _TimeChip({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12), overflow: TextOverflow.ellipsis),
          Text(label,  style: const TextStyle(color: _C.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Donut stat ──
class _DonutStat extends StatefulWidget {
  final String label;
  final int    value;
  final Color  color;
  const _DonutStat({required this.label, required this.value, required this.color});

  @override
  State<_DonutStat> createState() => _DonutStatState();
}

class _DonutStatState extends State<_DonutStat> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double>   _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
    _a = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Column(
        children: [
          SizedBox(
            width: 68, height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(size: const Size(68, 68), painter: _DonutPainter(progress: _a.value, color: widget.color)),
                Text('${(widget.value * _a.value).round()}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: widget.color)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(widget.label, style: const TextStyle(fontSize: 12, color: _C.textSub, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final Color  color;
  _DonutPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 7;
    final bg = Paint()..color = color.withOpacity(0.10)..strokeWidth = 8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final fg = Paint()..color = color..strokeWidth = 8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, bg);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.progress != progress || o.color != color;
}

// ── Profile info card ──
class _ProfileInfoCard extends StatelessWidget {
  final List<_ProfileRow> rows;
  const _ProfileInfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Column(children: [e.value, if (!isLast) const _Divider()]);
        }).toList(),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  final Color    color;
  const _ProfileRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: _C.textMuted, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLinkRow extends StatelessWidget {
  final IconData    icon;
  final String      label;
  final Color       color;
  final VoidCallback onTap;
  const _ProfileLinkRow({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _C.textPrimary))),
            const Icon(Icons.chevron_right_rounded, color: _C.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Leave action card ──
class _LeaveActionCard extends StatelessWidget {
  final String         title, subtitle, badgeLabel;
  final IconData       icon;
  final List<Color>    gradient;
  final Color          glowColor, badgeColor, badgeTextColor;
  final VoidCallback   onTap;

  const _LeaveActionCard({
    required this.title, required this.subtitle, required this.icon,
    required this.gradient, required this.glowColor,
    required this.badgeLabel, required this.badgeColor, required this.badgeTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: glowColor.withOpacity(0.32), blurRadius: 18, offset: const Offset(0, 7))],
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
                      child: Text(badgeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeTextColor)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, height: 1.4)),
                  const SizedBox(height: 10),
                  const Row(children: [
                    Text('Tap to open', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 12),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Resource card ──
class _ResourceCard extends StatelessWidget {
  final String       title, subtitle;
  final IconData     icon;
  final List<Color>  gradient;
  final Color        glowColor;
  final VoidCallback onTap;

  const _ResourceCard({
    required this.title, required this.subtitle, required this.icon,
    required this.gradient, required this.glowColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: glowColor.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 11, height: 1.4)),
          ],
        ),
      ),
    );
  }
}