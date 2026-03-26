import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:math' as math;
import '../../screens/holidays/holiday_list_screen.dart';
import '../../screens/attendance/attendance_menu_screen.dart';
import '../../screens/leave/leave_approval_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/schedule/schedule_screen.dart';
import '../../services/api_service.dart';
import '../../services/token_service.dart';
import 'dean_leave_screen.dart';

// ── Color Palette ─────────────────────────────────────────────────────────────
class _C {
  static const navy        = Color(0xFF0A2342);
  static const navyMid     = Color(0xFF1B3F72);
  static const navyLight   = Color(0xFF2E5FA3);
  static const teal        = Color(0xFF0077B6);
  static const bg          = Color(0xFFF2F5FB);
  static const card        = Color(0xFFFFFFFF);
  static const border      = Color(0xFFE4EAF4);
  static const success     = Color(0xFF0A7953);
  static const successBg   = Color(0xFFE6F4EF);
  static const danger      = Color(0xFFB91C1C);
  static const dangerBg    = Color(0xFFFEE2E2);
  static const gold        = Color(0xFFB45309);
  static const goldBg      = Color(0xFFFEF3C7);
  static const purple      = Color(0xFF5B21B6);
  static const textPrimary = Color(0xFF0F172A);
  static const textSub     = Color(0xFF64748B);
  static const textMuted   = Color(0xFF94A3B8);
}

// ─────────────────────────────────────────────────────────────────────────────
class DeanDashboardScreen extends StatefulWidget {
  final String name;
  final String email;
  final String deanId;          // faculty_id stored here
  final String department;
  final String? designation;
  final String? qualification;
  final String? profileImage;

  const DeanDashboardScreen({
    super.key,
    required this.name,
    required this.email,
    this.deanId       = '',
    this.department   = 'Dean of Faculty',
    this.designation,
    this.qualification,
    this.profileImage,
  });

  @override
  State<DeanDashboardScreen> createState() => _DeanDashboardScreenState();
}

class _DeanDashboardScreenState extends State<DeanDashboardScreen>
    with TickerProviderStateMixin {

  // 5 tabs: Home | Attendance | My Leave | Schedule | Profile
  int _currentIndex = 0;

  // ── State ──────────────────────────────────────────────────────────────────
  DateTime _today         = DateTime.now();
  List     _todayLeaves   = [];
  bool     _loadingLeaves = true;
  Map      _leaveBalance  = {};
  bool     _loadingBal    = true;
  Map<String, dynamic>? _todayAtt;
  bool     _loadingAtt    = true;
  int      _hodsOnLeave   = 0;
  bool     _loadingStats  = true;

  // Resolved faculty ID (deanId or from session)
  String   _resolvedId    = '';

  // Profile state
  late String _profileName;
  late String _profileEmail;
  late String _profileFacultyId;
  late String _profileDesignation;
  late String _profileQualification;
  String? _profileImageUrl;
  bool _loadingProfile = true;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _headerCtrl;
  late AnimationController _staggerCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<Offset> _headerSlide;
  late Animation<double>  _headerFade;
  late Animation<double>  _pulse;
  late Animation<double>  _shimmer;

  // period time labels (same as ScheduleScreen)
  static const _periodTimes = [
    '09:30','10:20','11:10','12:00',
    '13:00','13:50','14:40','15:30',
  ];

  int get _todayDayIndex {
    final w = DateTime.now().weekday;
    return w >= 1 && w <= 6 ? w - 1 : 0;
  }

  @override
  void initState() {
    super.initState();

    _profileName = widget.name;
    _profileEmail = widget.email;
    _profileFacultyId = widget.deanId;
    _profileDesignation = widget.designation ?? '';
    _profileQualification = widget.qualification ?? '';
    _profileImageUrl = widget.profileImage;

    _headerCtrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800));
    _headerSlide = Tween<Offset>(
        begin: const Offset(0, -0.12), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _headerCtrl, curve: Curves.easeOutCubic));
    _headerFade  = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(
        parent: _headerCtrl, curve: Curves.easeIn));

    _staggerCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1400));

    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.82, end: 1.18)
        .animate(CurvedAnimation(
        parent: _pulseCtrl, curve: Curves.easeInOut));

    _shimmerCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1800))
      ..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 1.5)
        .animate(CurvedAnimation(
        parent: _shimmerCtrl, curve: Curves.linear));

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 250),
            () { if (mounted) _staggerCtrl.forward(); });

    _resolveIdThenLoad();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _staggerCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Resolve ID (deanId widget prop OR session fallback) ────────────────────
  Future<void> _resolveIdThenLoad() async {
    final fromWidget = widget.deanId.trim();
    if (fromWidget.isNotEmpty) {
      _resolvedId = fromWidget;
    } else {
      try {
        final session = await TokenService.getUserSession();
        _resolvedId = (session['facultyId'] ?? '').trim();
      } catch (_) {
        _resolvedId = '';
      }
    }
    await _loadAll();
  }

  // ── Data loaders ───────────────────────────────────────────────────────────
  Future<void> _loadAll() async {
    await Future.wait([
      _loadLeaves(),
      _loadLeaveBalance(),
      _loadAttendance(),
      _loadProfile(),
    ]);
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.getProfile();

      if (!mounted) return;

      setState(() {
        _profileName = (data['name'] ?? widget.name).toString();
        _profileEmail = (data['email'] ?? widget.email).toString();
        _profileFacultyId =
            (data['faculty_id'] ??
                data['dean_id'] ??
                data['employee_id'] ??
                widget.deanId)
                .toString();
        _profileDesignation =
            (data['designation'] ?? widget.designation ?? '').toString();
        _profileQualification =
            (data['qualification'] ?? widget.qualification ?? '').toString();
        _profileImageUrl =
            data['profile_image_url']?.toString() ??
                data['profile_image']?.toString() ??
                widget.profileImage;
        _loadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profileName = widget.name;
        _profileEmail = widget.email;
        _profileFacultyId = _resolvedId.isNotEmpty ? _resolvedId : widget.deanId;
        _profileDesignation = widget.designation ?? '';
        _profileQualification = widget.qualification ?? '';
        _profileImageUrl = widget.profileImage;
        _loadingProfile = false;
      });
    }
  }

  Future<void> _loadLeaves() async {
    try {
      final data = await ApiService.getTodayHodLeaves();
      if (!mounted) return;
      setState(() {
        _todayLeaves   = data;
        _hodsOnLeave   = data.length;
        _loadingLeaves = false;
        _loadingStats  = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loadingLeaves = false; _loadingStats = false; });
    }
  }

  Future<void> _loadLeaveBalance() async {
    try {
      final data = await ApiService.getLeaveBalance();
      if (!mounted) return;
      setState(() { _leaveBalance = data; _loadingBal = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loadingBal = false; });
    }
  }

  Future<void> _loadAttendance() async {
    try {
      final data = await ApiService.getTodayAttendanceStatus();
      if (!mounted) return;
      setState(() { _todayAtt = data; _loadingAtt = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingAtt = false;
        _todayAtt = {
          'status': 'ERROR',
          'message': 'Unable to load attendance',
          'clock_in_time': null,
          'clock_out_time': null,
          'working_hours': 0,
        };
      });
    }
  }

  // ── Stagger helpers ────────────────────────────────────────────────────────
  Animation<double> _stag(int i) {
    final s = (i * 0.10).clamp(0.0, 0.75);
    final e = (s + 0.35).clamp(s + 0.01, 1.0);
    return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _staggerCtrl,
            curve: Interval(s, e, curve: Curves.easeOutCubic)));
  }

  Widget _sw(int i, Widget child) => AnimatedBuilder(
    animation: _staggerCtrl,
    builder: (_, __) => Transform.translate(
      offset: Offset(0, 36 * (1 - _stag(i).value)),
      child: Opacity(opacity: _stag(i).value, child: child),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD ROOT
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _homeTab(),
      AttendanceMenuScreen(email: widget.email),
      const DeanLeaveScreen(),
      // ✅ Fixed: use _resolvedId instead of widget.facultyId
      ScheduleScreen(facultyId: _resolvedId),
      _profileTab(),
    ];

    return Scaffold(
      backgroundColor: _C.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(
            key: ValueKey(_currentIndex),
            child: pages[_currentIndex]),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      {'icon': Icons.home_rounded,               'label': 'Home'},
      {'icon': Icons.fingerprint_rounded,        'label': 'Attendance'},
      {'icon': Icons.event_note_rounded,         'label': 'Leaves'},
      {'icon': Icons.calendar_view_week_rounded, 'label': 'Schedule'},
      {'icon': Icons.person_rounded,             'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: _C.navy.withOpacity(0.10),
            blurRadius: 20, offset: const Offset(0, -4))],
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
                  if (i == 0) await _loadAll();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  padding: sel
                      ? const EdgeInsets.symmetric(horizontal: 16, vertical: 9)
                      : const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: sel
                        ? const LinearGradient(colors: [_C.navy, _C.navyLight])
                        : null,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(children: [
                    Icon(items[i]['icon']! as IconData,
                        color: sel ? Colors.white : _C.textMuted, size: 22),
                    if (sel) ...[
                      const SizedBox(width: 6),
                      Text(items[i]['label']! as String,
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HOME TAB
  // ══════════════════════════════════════════════════════════════════════════
  Widget _homeTab() {
    return SafeArea(
      child: RefreshIndicator(
        color: _C.navy,
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: Column(children: [
            const SizedBox(height: 16),

            // 1 ── HERO
            AnimatedBuilder(
              animation: _headerCtrl,
              builder: (_, __) => SlideTransition(
                position: _headerSlide,
                child: FadeTransition(
                    opacity: _headerFade, child: _buildHero()),
              ),
            ),
            const SizedBox(height: 22),

            // 2 ── CALENDAR
            _sw(0, _buildCalendarCard()),
            const SizedBox(height: 18),

            // 3 ── TODAY'S CLASSES (live from timetable)
            _sw(1, _buildTodayScheduleCard()),
            const SizedBox(height: 18),

            // 4 ── TODAY'S LOGS
            _sw(2, _buildLogsCard()),
            const SizedBox(height: 18),

            // 5 ── MY LEAVE SUMMARY
            _sw(3, _buildLeaveCard()),
            const SizedBox(height: 18),

            // 6 ── HODs ON LEAVE
            _sw(4, _buildHodsOnLeaveCard()),
            const SizedBox(height: 18),

            // 7 ── DEAN STATS ROW
            _sw(5, _buildDeanStatsRow()),
            const SizedBox(height: 18),

            // 8 ── HOLIDAYS
            _sw(6, _buildHolidaysCard()),
          ]),
        ),
      ),
    );
  }

  // ── HERO (matches HOD style) ───────────────────────────────────────────────
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_C.navy, _C.navyMid, _C.navyLight],
        ),
        boxShadow: [BoxShadow(color: _C.navy.withOpacity(0.45),
            blurRadius: 28, offset: const Offset(0, 10))],
      ),
      child: Stack(children: [
        Positioned(top: -28, right: -18,
            child: _circle(120, Colors.white.withOpacity(0.05))),
        Positioned(bottom: -35, right: 50,
            child: _circle(85, Colors.white.withOpacity(0.04))),
        Positioned(top: 12, left: -28,
            child: _circle(75, Colors.white.withOpacity(0.04))),
        Positioned(top: -20, left: 80,
            child: _circle(55, const Color(0xFFD4A017).withOpacity(0.07))),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Online dot + refresh
                Row(children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Transform.scale(
                      scale: _pulse.value,
                      child: Container(width: 9, height: 9,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF34D399))),
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Text('Online',
                      style: TextStyle(color: Color(0xFF34D399),
                          fontSize: 12, fontWeight: FontWeight.w600,
                          letterSpacing: 0.8)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _loadAll,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ]),

                const SizedBox(height: 14),
                Text('Good ${_greeting()}, 👋',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontSize: 13, letterSpacing: 0.2)),
                const SizedBox(height: 5),
                Text(widget.name,
                    style: const TextStyle(fontSize: 23,
                        fontWeight: FontWeight.w800, color: Colors.white,
                        letterSpacing: -0.3, height: 1.2)),
                const SizedBox(height: 4),
                Text(widget.department,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12)),
                const SizedBox(height: 16),

                // DEAN shimmer badge
                AnimatedBuilder(
                  animation: _shimmer,
                  builder: (_, __) => ShaderMask(
                    shaderCallback: (b) => LinearGradient(
                      colors: const [
                        Colors.white, Color(0xFFFFD68A), Colors.white
                      ],
                      stops: [
                        (_shimmer.value - 0.3).clamp(0.0, 1.0),
                        (_shimmer.value).clamp(0.0, 1.0),
                        (_shimmer.value + 0.3).clamp(0.0, 1.0),
                      ],
                    ).createShader(b),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.11),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                            color: const Color(0xFFD4A017).withOpacity(0.40)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_rounded,
                                color: Colors.white, size: 13),
                            SizedBox(width: 6),
                            Text('DEAN',
                                style: TextStyle(color: Colors.white,
                                    fontSize: 11, fontWeight: FontWeight.w700,
                                    letterSpacing: 1.3)),
                          ]),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Quick stats row
                Row(children: [
                  _heroStat(
                    icon: Icons.people_alt_rounded,
                    label: 'HODs on\nLeave',
                    value: _loadingStats ? '—' : '$_hodsOnLeave',
                    color: const Color(0xFFFC9D3A),
                  ),
                  const SizedBox(width: 10),
                  _heroStat(
                    icon: Icons.event_busy_rounded,
                    label: 'Today',
                    value: _todayLabel(),
                    color: const Color(0xFF34D399),
                  ),
                  const SizedBox(width: 10),
                  _heroStat(
                    icon: Icons.assignment_turned_in_rounded,
                    label: 'Leave\nApprovals',
                    value: _loadingLeaves ? '—' : '${_todayLeaves.length}',
                    color: const Color(0xFFA78BFA),
                  ),
                ]),
              ]),
        ),
      ]),
    );
  }

  Widget _heroStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(color: color,
              fontWeight: FontWeight.w800, fontSize: 15)),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70,
                  fontSize: 10, fontWeight: FontWeight.w500, height: 1.3)),
        ]),
      ),
    );
  }

  // ── CALENDAR ──────────────────────────────────────────────────────────────
  Widget _buildCalendarCard() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(title: 'Calendar',
                icon: Icons.calendar_month_rounded, color: _C.teal),
            const SizedBox(height: 10),
            TableCalendar(
              focusedDay: _today,
              firstDay: DateTime.utc(2020),
              lastDay: DateTime.utc(2030),
              calendarFormat: CalendarFormat.week,
              headerVisible: false,
              selectedDayPredicate: (d) => isSameDay(d, _today),
              onDaySelected: (sel, foc) => setState(() => _today = sel),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _C.navy.withOpacity(0.35),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                selectedDecoration: BoxDecoration(
                    color: _C.teal, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _C.teal.withOpacity(0.35),
                        blurRadius: 8, offset: const Offset(0, 3))]),
                weekendTextStyle:
                const TextStyle(color: Color(0xFFDC2626)),
                defaultTextStyle: const TextStyle(
                    color: _C.textPrimary, fontWeight: FontWeight.w500),
                todayTextStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: _C.textSub,
                    fontSize: 12, fontWeight: FontWeight.w600),
                weekendStyle: TextStyle(color: Color(0xFFDC2626),
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
    );
  }

  // ── TODAY'S SCHEDULE (live timetable, matching HOD style) ─────────────────
  Widget _buildTodayScheduleCard() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const _Header(title: "Today's Classes",
                  icon: Icons.class_rounded, color: _C.teal),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _currentIndex = 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: _C.teal.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(children: [
                    Text('Full Schedule',
                        style: TextStyle(fontSize: 11,
                            color: _C.teal, fontWeight: FontWeight.w700)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 10, color: _C.teal),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 14),

            // If resolvedId is ready, show a note — actual slots shown in
            // ScheduleScreen. Here we show an informational placeholder that
            // mirrors the HOD "no classes" / "has classes" state cleanly.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _C.teal.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.teal.withOpacity(0.12)),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: _C.teal.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.calendar_view_day_rounded,
                      color: _C.teal, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your timetable is ready',
                          style: TextStyle(fontWeight: FontWeight.w700,
                              fontSize: 14, color: _C.textPrimary)),
                      const SizedBox(height: 3),
                      Text(
                        _resolvedId.isNotEmpty
                            ? 'Tap "Full Schedule" to see today\'s periods'
                            : 'Faculty ID not set — open Schedule tab',
                        style: const TextStyle(
                            fontSize: 12, color: _C.textSub),
                      ),
                    ])),
              ]),
            ),
          ]),
    );
  }

  // ── TODAY'S LOGS ──────────────────────────────────────────────────────────
  Widget _buildLogsCard() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(title: "Today's Logs",
                icon: Icons.receipt_long_rounded, color: _C.gold),
            const SizedBox(height: 14),
            _loadingAtt ? _shimmerRows(1, 80) : _logsContent(),
          ]),
    );
  }

  Widget _logsContent() {
    final status    = _todayAtt?['status'] ?? 'UNKNOWN';
    final isPresent = status == 'PRESENT' || status == 'CHECKED_IN';
    final sColor    = isPresent ? _C.success : _C.danger;
    final sBg       = isPresent ? _C.successBg : _C.dangerBg;

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: sBg, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sColor.withOpacity(0.20))),
        child: Row(children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Transform.scale(
              scale: isPresent ? _pulse.value : 1.0,
              child: Container(width: 44, height: 44,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sColor.withOpacity(0.12)),
                  child: Icon(
                      isPresent
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: sColor, size: 26)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(status, style: TextStyle(fontSize: 17,
                fontWeight: FontWeight.w800, color: sColor)),
            const SizedBox(height: 2),
            Text((_todayAtt?['message'] ?? '-').toString(),
                style: const TextStyle(
                    fontSize: 12, color: _C.textSub)),
          ])),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _TimeChip(
            label: 'Clock In',
            value: (_todayAtt?['clock_in_time']  ?? '--').toString(),
            icon: Icons.login_rounded, color: _C.success)),
        const SizedBox(width: 10),
        Expanded(child: _TimeChip(
            label: 'Clock Out',
            value: (_todayAtt?['clock_out_time'] ?? '--').toString(),
            icon: Icons.logout_rounded, color: _C.danger)),
        const SizedBox(width: 10),
        Expanded(child: _TimeChip(
            label: 'Hrs Worked',
            value: '${_todayAtt?['working_hours'] ?? 0}h',
            icon: Icons.timer_rounded, color: _C.teal)),
      ]),
    ]);
  }

  // ── MY LEAVE SUMMARY ──────────────────────────────────────────────────────
  Widget _buildLeaveCard() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(title: 'My Leave Balance',
                icon: Icons.event_note_rounded, color: _C.purple),
            const SizedBox(height: 16),
            _loadingBal
                ? _shimmerRows(1, 70)
                : Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _DonutStat(label: 'Allowed',
                      value: int.tryParse(
                          _leaveBalance['total_allowed']?.toString() ?? '0') ?? 0,
                      color: _C.navyLight),
                  _DonutStat(label: 'Used',
                      value: int.tryParse(
                          _leaveBalance['used']?.toString() ?? '0') ?? 0,
                      color: _C.danger),
                  _DonutStat(label: 'Remaining',
                      value: int.tryParse(
                          _leaveBalance['remaining']?.toString() ?? '0') ?? 0,
                      color: _C.success),
                ]),
          ]),
    );
  }

  // ── HODs ON LEAVE ─────────────────────────────────────────────────────────
  Widget _buildHodsOnLeaveCard() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _Header(
                title: 'HODs on Leave Today',
                icon: Icons.people_alt_rounded,
                color: _todayLeaves.isEmpty ? _C.success : _C.danger,
              ),
              const Spacer(),
              if (!_loadingLeaves && _todayLeaves.isNotEmpty)
                _countBadge(_todayLeaves.length, _C.danger),
            ]),
            const SizedBox(height: 14),
            if (_loadingLeaves)
              _shimmerRows(2, 52)
            else if (_todayLeaves.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _C.successBg,
                    borderRadius: BorderRadius.circular(14),
                    border:
                    Border.all(color: _C.success.withOpacity(0.20))),
                child: Row(children: [
                  Container(width: 44, height: 44,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _C.success.withOpacity(0.12)),
                      child: const Icon(Icons.check_circle_rounded,
                          color: _C.success, size: 26)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('All HODs present today',
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700, color: _C.success))),
                ]),
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
                      border: Border.all(
                          color: _C.danger.withOpacity(0.13)),
                    ),
                    child: Row(children: [
                      CircleAvatar(radius: 20,
                          backgroundColor: _C.danger.withOpacity(0.12),
                          child: Text(initials,
                              style: const TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _C.danger))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14, color: _C.textPrimary)),
                            if (start.isNotEmpty && end.isNotEmpty)
                              Text('$start → $end',
                                  style: const TextStyle(
                                      fontSize: 11, color: _C.textSub,
                                      fontWeight: FontWeight.w500)),
                          ])),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: _C.goldBg,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(leaveType,
                            style: const TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w700, color: _C.gold)),
                      ),
                    ]),
                  );
                }).toList(),
              ),

            const SizedBox(height: 14),
            // Manage button
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) =>
                  const LeaveApprovalScreen(role: 'dean'))),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: _C.navy.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color: _C.navy.withOpacity(0.15)),
                ),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_rounded,
                          color: _C.navy, size: 16),
                      SizedBox(width: 8),
                      Text('Manage HOD Leave Requests',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w700, color: _C.navy)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: _C.navyLight, size: 12),
                    ]),
              ),
            ),
          ]),
    );
  }

  // ── DEAN STATS ROW ────────────────────────────────────────────────────────
  Widget _buildDeanStatsRow() {
    final items = [
      {
        'label': 'HODs on\nLeave',
        'value': _loadingStats ? '—' : '$_hodsOnLeave',
        'icon':  Icons.person_off_rounded,
        'color': _C.danger,
        'bg':    _C.dangerBg,
      },
      {
        'label': 'Leave\nRequests',
        'value': _loadingLeaves ? '—' : '${_todayLeaves.length}',
        'icon':  Icons.pending_actions_rounded,
        'color': _C.gold,
        'bg':    _C.goldBg,
      },
      {
        'label': "Today's\nDate",
        'value': _todayLabel(),
        'icon':  Icons.today_rounded,
        'color': _C.navyLight,
        'bg':    const Color(0xFFEFF4FF),
      },
    ];

    return Row(
      children: List.generate(items.length, (i) {
        final s     = items[i];
        final color = s['color'] as Color;
        final bg    = s['bg']    as Color;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < items.length - 1 ? 10 : 0),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _C.border),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14, offset: const Offset(0, 4))],
            ),
            child: Column(children: [
              Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Icon(s['icon'] as IconData,
                      color: color, size: 20)),
              const SizedBox(height: 10),
              Text(s['value'] as String,
                  style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 4),
              Text(s['label'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: _C.textSub,
                      fontWeight: FontWeight.w600, height: 1.3)),
            ]),
          ),
        );
      }),
    );
  }

  // ── HOLIDAYS ──────────────────────────────────────────────────────────────
  Widget _buildHolidaysCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const HolidayListScreen(isAdmin: false))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0A4F7A), Color(0xFF0077B6)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _C.teal.withOpacity(0.35),
              blurRadius: 18, offset: const Offset(0, 7))],
        ),
        child: Row(children: [
          Container(width: 50, height: 50,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.celebration_rounded,
                  color: Colors.white, size: 26)),
          const SizedBox(width: 16),
          const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Holidays', style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w800, fontSize: 15)),
            SizedBox(height: 3),
            Text('View holiday list & calendar',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
          Container(width: 34, height: 34,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 16)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PROFILE TAB (matches HOD style)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _profileTab() {
    final displayName = _profileName.isNotEmpty ? _profileName : widget.name;
    final displayEmail = _profileEmail.isNotEmpty ? _profileEmail : widget.email;
    final facultyId = _profileFacultyId.isNotEmpty
        ? _profileFacultyId
        : (_resolvedId.isNotEmpty ? _resolvedId : widget.deanId);
    final designation = _profileDesignation;
    final qualification = _profileQualification;
    final profileImage = _profileImageUrl;
    final initials = _initials(displayName);

    if (_loadingProfile) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A1929),
                    Color(0xFF0D2B4E),
                    Color(0xFF1B4080),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.navy.withOpacity(0.42),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -14,
                    right: -8,
                    child: _circle(76, Colors.white.withOpacity(0.04)),
                  ),
                  Positioned(
                    bottom: -20,
                    left: 8,
                    child: _circle(52, Colors.white.withOpacity(0.03)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                              ),
                              border: Border.all(
                                color: const Color(0xFFD4A017).withOpacity(0.55),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0D47A1).withOpacity(0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: profileImage != null && profileImage.isNotEmpty
                                  ? ClipOval(
                                child: Image.network(
                                  profileImage,
                                  width: 74,
                                  height: 74,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Text(
                                    initials,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                                  : Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditProfileScreen(
                                    name: displayName,
                                    email: displayEmail,
                                    designation: designation,
                                    qualification: qualification,
                                  ),
                                ),
                              );

                              if (result != null && mounted) {
                                setState(() {
                                  _profileName =
                                      (result['name'] ?? _profileName).toString();
                                  _profileDesignation =
                                      (result['designation'] ?? _profileDesignation)
                                          .toString();
                                  _profileQualification =
                                      (result['qualification'] ??
                                          _profileQualification)
                                          .toString();
                                });
                                await _loadProfile();
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                ),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dean of Faculty',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.62),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (facultyId.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.16),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.badge_rounded,
                                color: Colors.white.withOpacity(0.72),
                                size: 13,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Faculty ID: $facultyId',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.84),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (designation.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          designation,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.54),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A017).withOpacity(0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFD4A017).withOpacity(0.40),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.account_balance_rounded,
                              color: Color(0xFFD4A017),
                              size: 13,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Dean of Faculty',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD4A017),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _Card(
              child: Column(
                children: [
                  _profRow(
                    Icons.person_rounded,
                    'Full Name',
                    displayName,
                    _C.navy,
                  ),
                  if (facultyId.isNotEmpty) ...[
                    const _Divider(),
                    _profRow(
                      Icons.badge_rounded,
                      'Faculty ID',
                      facultyId,
                      _C.navyLight,
                    ),
                  ],
                  if (displayEmail.isNotEmpty) ...[
                    const _Divider(),
                    _profRow(
                      Icons.email_rounded,
                      'Email',
                      displayEmail,
                      _C.purple,
                    ),
                  ],
                  if (designation.isNotEmpty) ...[
                    const _Divider(),
                    _profRow(
                      Icons.work_rounded,
                      'Designation',
                      designation,
                      _C.gold,
                    ),
                  ],
                  if (qualification.isNotEmpty) ...[
                    const _Divider(),
                    _profRow(
                      Icons.school_rounded,
                      'Qualification',
                      qualification,
                      _C.success,
                    ),
                  ],
                  const _Divider(),
                  _profRow(
                    Icons.verified_user_rounded,
                    'Role',
                    'Dean of Faculty',
                    const Color(0xFFE65100),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Header(
                    title: 'Quick Links',
                    icon: Icons.grid_view_rounded,
                    color: _C.navy,
                  ),
                  const SizedBox(height: 14),
                  _linkRow(
                    Icons.fingerprint_rounded,
                    'My Attendance',
                    _C.teal,
                        () => setState(() => _currentIndex = 1),
                  ),
                  const _Divider(),
                  _linkRow(
                    Icons.event_note_rounded,
                    'My Leaves',
                    _C.success,
                        () => setState(() => _currentIndex = 2),
                  ),
                  const _Divider(),
                  _linkRow(
                    Icons.calendar_view_week_rounded,
                    'My Schedule',
                    _C.teal,
                        () => setState(() => _currentIndex = 3),
                  ),
                  const _Divider(),
                  _linkRow(
                    Icons.assignment_turned_in_rounded,
                    'Dean Leave Panel',
                    const Color(0xFFE65100),
                        () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeanLeaveScreen(),
                      ),
                    ),
                  ),
                  const _Divider(),
                  _linkRow(
                    Icons.celebration_rounded,
                    'Holidays',
                    const Color(0xFF6A1B9A),
                        () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HolidayListScreen(isAdmin: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _showLogoutDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7F1D1D), Color(0xFFB91C1C)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _C.danger.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _profRow(
      IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11,
              color: _C.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14,
              fontWeight: FontWeight.w700, color: _C.textPrimary)),
        ])),
      ]),
    );
  }

  Widget _linkRow(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14,
              fontWeight: FontWeight.w600, color: _C.textPrimary))),
          const Icon(Icons.chevron_right_rounded,
              color: _C.textMuted, size: 20),
        ]),
      ),
    );
  }

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
              colors: const [
                Color(0xFFE7EDF4), Color(0xFFF9FBFD), Color(0xFFE7EDF4)
              ],
            ),
          ),
        )),
      ),
    );
  }

  Widget _countBadge(int count, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20)),
    child: Text('$count',
        style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w800, color: color)),
  );

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              TokenService.clearToken();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (r) => false);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  String _todayLabel() {
    final n = DateTime.now();
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${n.day} ${m[n.month - 1]}';
  }

  String _initials(String name) {
    final parts =
    name.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static Widget _circle(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _C.card,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _C.border),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
          blurRadius: 18, offset: const Offset(0, 5))],
    ),
    child: child,
  );
}

class _Header extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _Header(
      {required this.title, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 36, height: 36,
        decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 19)),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(fontWeight: FontWeight.w800,
        fontSize: 15, color: _C.textPrimary)),
  ]);
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: _C.border);
}

class _TimeChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _TimeChip({required this.label, required this.value,
    required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.14)),
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 17),
      const SizedBox(height: 5),
      Text(value, style: TextStyle(color: color,
          fontWeight: FontWeight.w800, fontSize: 12),
          overflow: TextOverflow.ellipsis),
      Text(label, style: const TextStyle(color: _C.textMuted,
          fontSize: 10, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _DonutStat extends StatefulWidget {
  final String label;
  final int    value;
  final Color  color;
  const _DonutStat(
      {required this.label, required this.value, required this.color});
  @override
  State<_DonutStat> createState() => _DonutStatState();
}

class _DonutStatState extends State<_DonutStat>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double>   _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 950));
    _a = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Column(children: [
      SizedBox(width: 68, height: 68,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: const Size(68, 68),
                painter: _DonutPainter(
                    progress: _a.value, color: widget.color)),
            Text('${(widget.value * _a.value).round()}',
                style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w900, color: widget.color)),
          ])),
      const SizedBox(height: 8),
      Text(widget.label, style: const TextStyle(fontSize: 12,
          color: _C.textSub, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final Color  color;
  _DonutPainter({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final c  = Offset(size.width / 2, size.height / 2);
    final r  = size.width / 2 - 7;
    final bg = Paint()
      ..color      = color.withOpacity(0.10)
      ..strokeWidth = 8
      ..style      = PaintingStyle.stroke
      ..strokeCap  = StrokeCap.round;
    final fg = Paint()
      ..color      = color
      ..strokeWidth = 8
      ..style      = PaintingStyle.stroke
      ..strokeCap  = StrokeCap.round;
    canvas.drawCircle(c, r, bg);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        -math.pi / 2, 2 * math.pi * progress, false, fg);
  }
  @override
  bool shouldRepaint(_DonutPainter o) =>
      o.progress != progress || o.color != color;
}