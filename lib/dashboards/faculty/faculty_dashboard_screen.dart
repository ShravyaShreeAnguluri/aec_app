import 'dart:convert';
import 'dart:ui';

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
import '../../screens/leave/leave_history_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/schedule/schedule_screen.dart';
import '../../services/api_service.dart';
import '../../services/app_config.dart';
import '../../services/token_service.dart';

class _C {
  static const navy = Color(0xFF0D47A1);
  static const navyMid = Color(0xFF1565C0);
  static const navyLight = Color(0xFF1E88E5);
  static const accent = Color(0xFF2196F3);
  static const accentLight = Color(0xFF42A5F5);
  static const teal = Color(0xFF0288D1);

  static const bg = Color(0xFFF4F8FD);
  static const bgSoft = Color(0xFFEFF5FC);
  static const cardBg = Color(0xFFFFFFFF);

  static const success = Color(0xFF2E7D32);
  static const successBg = Color(0xFFEAF7EC);
  static const danger = Color(0xFFC62828);
  static const dangerBg = Color(0xFFFFEEF0);
  static const warning = Color(0xFFEF6C00);
  static const warningBg = Color(0xFFFFF4E8);
  static const gold = Color(0xFFBF8600);
  static const purple = Color(0xFF6A1B9A);

  static const textPrimary = Color(0xFF102033);
  static const textSub = Color(0xFF506070);
  static const textMuted = Color(0xFF8A9AAA);
  static const border = Color(0xFFE5EEF7);
}

Color _slotColor(String type) {
  switch (type.toUpperCase()) {
    case 'LAB':
      return const Color(0xFF4F46E5);
    case 'THEORY':
      return _C.navy;
    case 'FIP':
      return _C.success;
    case 'THUB':
      return _C.gold;
    case 'PSA':
      return _C.purple;
    default:
      return _C.textSub;
  }
}

class FacultyDashboardScreen extends StatefulWidget {
  final String email;
  final String name;
  final String facultyId;
  final String department;
  final String? designation;
  final String? qualification;
  final String? profileImage;
  final String role;

  const FacultyDashboardScreen({
    super.key,
    required this.email,
    required this.name,
    required this.facultyId,
    required this.department,
    this.designation,
    this.qualification,
    this.profileImage,
    required this.role,
  });

  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  DateTime today = DateTime.now();

  Map leaveBalance = {};
  bool loadingLeaveBalance = true;

  Map<String, dynamic>? todayAttendance;
  bool loadingTodayAttendance = true;

  List<Map<String, dynamic>> _todaySlots = [];
  bool _loadingTodaySchedule = true;

  late AnimationController _heroCtrl;
  late AnimationController _staggerCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shimmerCtrl;

  late Animation<Offset> _heroSlide;
  late Animation<double> _heroFade;
  late Animation<double> _pulse;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _heroSlide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic),
    );

    _heroFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _heroCtrl, curve: Curves.easeIn),
    );

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.90, end: 1.10).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _shimmer = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear),
    );

    _heroCtrl.forward();
    Future.delayed(
      const Duration(milliseconds: 180),
          () => _staggerCtrl.forward(),
    );

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

  Future<void> _refresh() async {
    await Future.wait([
      _loadLeave(),
      _loadAttendance(),
      _loadTodaySchedule(),
    ]);
  }

  Future<void> _loadLeave() async {
    try {
      final data = await ApiService.getLeaveBalance();
      if (mounted) {
        setState(() {
          leaveBalance = data;
          loadingLeaveBalance = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loadingLeaveBalance = false);
      }
    }
  }

  Future<void> _loadAttendance() async {
    try {
      final data = await ApiService.getTodayAttendanceStatus();
      if (!mounted) return;
      setState(() {
        todayAttendance = data;
        loadingTodayAttendance = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingTodayAttendance = false;
        todayAttendance = {
          'status': 'ERROR',
          'message': 'Unable to load attendance',
          'clock_in_time': null,
          'clock_out_time': null,
          'working_hours': 0,
        };
      });
    }
  }

  int get _todayDayIndex {
    final w = DateTime.now().weekday;
    return w >= 1 && w <= 6 ? w - 1 : 0;
  }

  Future<void> _loadTodaySchedule() async {
    if (widget.facultyId.trim().isEmpty) {
      if (mounted) setState(() => _loadingTodaySchedule = false);
      return;
    }

    try {
      final token = await TokenService.getToken();

      final res = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/timetable/faculty/${widget.facultyId.trim()}/schedule',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
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
            .toList();

        all.sort(
              (a, b) =>
              (a['period'] as int? ?? 0).compareTo(b['period'] as int? ?? 0),
        );

        setState(() {
          _todaySlots = all;
          _loadingTodaySchedule = false;
        });
      } else {
        setState(() => _loadingTodaySchedule = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTodaySchedule = false);
    }
  }

  void _openDocs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DocumentProvider()),
            ChangeNotifierProvider(create: (_) => CertificateProvider()),
          ],
          child: HomeScreen(facultyName: widget.name),
        ),
      ),
    );
  }

  void _openCerts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CertificateProvider(),
          child: CertificatesScreen(facultyName: widget.name),
        ),
      ),
    );
  }

  Animation<double> _stag(int i) {
    final s = (i * 0.10).clamp(0.0, 0.75);
    final e = (s + 0.35).clamp(s + 0.01, 1.0);
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(s, e, curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _sw(int i, Widget child) {
    return AnimatedBuilder(
      animation: _staggerCtrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, 26 * (1 - _stag(i).value)),
        child: Opacity(opacity: _stag(i).value, child: child),
      ),
    );
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _home(),
      AttendanceMenuScreen(email: widget.email),
      LeaveHistoryScreen(),
      ScheduleScreen(facultyId: widget.facultyId),
      ProfileScreen(
        name: widget.name,
        email: widget.email,
        facultyId: widget.facultyId,
        department: widget.department,
        designation: widget.designation,
        qualification: widget.qualification,
        profileImage: widget.profileImage,
      ),
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

  Widget _buildBottomNav() {
    const items = [
      (icon: Icons.home_rounded, label: 'Home'),
      (icon: Icons.fingerprint_rounded, label: 'Attendance'),
      (icon: Icons.event_note_rounded, label: 'Leave'),
      (icon: Icons.calendar_view_week_rounded, label: 'Schedule'),
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
              top: BorderSide(color: _C.border.withOpacity(0.9), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
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
                        horizontal: 18,
                        vertical: 10,
                      )
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
                            color: const Color(0xFF1565C0).withOpacity(0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            items[i].icon,
                            color: selected ? Colors.white : _C.textMuted,
                            size: 21,
                          ),
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

  Widget _home() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEAF2FC),
            Color(0xFFF5F8FD),
            Color(0xFFFFFFFF),
          ],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          color: _C.navyLight,
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 86),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _heroCtrl,
                  builder: (_, __) => SlideTransition(
                    position: _heroSlide,
                    child: FadeTransition(
                      opacity: _heroFade,
                      child: _buildHero(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _sw(0, _buildCalendarCard()),
                const SizedBox(height: 20),
                _sw(1, _buildScheduleCard()),
                const SizedBox(height: 20),
                _sw(2, _buildLogsCard()),
                const SizedBox(height: 20),
                _sw(3, _buildLeaveCard()),
                const SizedBox(height: 20),
                _sw(4, _buildHolidaysCard()),
                const SizedBox(height: 20),
                _sw(5, _buildResourcesSection()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    final initials = widget.name.trim().isNotEmpty
        ? widget.name
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join()
        : 'F';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D47A1),
            Color(0xFF1565C0),
            Color(0xFF1E88E5),
          ],
          stops: [0.0, 0.52, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withOpacity(0.22),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -22,
            right: -10,
            child: _circle(118, Colors.white.withOpacity(0.05)),
          ),
          Positioned(
            bottom: -34,
            left: -18,
            child: _circle(92, Colors.white.withOpacity(0.04)),
          ),
          Positioned(
            top: 70,
            right: 30,
            child: _circle(52, Colors.white.withOpacity(0.035)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                                color: const Color(0xFF34D399).withOpacity(0.45),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'Online',
                      style: TextStyle(
                        color: Color(0xFFB9F6CA),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
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
                          color: Colors.white.withOpacity(0.22),
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good $_greeting',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.department,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
                        Icons.badge_outlined,
                        'Faculty ID',
                        widget.facultyId,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _heroStat(
                        Icons.workspace_premium_rounded,
                        'Designation',
                        widget.designation ?? 'Faculty',
                      ),
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
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.66),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
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

  Widget _buildCalendarCard() {
    return _PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('Calendar', Icons.calendar_month_rounded, _C.teal),
          const SizedBox(height: 12),
          TableCalendar(
            focusedDay: today,
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            calendarFormat: CalendarFormat.week,
            headerVisible: false,
            selectedDayPredicate: (d) => isSameDay(d, today),
            onDaySelected: (sel, foc) => setState(() => today = sel),
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Color(0xFF42A5F5),
                shape: BoxShape.circle,
              ),
              weekendTextStyle: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
              ),
              defaultTextStyle: TextStyle(
                color: _C.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              todayTextStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: _C.textSub,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              weekendStyle: TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    const periodTimes = [
      '09:30',
      '10:20',
      '11:10',
      '12:00',
      '13:00',
      '13:50',
      '14:40',
      '15:30',
    ];

    return _PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeader(
                  "Today's Classes",
                  Icons.class_rounded,
                  _C.accent,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _currentIndex = 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _C.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Full Schedule',
                        style: TextStyle(
                          color: _C.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: _C.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingTodaySchedule)
            _scheduleSkeletonRows()
          else if (_todaySlots.isEmpty)
            _noClassesToday()
          else
            ..._todaySlots.map((slot) {
              final period = slot['period'] as int? ?? 0;
              final time =
              period < periodTimes.length ? periodTimes[period] : '—';
              final subj = slot['subject']?.toString() ??
                  slot['subject_abbr']?.toString() ??
                  'Class';
              final room = slot['room']?.toString() ?? '—';
              final section = slot['section_name']?.toString() ?? '';
              final type = slot['slot_type']?.toString() ?? 'THEORY';
              final color = _slotColor(type);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.035),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subj,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _C.textPrimary,
                            ),
                          ),
                          if (section.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                section,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _C.textSub,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            room,
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

  Widget _scheduleSkeletonRows() {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) => Column(
        children: List.generate(
          3,
              (_) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
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

  Widget _noClassesToday() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _C.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.free_breakfast_rounded,
              color: _C.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No classes today',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _C.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Enjoy your free day',
                style: TextStyle(
                  fontSize: 12,
                  color: _C.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsCard() {
    return _PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            "Today's Logs",
            Icons.receipt_long_rounded,
            _C.gold,
          ),
          const SizedBox(height: 14),
          loadingTodayAttendance ? _skeleton() : _logsContent(),
        ],
      ),
    );
  }

  Widget _logsContent() {
    final status = todayAttendance?['status'] ?? 'UNKNOWN';
    final isPresent = status == 'PRESENT' || status == 'CHECKED_IN';
    final sColor = isPresent ? _C.success : _C.danger;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
          ),
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
                      color: sColor.withOpacity(0.12),
                    ),
                    child: Icon(
                      isPresent
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: sColor,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: sColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      todayAttendance?['message'] ?? '—',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _C.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: sColor.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${todayAttendance?["working_hours"] ?? 0}h',
                        style: TextStyle(
                          color: sColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hours',
                    style: TextStyle(
                      color: sColor.withOpacity(0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                value: todayAttendance?['clock_in_time'] ?? '--',
                icon: Icons.login_rounded,
                color: _C.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimeChip(
                label: 'Clock Out',
                value: todayAttendance?['clock_out_time'] ?? '--',
                icon: Icons.logout_rounded,
                color: _C.danger,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimeChip(
                label: 'Hrs Worked',
                value: '${todayAttendance?["working_hours"] ?? 0}h',
                icon: Icons.timer_rounded,
                color: _C.teal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeaveCard() {
    final allowedD =
    _parseNum(leaveBalance, ['total_allowed', 'total', 'allowed']);
    final usedD = _parseNum(leaveBalance, ['used_days', 'days_used', 'used']);
    final remainingD = (allowedD - usedD).clamp(0, allowedD).toDouble();
    final allowed = allowedD.toInt();
    final progress =
    allowed > 0 ? (usedD / allowedD).clamp(0.0, 1.0) : 0.0;

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
                  'Leave Summary',
                  Icons.event_note_rounded,
                  _C.purple,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _currentIndex = 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _C.purple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          color: _C.purple,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: _C.purple,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (loadingLeaveBalance)
            _skeleton()
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: _C.textSub,
                      ),
                      children: [
                        TextSpan(
                          text: _fmtDays(usedD),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: barColor,
                            letterSpacing: -0.4,
                          ),
                        ),
                        TextSpan(
                          text: ' / $allowed days used',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _C.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_fmtDays(remainingD)} left',
                    style: const TextStyle(
                      color: _C.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                  color: _C.navyLight,
                ),
                const SizedBox(width: 8),
                _LeaveStatChip(
                  label: 'Used',
                  value: _fmtDays(usedD),
                  icon: Icons.remove_circle_outline_rounded,
                  color: barColor,
                ),
                const SizedBox(width: 8),
                _LeaveStatChip(
                  label: 'Remaining',
                  value: _fmtDays(remainingD),
                  icon: Icons.check_circle_outline_rounded,
                  color: _C.success,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  double _parseNum(Map map, List<String> keys) {
    for (final k in keys) {
      final v = num.tryParse(map[k]?.toString() ?? '');
      if (v != null) return v.toDouble();
    }
    return 0;
  }

  String _fmtDays(double d) {
    return d == d.truncateToDouble()
        ? d.toInt().toString()
        : d.toStringAsFixed(1);
  }

  Widget _buildHolidaysCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const HolidayListScreen(isAdmin: false),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0D47A1),
              Color(0xFF1976D2),
              Color(0xFF42A5F5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D47A1).withOpacity(0.20),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.celebration_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Holidays',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'View holiday calendar & schedule',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourcesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Resources',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _C.textPrimary,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _ResourceCard(
                title: 'Faculty Docs',
                subtitle: 'Notes, Assignments\n& Study Material',
                icon: Icons.folder_open_rounded,
                gradient: const [Color(0xFF0D47A1), Color(0xFF1E88E5)],
                glowColor: _C.navy,
                onTap: _openDocs,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _ResourceCard(
                title: 'Certificates',
                subtitle: 'Achievements &\nTraining Records',
                icon: Icons.workspace_premium_rounded,
                gradient: const [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                glowColor: const Color(0xFF7C3AED),
                onTap: _openCerts,
              ),
            ),
          ],
        ),
      ],
    );
  }

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

  static Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.70),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.78)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.20),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: _C.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TimeChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _C.textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveStatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _LeaveStatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
                color: color.withOpacity(0.11),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: _C.textSub,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final Color glowColor;
  final VoidCallback onTap;

  const _ResourceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.onTap,
  });

  @override
  State<_ResourceCard> createState() => _ResourceCardState();
}

class _ResourceCardState extends State<_ResourceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _s = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _s,
        builder: (_, child) => Transform.scale(scale: _s.value, child: child),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradient,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(0.26),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.74),
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}