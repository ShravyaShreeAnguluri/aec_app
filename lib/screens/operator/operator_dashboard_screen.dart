import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../screens/attendance/attendance_menu_screen.dart';
import '../../screens/holidays/holiday_list_screen.dart';
import '../../screens/leave/leave_history_screen.dart';
import '../../services/api_service.dart';
import '../../services/token_service.dart';
import '../profile/edit_profile_screen.dart';
import 'timetable/timetableapp_theme.dart';
import 'timetable/generate_timetable_screen.dart';
import 'timetable/view_faculty_timetable_screen.dart';
import 'timetable/view_section_timetable_screen.dart';
import 'rooms/create_room_screen.dart';
import 'rooms/view_rooms_screen.dart';
import 'sections/create_section_screen.dart';
import 'sections/view_sections_screen.dart';
import 'subjects/create_subject_screen.dart';
import 'subjects/view_subjects_screen.dart';
import 'mappings/create_mapping_screen.dart';
import 'mappings/view_mappings_screen.dart';

// ─── Colour palette (matches faculty dashboard) ──────────────────────────────
class _C {
  static const navy = Color(0xFF0D47A1);
  static const navyMid = Color(0xFF1565C0);
  static const navyLight = Color(0xFF1E88E5);
  static const accent = Color(0xFF2196F3);
  static const teal = Color(0xFF0288D1);

  static const bg = Color(0xFFF4F8FD);
  static const cardBg = Color(0xFFFFFFFF);

  static const success = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
  static const warning = Color(0xFFEF6C00);
  static const gold = Color(0xFFBF8600);
  static const purple = Color(0xFF6A1B9A);

  static const textPrimary = Color(0xFF102033);
  static const textSub = Color(0xFF506070);
  static const textMuted = Color(0xFF8A9AAA);
  static const border = Color(0xFFE5EEF7);
}

// ─── Dashboard item / group models ───────────────────────────────────────────
class _DashItem {
  final String title;
  final IconData icon;
  final Widget screen;
  const _DashItem(this.title, this.icon, this.screen);
}

class _DashGroup {
  final String title;
  final IconData icon;
  final Color color;
  final List<_DashItem> items;
  const _DashGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
}

// ─── Main widget ─────────────────────────────────────────────────────────────
class OperatorDashboardScreen extends StatefulWidget {
  final String name;
  final String department;
  final String token;

  const OperatorDashboardScreen({
    super.key,
    required this.name,
    required this.department,
    required this.token,
  });

  @override
  State<OperatorDashboardScreen> createState() =>
      _OperatorDashboardScreenState();
}

class _OperatorDashboardScreenState extends State<OperatorDashboardScreen>
    with TickerProviderStateMixin {
  // ── Bottom-nav state ──────────────────────────────────────────────────────
  int _currentIndex = 0;
  DateTime _today = DateTime.now();

  // ── Leave / attendance data ───────────────────────────────────────────────
  Map _leaveBalance = {};
  bool _loadingLeave = true;

  Map<String, dynamic>? _todayAttendance;
  bool _loadingAttendance = true;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _heroCtrl;
  late AnimationController _staggerCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shimmerCtrl;

  late Animation<Offset> _heroSlide;
  late Animation<double> _heroFade;
  late Animation<double> _pulse;
  late Animation<double> _shimmer;

  // ── Dashboard groups (Rooms, Sections, Subjects, Mappings, Timetable) ─────
  late List<_DashGroup> _groups;

  @override
  void initState() {
    super.initState();

    _groups = [
      _DashGroup(
        title: 'Rooms & Labs',
        icon: Icons.meeting_room_outlined,
        color: const Color(0xFF1565C0),
        items: [
          _DashItem('Create Room', Icons.add_circle_outline,
              CreateRoomScreen(token: widget.token)),
          _DashItem('View Rooms', Icons.domain_outlined,
              ViewRoomsScreen(token: widget.token)),
        ],
      ),
      _DashGroup(
        title: 'Sections',
        icon: Icons.class_outlined,
        color: const Color(0xFF00695C),
        items: [
          _DashItem('Create Section', Icons.add_circle_outline,
              CreateSectionScreen(token: widget.token)),
          _DashItem('View Sections', Icons.view_list_outlined,
              ViewSectionsScreen(token: widget.token)),
        ],
      ),
      _DashGroup(
        title: 'Subjects',
        icon: Icons.menu_book_outlined,
        color: const Color(0xFF6A1B9A),
        items: [
          _DashItem('Create Subject', Icons.add_circle_outline,
              CreateSubjectScreen(token: widget.token)),
          _DashItem('View Subjects', Icons.library_books_outlined,
              ViewSubjectsScreen(token: widget.token)),
        ],
      ),
      _DashGroup(
        title: 'Faculty Mappings',
        icon: Icons.people_alt_outlined,
        color: const Color(0xFFBF360C),
        items: [
          _DashItem('Create Mapping', Icons.link_outlined,
              CreateFacultyMappingScreen(token: widget.token)),
          _DashItem('View Mappings', Icons.account_tree_outlined,
              ViewMappingsScreen(token: widget.token)),
        ],
      ),
      _DashGroup(
        title: 'Timetable',
        icon: Icons.calendar_month_outlined,
        color: TimetableAppTheme.primary,
        items: [
          _DashItem('Generate Timetable', Icons.auto_awesome_outlined,
              GenerateTimetableScreen(token: widget.token)),
          _DashItem('Section Timetable', Icons.grid_view_rounded,
              ViewSectionTimetableScreen(token: widget.token)),
          _DashItem('Faculty Timetable', Icons.badge_outlined,
              ViewFacultyTimetableScreen(token: widget.token)),
        ],
      ),
    ];

    // animations
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _heroSlide = Tween<Offset>(
        begin: const Offset(0, -0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));
    _heroFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeIn));

    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.90, end: 1.10)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 1.5)
        .animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear));

    _heroCtrl.forward();
    Future.delayed(
        const Duration(milliseconds: 180), () => _staggerCtrl.forward());

    _refresh();
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _staggerCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Data loaders ──────────────────────────────────────────────────────────
  Future<void> _refresh() async {
    await Future.wait([_loadLeave(), _loadAttendance()]);
  }

  Future<void> _loadLeave() async {
    try {
      final data = await ApiService.getLeaveBalance();
      if (mounted) setState(() { _leaveBalance = data; _loadingLeave = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingLeave = false);
    }
  }

  Future<void> _loadAttendance() async {
    try {
      final data = await ApiService.getTodayAttendanceStatus();
      if (!mounted) return;
      setState(() { _todayAttendance = data; _loadingAttendance = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingAttendance = false;
        _todayAttendance = {
          'status': 'ERROR',
          'message': 'Unable to load attendance',
          'clock_in_time': null,
          'clock_out_time': null,
          'working_hours': 0,
        };
      });
    }
  }

  Future<void> _logout() async {
    await TokenService.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  // ── Stagger helper ────────────────────────────────────────────────────────
  Animation<double> _stag(int i) {
    final s = (i * 0.10).clamp(0.0, 0.75);
    final e = (s + 0.35).clamp(s + 0.01, 1.0);
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(s, e, curve: Curves.easeOutCubic)),
    );
  }

  Widget _sw(int i, Widget child) => AnimatedBuilder(
    animation: _staggerCtrl,
    builder: (_, __) => Transform.translate(
      offset: Offset(0, 26 * (1 - _stag(i).value)),
      child: Opacity(opacity: _stag(i).value, child: child),
    ),
  );

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Pages indexed by bottom nav
    final pages = [
      _homePage(),
      AttendanceMenuScreen(email: ''), // operator still has attendance
      LeaveHistoryScreen(),
      _timetablePage(),               // ← replaces Schedule
      _profilePage(),
    ];

    return Scaffold(
      backgroundColor: _C.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      (icon: Icons.home_rounded, label: 'Home'),
      (icon: Icons.fingerprint_rounded, label: 'Attendance'),
      (icon: Icons.event_note_rounded, label: 'Leave'),
      (icon: Icons.calendar_month_rounded, label: 'Timetable'), // ← changed
      (icon: Icons.person_rounded, label: 'Profile'),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            border: Border(
                top: BorderSide(color: _C.border.withOpacity(0.9), width: 1)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, -4)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (i) {
                  final selected = _currentIndex == i;
                  return GestureDetector(
                    onTap: () async {
                      setState(() => _currentIndex = i);
                      if (i == 0) await _refresh();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: selected
                          ? const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10)
                          : const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(
                          colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : null,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: selected
                            ? [
                          BoxShadow(
                            color: const Color(0xFF1565C0)
                                .withOpacity(0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(items[i].icon,
                              color: selected ? Colors.white : _C.textMuted,
                              size: 21),
                          if (selected) ...[
                            const SizedBox(width: 7),
                            Text(
                              items[i].label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Home page ─────────────────────────────────────────────────────────────
  Widget _homePage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF2FC), Color(0xFFF5F8FD), Color(0xFFFFFFFF)],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          color: _C.navyLight,
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 86),
            child: Column(
              children: [
                // Hero header
                AnimatedBuilder(
                  animation: _heroCtrl,
                  builder: (_, __) => SlideTransition(
                    position: _heroSlide,
                    child: FadeTransition(
                        opacity: _heroFade, child: _buildHero()),
                  ),
                ),
                const SizedBox(height: 20),
                _sw(0, _buildCalendarCard()),
                const SizedBox(height: 20),
                _sw(1, _buildLogsCard()),
                const SizedBox(height: 20),
                _sw(2, _buildLeaveCard()),
                const SizedBox(height: 20),
                _sw(3, _buildHolidaysCard()),
                const SizedBox(height: 20),
                _sw(4, _buildManagementSection()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero header ───────────────────────────────────────────────────────────
  Widget _buildHero() {
    final initials = widget.name.trim().isNotEmpty
        ? widget.name
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join()
        : 'OP';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
          stops: [0.0, 0.52, 1.0],
        ),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0D47A1).withOpacity(0.22),
              blurRadius: 26,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
              top: -22,
              right: -10,
              child: _circle(118, Colors.white.withOpacity(0.05))),
          Positioned(
              bottom: -34,
              left: -18,
              child: _circle(92, Colors.white.withOpacity(0.04))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Online indicator
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Transform.scale(
                        scale: _pulse.value,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: const Color(0xFF34D399),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color:
                                  const Color(0xFF34D399).withOpacity(0.45),
                                  blurRadius: 8,
                                  spreadRadius: 1),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text('Online',
                        style: TextStyle(
                            color: Color(0xFFB9F6CA),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4)),
                    const Spacer(),
                    // Logout button in hero
                    GestureDetector(
                      onTap: _logout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border:
                          Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.logout_rounded,
                                color: Colors.white70, size: 14),
                            SizedBox(width: 5),
                            Text('Logout',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.16),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.22), width: 1.2),
                      ),
                      child: Center(
                        child: Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Good $_greeting',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.72),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(widget.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  height: 1.1)),
                          const SizedBox(height: 6),
                          Text(widget.department,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.78),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _heroStat(
                          Icons.manage_accounts_outlined, 'Role', 'Operator'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _heroStat(Icons.domain_outlined, 'Department',
                          widget.department),
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

  Widget _heroStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.66),
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Calendar card ─────────────────────────────────────────────────────────
  Widget _buildCalendarCard() {
    return _PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader('Calendar', Icons.calendar_month_rounded, _C.teal),
          const SizedBox(height: 12),
          TableCalendar(
            focusedDay: _today,
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            calendarFormat: CalendarFormat.week,
            headerVisible: false,
            selectedDayPredicate: (d) => isSameDay(d, _today),
            onDaySelected: (sel, _) => setState(() => _today = sel),
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                  color: Color(0xFF42A5F5), shape: BoxShape.circle),
              weekendTextStyle:
              TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
              defaultTextStyle:
              TextStyle(color: _C.textPrimary, fontWeight: FontWeight.w500),
              todayTextStyle:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                  color: _C.textSub, fontSize: 12, fontWeight: FontWeight.w600),
              weekendStyle: TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Today's logs card ─────────────────────────────────────────────────────
  Widget _buildLogsCard() {
    return _PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
              "Today's Logs", Icons.receipt_long_rounded, _C.gold),
          const SizedBox(height: 14),
          _loadingAttendance ? _skeleton() : _logsContent(),
        ],
      ),
    );
  }

  Widget _logsContent() {
    final status = _todayAttendance?['status'] ?? 'UNKNOWN';
    final isPresent = status == 'PRESENT' || status == 'CHECKED_IN';
    final sColor = isPresent ? _C.success : _C.danger;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: sColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Transform.scale(
                  scale: isPresent ? _pulse.value : 1.0,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sColor.withOpacity(0.12)),
                    child: Icon(
                        isPresent
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: sColor,
                        size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: sColor,
                            letterSpacing: 0.2)),
                    const SizedBox(height: 4),
                    Text(_todayAttendance?['message'] ?? '—',
                        style:
                        const TextStyle(fontSize: 12, color: _C.textSub)),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: sColor.withOpacity(0.10), shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                          '${_todayAttendance?["working_hours"] ?? 0}h',
                          style: TextStyle(
                              color: sColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Hours',
                      style: TextStyle(
                          color: sColor.withOpacity(0.75),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _TimeChip(
                    label: 'Clock In',
                    value: _todayAttendance?['clock_in_time'] ?? '--',
                    icon: Icons.login_rounded,
                    color: _C.success)),
            const SizedBox(width: 10),
            Expanded(
                child: _TimeChip(
                    label: 'Clock Out',
                    value: _todayAttendance?['clock_out_time'] ?? '--',
                    icon: Icons.logout_rounded,
                    color: _C.danger)),
            const SizedBox(width: 10),
            Expanded(
                child: _TimeChip(
                    label: 'Hrs Worked',
                    value: '${_todayAttendance?["working_hours"] ?? 0}h',
                    icon: Icons.timer_rounded,
                    color: _C.teal)),
          ],
        ),
      ],
    );
  }

  // ── Leave summary card ────────────────────────────────────────────────────
  Widget _buildLeaveCard() {
    final allowedD = _parseNum(_leaveBalance, ['total_allowed', 'total', 'allowed']);
    final usedD = _parseNum(_leaveBalance, ['used_days', 'days_used', 'used']);
    final remainingD = (allowedD - usedD).clamp(0, allowedD).toDouble();
    final allowed = allowedD.toInt();
    final progress = allowed > 0 ? (usedD / allowedD).clamp(0.0, 1.0) : 0.0;
    final barColor = progress < 0.5
        ? _C.success
        : progress < 0.8
        ? _C.warning
        : _C.danger;

    return _PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeader(
                    'Leave Summary', Icons.event_note_rounded, _C.purple),
              ),
              GestureDetector(
                onTap: () => setState(() => _currentIndex = 2),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: _C.purple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Text('View All',
                          style: TextStyle(
                              color: _C.purple,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 11, color: _C.purple),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingLeave)
            _skeleton()
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style:
                      const TextStyle(fontSize: 13, color: _C.textSub),
                      children: [
                        TextSpan(
                            text: _fmtDays(usedD),
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: barColor,
                                letterSpacing: -0.4)),
                        TextSpan(
                            text: ' / $allowed days used',
                            style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: _C.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('${_fmtDays(remainingD)} left',
                      style: const TextStyle(
                          color: _C.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: _C.purple.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _LeaveStatChip(
                    label: 'Allowed',
                    value: _fmtDays(allowedD),
                    icon: Icons.calendar_month_rounded,
                    color: _C.navyLight),
                const SizedBox(width: 8),
                _LeaveStatChip(
                    label: 'Used',
                    value: _fmtDays(usedD),
                    icon: Icons.remove_circle_outline_rounded,
                    color: barColor),
                const SizedBox(width: 8),
                _LeaveStatChip(
                    label: 'Remaining',
                    value: _fmtDays(remainingD),
                    icon: Icons.check_circle_outline_rounded,
                    color: _C.success),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Holidays banner ───────────────────────────────────────────────────────
  Widget _buildHolidaysCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const HolidayListScreen(isAdmin: false))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF0D47A1).withOpacity(0.20),
                blurRadius: 22,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.celebration_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Holidays',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  SizedBox(height: 3),
                  Text('View holiday calendar & schedule',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ── Management quick-access section (on home page) ────────────────────────
  Widget _buildManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text('Management',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary)),
        ),
        // Show all groups compactly as two-column chips
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _groups
              .expand((g) => g.items.map((item) => _QuickChip(
            title: item.title,
            icon: item.icon,
            color: g.color,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => item.screen)),
          )))
              .toList(),
        ),
      ],
    );
  }

  // ── Timetable page (full page shown when "Timetable" tab is selected) ─────
  Widget _timetablePage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 86),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    TimetableAppTheme.primary,
                    TimetableAppTheme.primary.withOpacity(0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: TimetableAppTheme.primary.withOpacity(0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.calendar_month_outlined,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Timetable Manager',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 3),
                      Text('Generate & view timetables',
                          style:
                          TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Each timetable group rendered as a card
            ..._groups.map((g) => _GroupCard(group: g)),
          ],
        ),
      ),
    );
  }

  // ── Profile page ──────────────────────────────────────────────────────────
  Widget _profilePage() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadOperatorProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: _C.bg,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data ?? {};
        final profileName = (profile['name'] ?? widget.name ?? '').toString();
        final email = (profile['email'] ?? '').toString();
        final facultyId = (profile['faculty_id'] ?? profile['facultyId'] ?? '').toString();
        final department = (profile['department'] ?? widget.department).toString();
        final designation = (profile['designation'] ?? 'Operator').toString();
        final role = (profile['role'] ?? 'operator').toString();
        final qualification = profile['qualification']?.toString();
        final profileImage = profile['profile_image']?.toString();

        return Container(
          color: _C.bg,
          child: SafeArea(
            child: RefreshIndicator(
              color: _C.navyLight,
              onRefresh: () async {
                setState(() {});
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D47A1).withOpacity(0.20),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -18,
                            right: -8,
                            child: _circle(110, Colors.white.withOpacity(0.05)),
                          ),
                          Positioned(
                            bottom: -30,
                            left: -18,
                            child: _circle(90, Colors.white.withOpacity(0.04)),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _roundIconButton(
                                      icon: Icons.arrow_back_ios_new_rounded,
                                      onTap: () => setState(() => _currentIndex = 0),
                                    ),
                                    const Spacer(),
                                    _roundIconButton(
                                      icon: Icons.edit_rounded,
                                      onTap: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditProfileScreen(
                                              name: profileName,
                                              email: email,
                                              designation: designation,
                                              qualification: qualification,
                                            ),
                                          ),
                                        );
                                        if (result != null && mounted) {
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _buildProfileAvatar(profileName, profileImage),
                                const SizedBox(height: 16),
                                Text(
                                  profileName.isNotEmpty ? profileName : 'Operator',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                                  ),
                                  child: Text(
                                    designation.isNotEmpty ? designation : 'Operator',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeader('Profile Details', Icons.person_outline_rounded, _C.navyLight),
                          const SizedBox(height: 4),
                          const Text(
                            'Your academic and account information',
                            style: TextStyle(
                              color: _C.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _profileInfoTile(
                            icon: Icons.badge_outlined,
                            color: const Color(0xFF1E88E5),
                            label: 'Faculty ID',
                            value: facultyId,
                          ),
                          const Divider(height: 1, color: _C.border),
                          _profileInfoTile(
                            icon: Icons.mail_outline_rounded,
                            color: const Color(0xFF0288D1),
                            label: 'Email',
                            value: email,
                          ),
                          const Divider(height: 1, color: _C.border),
                          _profileInfoTile(
                            icon: Icons.apartment_outlined,
                            color: const Color(0xFF7E57C2),
                            label: 'Department',
                            value: department,
                          ),
                          const Divider(height: 1, color: _C.border),
                          _profileInfoTile(
                            icon: Icons.work_outline_rounded,
                            color: const Color(0xFFFB8C00),
                            label: 'Designation',
                            value: designation,
                          ),
                          const Divider(height: 1, color: _C.border),
                          _profileInfoTile(
                            icon: Icons.verified_user_outlined,
                            color: const Color(0xFF2E7D32),
                            label: 'Role',
                            value: role.isEmpty ? 'operator' : role,
                          ),
                          if (qualification != null && qualification.trim().isNotEmpty) ...[
                            const Divider(height: 1, color: _C.border),
                            _profileInfoTile(
                              icon: Icons.school_outlined,
                              color: const Color(0xFF5E35B1),
                              label: 'Qualification',
                              value: qualification,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadOperatorProfile() async {
    Map<String, dynamic> profile = {};

    try {
      profile = Map<String, dynamic>.from(await ApiService.getProfile());
    } catch (_) {}

    final session = await TokenService.getUserSession();

    profile['name'] = (profile['name'] ?? session['name'] ?? widget.name);
    profile['email'] = (profile['email'] ?? session['email'] ?? '');
    profile['faculty_id'] = (profile['faculty_id'] ?? session['facultyId'] ?? '');
    profile['department'] = (profile['department'] ?? session['department'] ?? widget.department);
    profile['designation'] = (profile['designation'] ?? session['designation'] ?? 'Operator');
    profile['qualification'] = (profile['qualification'] ?? session['qualification']);
    profile['role'] = (profile['role'] ?? session['role'] ?? 'operator');
    profile['profile_image'] = (profile['profile_image'] ?? session['profileImage']);

    return profile;
  }

  Widget _roundIconButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(String name, String? profileImage) {
    final clean = (profileImage ?? '').trim();
    ImageProvider? provider;

    if (clean.isNotEmpty) {
      try {
        provider = MemoryImage(base64Decode(clean));
      } catch (_) {
        provider = null;
      }
    }

    final initials = name.trim().isEmpty
        ? 'O'
        : name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFD54F), width: 2),
        color: Colors.white,
      ),
      child: CircleAvatar(
        radius: 38,
        backgroundColor: const Color(0xFFF1F6FD),
        backgroundImage: provider,
        child: provider == null
            ? Text(
          initials,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _C.navy,
          ),
        )
            : null,
      ),
    );
  }

  Widget _profileInfoTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _C.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value.trim().isEmpty ? 'Not available' : value,
                  style: const TextStyle(
                    color: _C.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  double _parseNum(Map map, List<String> keys) {
    for (final k in keys) {
      final v = num.tryParse(map[k]?.toString() ?? '');
      if (v != null) return v.toDouble();
    }
    return 0;
  }

  String _fmtDays(double d) =>
      d == d.truncateToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);

  Widget _skeleton() {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) => Column(
        children: List.generate(
          2,
              (_) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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

  static Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const _PremiumCard({
    required this.child,
    this.borderRadius = 22,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.96),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: Colors.white.withOpacity(0.70), width: 1),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 22,
            offset: const Offset(0, 8)),
      ],
    ),
    child: child,
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.78)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.20),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
      const SizedBox(width: 12),
      Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: _C.textPrimary)),
    ],
  );
}

class _TimeChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TimeChip(
      {required this.label,
        required this.value,
        required this.icon,
        required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.12)),
    ),
    child: Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 7),
        Text(value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: _C.textMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _LeaveStatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _LeaveStatChip(
      {required this.label,
        required this.value,
        required this.icon,
        required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: color.withOpacity(0.11), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.3)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: _C.textSub,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

/// Quick-access chip shown in the home page's Management section
class _QuickChip extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickChip(
      {required this.title,
        required this.icon,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width - 44) / 2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  maxLines: 2,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full group card used on the Timetable tab page
class _GroupCard extends StatelessWidget {
  final _DashGroup group;

  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TimetableAppTheme.radiusLg),
        boxShadow: TimetableAppTheme.cardShadow,
        border: Border.all(color: TimetableAppTheme.border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: group.color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(TimetableAppTheme.radiusLg)),
              border: Border(
                  bottom: BorderSide(color: group.color.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: group.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(group.icon, color: group.color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(group.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: group.color)),
              ],
            ),
          ),
          // Items
          ...group.items.map((item) => InkWell(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => item.screen)),
            borderRadius:
            BorderRadius.circular(TimetableAppTheme.radiusLg),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: group.color.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(9)),
                    child: Icon(item.icon,
                        color: group.color.withOpacity(0.8), size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(item.title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: TimetableAppTheme.textPrimary)),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: group.color.withOpacity(0.5), size: 20),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}