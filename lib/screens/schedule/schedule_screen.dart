import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:faculty_app/services/app_config.dart';

import '../../services/token_service.dart';
import '../operator/timetable/view_section_timetable_screen.dart';

// ─── Period / Day Constants ────────────────────────────────────────────────────
const List<String> kPeriodLabels = [
  'P1  09:30–10:20',
  'P2  10:20–11:10',
  'P3  11:10–12:00',
  'LUNCH',
  'P5  13:00–13:50',
  'P6  13:50–14:40',
  'P7  14:40–15:30',
  'P8  15:30–16:20',
];

/// Returns just the time range part, e.g. "09:30–10:20"
String kPeriodTime(int p) {
  if (p < 0 || p >= kPeriodLabels.length) return '';
  final raw = kPeriodLabels[p];
  if (raw == 'LUNCH') return '12:00–13:00';
  final parts = raw.split('  ');
  return parts.length > 1 ? parts[1] : raw;
}

const List<String> kDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const List<String> kFullDayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];

// ─── Colour Tokens ─────────────────────────────────────────────────────────────
class _SC {
  static const navy        = Color(0xFF0D47A1);
  static const navyMid     = Color(0xFF1565C0);
  static const navyLight   = Color(0xFF1E88E5);
  static const accent      = Color(0xFF2196F3);
  static const bg          = Color(0xFFF0F6FF);
  static const textPrimary = Color(0xFF0D1B2A);
  static const textSub     = Color(0xFF37474F);
  static const textMuted   = Color(0xFF78909C);

  static const labColor    = Color(0xFF1565C0);
  static const theoryColor = Color(0xFF0D47A1);
  static const fipColor    = Color(0xFF2E7D32);
  static const thubColor   = Color(0xFFBF8600);
  static const psaColor    = Color(0xFF6A1B9A);
  static const lunchColor  = Color(0xFFEF6C00);
  static const freeColor   = Color(0xFF546E7A);

  static Color slotAccent(String type) {
    switch (type.toUpperCase()) {
      case 'LAB':    return labColor;
      case 'THEORY': return theoryColor;
      case 'FIP':    return fipColor;
      case 'THUB':   return thubColor;
      case 'PSA':    return psaColor;
      case 'LUNCH':  return lunchColor;
      default:       return freeColor;
    }
  }

  static Color slotSoft(String type) {
    switch (type.toUpperCase()) {
      case 'LAB':    return const Color(0xFFEEF2FF);
      case 'THEORY': return const Color(0xFFEFF6FF);
      case 'FIP':    return const Color(0xFFECFDF5);
      case 'THUB':   return const Color(0xFFFEF3C7);
      case 'PSA':    return const Color(0xFFF5F3FF);
      case 'LUNCH':  return const Color(0xFFFFF7ED);
      default:       return const Color(0xFFF8FAFC);
    }
  }
}

// ─── Data Model ───────────────────────────────────────────────────────────────
class TimetableSlotModel {
  final int day;
  final int period;
  final String slotType;
  final String? subjectName;
  final String? subjectAbbr;
  final String? facultyName;
  final String? room;
  final String? sectionName;
  final int? sectionYear;
  final bool isLabContinuation;

  TimetableSlotModel({
    required this.day,
    required this.period,
    required this.slotType,
    this.subjectName,
    this.subjectAbbr,
    this.facultyName,
    this.room,
    this.sectionName,
    this.sectionYear,
    this.isLabContinuation = false,
  });

  factory TimetableSlotModel.fromJson(Map<String, dynamic> json) {
    return TimetableSlotModel(
      day: json['day_index'] ?? json['day'] ?? 0,
      period: json['period'] ?? 0,
      slotType: (json['slot_type'] ?? 'FREE').toString(),
      subjectName: json['subject']?.toString(),
      subjectAbbr: json['subject_abbr']?.toString(),
      facultyName: json['faculty_name']?.toString(),
      room: json['room']?.toString(),
      sectionName: json['section_name']?.toString(),
      sectionYear: json['section_year'] as int?,
      isLabContinuation: json['is_lab_continuation'] ?? false,
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class ScheduleScreen extends StatefulWidget {
  /// Pass the faculty ID here. If it is empty, the screen will automatically
  /// read it from the stored session so the HOD's own schedule always loads.
  final String facultyId;
  const ScheduleScreen({super.key, required this.facultyId});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with TickerProviderStateMixin {
  List<TimetableSlotModel> _slots = [];
  bool _loading = true;
  String? _error;
  String _facultyName = '';
  String _token = '';

  /// The resolved faculty ID (widget.facultyId OR read from session).
  String _resolvedFacultyId = '';

  // 0=Today, 1=Weekly, 2=Grid, 3=Timeline, 4=Sections
  int _selectedView = 0;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  int get _todayIndex {
    final w = DateTime.now().weekday;
    return w >= 1 && w <= 6 ? w - 1 : 0;
  }
  int get _tomorrowIndex => _todayIndex >= 5 ? 0 : _todayIndex + 1;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadSchedule();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Resolve faculty ID ─────────────────────────────────────────────────────
  Future<String> _resolveFacultyId() async {
    final fromWidget = widget.facultyId.trim();
    if (fromWidget.isNotEmpty) return fromWidget;

    // Fall back to stored session — covers the HOD case where facultyId
    // might not be forwarded through the widget tree.
    final session = await TokenService.getUserSession();
    return (session['facultyId'] ?? '').trim();
  }

  Future<void> _loadSchedule() async {
    setState(() { _loading = true; _error = null; });

    try {
      _resolvedFacultyId = await _resolveFacultyId();
    } catch (_) {
      _resolvedFacultyId = '';
    }

    if (_resolvedFacultyId.isEmpty) {
      setState(() {
        _error = 'Faculty ID is missing. Please log out and log in again.';
        _loading = false;
      });
      return;
    }

    try {
      final token = await TokenService.getToken();
      _token = token ?? '';
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/timetable/faculty/$_resolvedFacultyId/schedule'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode != 200) {
        throw Exception('Status ${res.statusCode}: ${res.body}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final schedule = (data['schedule'] as List? ?? [])
          .map((e) => TimetableSlotModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _facultyName = data['faculty_name']?.toString() ?? '';
        _slots = schedule;
        _loading = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<TimetableSlotModel> _slotsForDay(int day) {
    final list = _slots.where((s) => s.day == day).toList();
    list.sort((a, b) => a.period.compareTo(b.period));
    return list;
  }

  int get _todayCount    => _slotsForDay(_todayIndex).length;
  int get _tomorrowCount => _slotsForDay(_tomorrowIndex).length;
  int get _weeklyCount   => _slots.length;

  Set<String> get _sectionNames =>
      _slots.map((e) => e.sectionName?.trim() ?? '').where((e) => e.isNotEmpty).toSet();

  String get _nextClassText {
    final now = DateTime.now();
    final todaySlots = _slotsForDay(_todayIndex);
    for (final s in todaySlots) {
      if (_periodStartMinutes(s.period) > (now.hour * 60 + now.minute)) {
        return '${s.subjectAbbr ?? s.subjectName ?? 'Class'} · ${kDayNames[_todayIndex]} ${kPeriodTime(s.period)}';
      }
    }
    final tmSlots = _slotsForDay(_tomorrowIndex);
    if (tmSlots.isNotEmpty) {
      final s = tmSlots.first;
      return '${s.subjectAbbr ?? s.subjectName ?? 'Class'} · ${kDayNames[_tomorrowIndex]} ${kPeriodTime(s.period)}';
    }
    return 'No upcoming class';
  }

  int _periodStartMinutes(int p) {
    const m = [570, 620, 670, 720, 780, 830, 880, 930];
    return p >= 0 && p < m.length ? m[p] : 24 * 60;
  }

  String _yearLabel(int? y) {
    if (y == null) return '';
    const suffix = ['st', 'nd', 'rd', 'th'];
    final s = y >= 1 && y <= 4 ? suffix[y - 1] : 'th';
    return '$y$s Yr';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SC.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F1FD), Color(0xFFF5F9FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? _buildLoader()
              : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadSchedule)
              : RefreshIndicator(
            color: _SC.navyLight,
            onRefresh: _loadSchedule,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroHeader(),
                          const SizedBox(height: 12),
                          _buildSummaryStrip(),
                          const SizedBox(height: 16),
                          _buildViewSelector(),
                          const SizedBox(height: 16),
                          _buildCurrentView(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.70),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: _SC.navy.withOpacity(0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF1E4D8F), strokeWidth: 3),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Loading schedule…',
              style: TextStyle(color: _SC.textSub, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Hero Header ─────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return _GlassCard(
      borderRadius: 28,
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D47A1), Color(0xFF1565C0),
              Color(0xFF1976D2), Color(0xFF2196F3),
            ],
            stops: [0.0, 0.3, 0.65, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
                top: -20, right: -10,
                child: _circle(100, Colors.white.withOpacity(0.05))),
            Positioned(
                bottom: -30, right: 60,
                child: _circle(70, Colors.white.withOpacity(0.04))),

            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.20)),
                  ),
                  child: const Icon(Icons.grid_view_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My Schedule',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(
                        _facultyName.isEmpty
                            ? _resolvedFacultyId
                            : _facultyName,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.70),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                    border:
                    Border.all(color: Colors.white.withOpacity(0.20)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.badge_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(height: 3),
                      Text(_resolvedFacultyId,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Summary strip ────────────────────────────────────────────────────────
  Widget _buildSummaryStrip() {
    return Column(
      children: [
        Row(
          children: [
            _summaryPill(
              Icons.today_rounded,
              kFullDayNames[_todayIndex],
              '$_todayCount classes',
              const Color(0xFF34D399),
              isToday: true,
            ),
            const SizedBox(width: 8),
            _summaryPill(
              Icons.event_rounded,
              kFullDayNames[_tomorrowIndex],
              '$_tomorrowCount classes',
              const Color(0xFFA78BFA),
            ),
            const SizedBox(width: 8),
            _summaryPill(
              Icons.calendar_view_week_rounded,
              'This Week',
              '$_weeklyCount total',
              const Color(0xFF34D399),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF0D47A1).withOpacity(0.18), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: Color(0xFF34D399), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text('Next: ',
                  style: TextStyle(
                      color: Color(0xFF059669),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              Expanded(
                child: Text(
                  _nextClassText,
                  style: const TextStyle(
                      color: _SC.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryPill(IconData icon, String day, String count, Color color,
      {bool isToday = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isToday
              ? const Color(0xFF0D47A1).withOpacity(0.08)
              : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isToday
                  ? const Color(0xFF0D47A1).withOpacity(0.20)
                  : const Color(0xFFE3EDF9),
              width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 13),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(day,
                      style: const TextStyle(
                          color: _SC.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(count,
                style: const TextStyle(
                    color: _SC.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  // ─── View Selector ────────────────────────────────────────────────────────
  Widget _buildViewSelector() {
    const items = [
      (icon: Icons.today_rounded,     label: 'Today'),
      (icon: Icons.view_week_rounded, label: 'Weekly'),
      (icon: Icons.grid_on_rounded,   label: 'Grid'),
      (icon: Icons.timeline_rounded,  label: 'Timeline'),
      (icon: Icons.groups_rounded,    label: 'Sections'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = _selectedView == i;
          return Padding(
            padding: EdgeInsets.only(right: i == items.length - 1 ? 0 : 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedView = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: selected
                      ? const LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: selected ? null : Colors.white,
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : const Color(0xFFBBDEFB),
                    width: 1.5,
                  ),
                  boxShadow: selected
                      ? [
                    BoxShadow(
                      color:
                      const Color(0xFF1565C0).withOpacity(0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    )
                  ]
                      : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Icon(items[i].icon,
                        size: 16,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF506680)),
                    const SizedBox(width: 7),
                    Text(items[i].label,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF506680),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        )),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Current View Dispatcher ──────────────────────────────────────────────
  Widget _buildCurrentView() {
    switch (_selectedView) {
      case 0: return _buildDayView(_todayIndex, 'Today');
      case 1: return _buildWeeklyCards();
      case 2: return _buildWeeklyGrid();
      case 3: return _buildTimelineView();
      case 4: return _buildSectionView();
      default: return _buildDayView(_todayIndex, 'Today');
    }
  }

  // ─── Day View ─────────────────────────────────────────────────────────────
  Widget _buildDayView(int dayIndex, String label) {
    final slots = _slotsForDay(dayIndex);

    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1E4D8F), Color(0xFF3B82F6)]),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                    label == 'Today'
                        ? Icons.today_rounded
                        : Icons.event_rounded,
                    color: Colors.white,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$label – ${kFullDayNames[dayIndex]}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _SC.navy)),
                  Text('${slots.length} period${slots.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: _SC.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              const Spacer(),
              _PillBadge('${slots.length}', _SC.accent),
            ],
          ),
          const SizedBox(height: 18),
          if (slots.isEmpty)
            _EmptyState(
              icon: Icons.coffee_rounded,
              title: 'No classes',
              subtitle: 'No teaching periods for $label.',
            )
          else
            ...List.generate(
              slots.length,
                  (i) => Padding(
                padding: EdgeInsets.only(
                    bottom: i == slots.length - 1 ? 0 : 12),
                child: _PeriodCard(slot: slots[i]),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Weekly Cards ─────────────────────────────────────────────────────────
  Widget _buildWeeklyCards() {
    return Column(
      children: List.generate(6, (day) {
        final slots = _slotsForDay(day);
        final isToday = day == _todayIndex;
        return Padding(
          padding: EdgeInsets.only(bottom: day == 5 ? 0 : 14),
          child: _GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isToday
                            ? const LinearGradient(
                          colors: [
                            Color(0xFF0D47A1),
                            Color(0xFF1E88E5)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : null,
                        color: isToday ? null : const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        kDayNames[day],
                        style: TextStyle(
                          color: isToday
                              ? Colors.white
                              : const Color(0xFF1E4D8F),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(kFullDayNames[day],
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _SC.textPrimary)),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      const _PillBadge('Today', Color(0xFF059669)),
                    ],
                    const Spacer(),
                    _PillBadge('${slots.length}', _SC.navyLight),
                  ],
                ),
                if (slots.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...slots.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CompactRow(slot: s),
                  )),
                ] else ...[
                  const SizedBox(height: 12),
                  const Text('Free day — no classes scheduled.',
                      style: TextStyle(
                          color: _SC.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  // ─── Weekly Grid ──────────────────────────────────────────────────────────
  Widget _buildWeeklyGrid() {
    final cellMap = <String, TimetableSlotModel>{};
    for (final s in _slots) {
      cellMap['${s.day}_${s.period}'] = s;
    }

    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1E4D8F), Color(0xFF3B82F6)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.grid_on_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Grid',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _SC.navy)),
                  Text('Complete timetable at a glance',
                      style: TextStyle(
                          fontSize: 12,
                          color: _SC.textSub,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Table(
                defaultColumnWidth:
                const FixedColumnWidth(110),
                border: TableBorder.all(
                  color: const Color(0xFFCDD6E8),
                  width: 0.8,
                  borderRadius: BorderRadius.circular(18),
                ),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
                      ),
                    ),
                    children: [
                      _gridHeader('Period'),
                      ...kDayNames.map(_gridHeader),
                    ],
                  ),
                  ...List.generate(8, (period) {
                    final isLunch = kPeriodLabels[period] == 'LUNCH';
                    return TableRow(
                      decoration: BoxDecoration(
                        color: isLunch
                            ? const Color(0xFFFFF7ED)
                            : period.isEven
                            ? Colors.white.withOpacity(0.85)
                            : const Color(0xFFF5F8FF),
                      ),
                      children: [
                        _gridCell(
                          isLunch
                              ? 'Lunch'
                              : kPeriodLabels[period],
                          isHeader: true,
                        ),
                        ...List.generate(6, (day) {
                          final slot = cellMap['${day}_$period'];
                          if (slot == null) return _gridCell('—');
                          return _gridCellSlot(slot);
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LegendChip('Theory', _SC.theoryColor),
              _LegendChip('Lab', _SC.labColor),
              _LegendChip('FIP', _SC.fipColor),
              _LegendChip('T-Hub', _SC.thubColor),
              _LegendChip('PSA', _SC.psaColor),
              _LegendChip('Lunch', _SC.lunchColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gridHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11)),
    );
  }

  Widget _gridCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: isHeader ? _SC.textSub : _SC.textMuted,
              fontWeight:
              isHeader ? FontWeight.w700 : FontWeight.w500,
              fontSize: 10)),
    );
  }

  Widget _gridCellSlot(TimetableSlotModel slot) {
    final accent = _SC.slotAccent(slot.slotType);
    return Container(
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: _SC.slotSoft(slot.slotType),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(slot.slotType,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: accent,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
          const SizedBox(height: 4),
          Text(
            slot.subjectAbbr ?? slot.subjectName ?? '—',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _SC.navy,
                fontWeight: FontWeight.w800,
                fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            slot.sectionName ?? '—',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _SC.textSub,
                fontWeight: FontWeight.w600,
                fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ─── Timeline View ────────────────────────────────────────────────────────
  Widget _buildTimelineView() {
    final entries = <({int day, TimetableSlotModel slot})>[];
    for (int d = 0; d < 6; d++) {
      for (final s in _slotsForDay(d)) {
        entries.add((day: d, slot: s));
      }
    }

    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.timeline_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Teaching Timeline',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _SC.navy)),
                  Text('Period-wise flow across the week',
                      style: TextStyle(
                          fontSize: 12,
                          color: _SC.textSub,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              const Spacer(),
              _PillBadge('${entries.length} slots',
                  const Color(0xFF7C3AED)),
            ],
          ),
          const SizedBox(height: 20),

          if (entries.isEmpty)
            const _EmptyState(
              icon: Icons.hourglass_empty_rounded,
              title: 'No teaching periods',
              subtitle: 'No schedule data found for the week.',
            )
          else
            ...List.generate(entries.length, (i) {
              final e = entries[i];
              final accent = _SC.slotAccent(e.slot.slotType);
              final isLast = i == entries.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: accent.withOpacity(0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2))
                          ],
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 80,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                accent.withOpacity(0.30),
                                accent.withOpacity(0.06),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Padding(
                      padding:
                      EdgeInsets.only(bottom: isLast ? 0 : 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: accent.withOpacity(0.22), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: accent.withOpacity(0.10),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${kDayNames[e.day]} · P${e.slot.period + 1}  ${kPeriodTime(e.slot.period)}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: accent,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.10),
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  child: Text(e.slot.slotType,
                                      style: TextStyle(
                                          color: accent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              e.slot.subjectName ??
                                  e.slot.subjectAbbr ??
                                  'Class',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _SC.navy),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 7, runSpacing: 7,
                              children: [
                                _MiniChip(
                                  Icons.groups_rounded,
                                  e.slot.sectionYear != null
                                      ? '${e.slot.sectionName ?? '—'} (${_yearLabel(e.slot.sectionYear)})'
                                      : e.slot.sectionName ?? '—',
                                ),
                                _MiniChip(Icons.meeting_room_outlined,
                                    e.slot.room ?? '—'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  // ─── Section View ─────────────────────────────────────────────────────────
  Widget _buildSectionView() {
    final sections = _sectionNames.toList()..sort();

    return Column(
      children: [
        _GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF10B981)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.groups_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Sections',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _SC.navy)),
                      Text('Sections from your timetable',
                          style: TextStyle(
                              fontSize: 12,
                              color: _SC.textSub,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Spacer(),
                  _PillBadge(
                      '${sections.length}', const Color(0xFF059669)),
                ],
              ),
              const SizedBox(height: 16),
              if (sections.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: _SC.textMuted),
                      SizedBox(width: 10),
                      Text('No mapped sections found.',
                          style: TextStyle(
                              color: _SC.textSub,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: sections.map((sec) {
                    final slots = _slots
                        .where((s) => s.sectionName == sec)
                        .toList();
                    final yearVal = slots.isNotEmpty
                        ? slots.first.sectionYear
                        : null;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF90CAF9), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sec,
                              style: const TextStyle(
                                  color: _SC.navyLight,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                          const SizedBox(height: 2),
                          if (yearVal != null)
                            Text(_yearLabel(yearVal),
                                style: const TextStyle(
                                    color: _SC.textSub,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${slots.length} periods/week',
                              style: const TextStyle(
                                  color: _SC.textSub,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (sections.isNotEmpty)
          ...sections.map((sec) {
            final sectionSlots = _slots
                .where((s) => s.sectionName == sec)
                .toList()
              ..sort((a, b) {
                if (a.day != b.day) return a.day.compareTo(b.day);
                return a.period.compareTo(b.period);
              });
            final yearVal = sectionSlots.isNotEmpty
                ? sectionSlots.first.sectionYear
                : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF0D47A1),
                                Color(0xFF1E88E5)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(sec,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${sectionSlots.length} teaching periods',
                              style: const TextStyle(
                                  color: _SC.textSub,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12),
                            ),
                            if (yearVal != null)
                              Text(
                                _yearLabel(yearVal),
                                style: const TextStyle(
                                    color: _SC.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ViewSectionTimetableScreen(
                                    token: _token),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF90CAF9),
                                  width: 1.5),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.open_in_new_rounded,
                                    size: 13,
                                    color: Color(0xFF0D47A1)),
                                SizedBox(width: 5),
                                Text('Grid',
                                    style: TextStyle(
                                        color: Color(0xFF0D47A1),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...sectionSlots.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CompactRow(slot: s, showDay: true),
                    )),
                  ],
                ),
              ),
            );
          }),

        _GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.grid_view_rounded,
                      color: _SC.navyLight, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Open full section timetable grid for any section.',
                      style: TextStyle(
                          color: _SC.textSub,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ViewSectionTimetableScreen(
                            token: _token),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('View Section Timetable',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  REUSABLE WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const _GlassCard({
    required this.child,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE3EDF9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final TimetableSlotModel slot;
  const _PeriodCard({required this.slot});

  String _yearLabel(int? y) {
    if (y == null) return '';
    const suffix = ['st', 'nd', 'rd', 'th'];
    final s = y >= 1 && y <= 4 ? suffix[y - 1] : 'th';
    return '$y$s Yr';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _SC.slotAccent(slot.slotType);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.22), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: accent.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 5)),
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withOpacity(0.14),
                  accent.withOpacity(0.06)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border:
              Border.all(color: accent.withOpacity(0.22), width: 1.5),
            ),
            child: Center(
              child: Text('P${slot.period + 1}',
                  style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        slot.subjectName ?? slot.subjectAbbr ?? 'Class',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _SC.navy),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: accent.withOpacity(0.18)),
                      ),
                      child: Text(slot.slotType,
                          style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Wrap(
                  spacing: 7, runSpacing: 6,
                  children: [
                    if (slot.sectionName != null)
                      _MiniChip(
                        Icons.groups_rounded,
                        slot.sectionYear != null
                            ? '${slot.sectionName!}  (${_yearLabel(slot.sectionYear)})'
                            : slot.sectionName!,
                      ),
                    if (slot.room != null)
                      _MiniChip(Icons.meeting_room_outlined, slot.room!),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 13, color: accent.withOpacity(0.8)),
                    const SizedBox(width: 5),
                    Text(
                      kPeriodTime(slot.period),
                      style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
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
}

class _CompactRow extends StatelessWidget {
  final TimetableSlotModel slot;
  final bool showDay;

  const _CompactRow({required this.slot, this.showDay = false});

  String _yearLabel(int? y) {
    if (y == null) return '';
    const suffix = ['st', 'nd', 'rd', 'th'];
    final s = y >= 1 && y <= 4 ? suffix[y - 1] : 'th';
    return '$y$s Yr';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _SC.slotAccent(slot.slotType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.20), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: accent.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('P${slot.period + 1}',
                style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showDay
                      ? '${kDayNames[slot.day]} · ${slot.subjectName ?? slot.subjectAbbr ?? "Class"}'
                      : slot.subjectName ?? slot.subjectAbbr ?? 'Class',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _SC.navy),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        slot.sectionYear != null
                            ? '${slot.sectionName ?? '—'} (${_yearLabel(slot.sectionYear)}) · ${slot.room ?? '—'}'
                            : '${slot.sectionName ?? '—'} · ${slot.room ?? '—'}',
                        style: const TextStyle(
                            color: _SC.textSub,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      kPeriodTime(slot.period),
                      style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(slot.slotType,
                style: TextStyle(
                    color: accent, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PillBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.28), width: 1.5),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBDEFB), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _SC.textSub),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  color: _SC.textSub,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
              BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFBBDEFB), width: 1.5),
              ),
              child:
              Icon(icon, color: const Color(0xFF0D47A1), size: 28),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _SC.navy)),
            const SizedBox(height: 5),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _SC.textSub, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState(
      {required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFB91C1C), size: 32),
            ),
            const SizedBox(height: 18),
            const Text('Unable to load schedule',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _SC.navy)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _SC.textSub, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}