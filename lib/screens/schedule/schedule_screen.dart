// lib/features/timetable/timetable_screen.dart
// Daily schedule viewer for faculty — integrates with existing Flutter app

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:faculty_app/services/app_config.dart';

import '../../services/token_service.dart';

// ─── Period timing constants (match backend) ─────────────────────────────────

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

const List<String> kPeriodLabelsShifted = [
  'P1  09:30–10:20',
  'P2  10:20–11:10',
  'P3  11:10–12:00',
  'LUNCH 12:00–12:50',
  'P5  12:50–13:50',
  'P6  13:50–14:40',
  'P7  14:40–15:30',
  'P8  15:30–16:20',
];

const List<String> kDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

// ─── Data models ─────────────────────────────────────────────────────────────

class TimetableSlotModel {
  final int day;
  final int period;
  final String slotType;
  final String? subjectName;
  final String? subjectAbbr;
  final String? facultyName;
  final String? room;
  final bool isLabContinuation;

  TimetableSlotModel({
    required this.day,
    required this.period,
    required this.slotType,
    this.subjectName,
    this.subjectAbbr,
    this.facultyName,
    this.room,
    this.isLabContinuation = false,
  });

  factory TimetableSlotModel.fromJson(Map<String, dynamic> json) =>
      TimetableSlotModel(
        day: json['day_index'] ?? json['day'] ?? 0,   // ← backend sends day_index
        period: json['period'] ?? 0,
        slotType: json['slot_type'] ?? 'FREE',
        subjectName: json['subject'],                  // ← backend sends 'subject' not 'subject_name'
        subjectAbbr: json['subject_abbr'],
        facultyName: json['faculty_name'],
        room: json['room'],
        isLabContinuation: json['is_lab_continuation'] ?? false,
      );
}

// ─── API service ─────────────────────────────────────────────────────────────

class TimetableService {
  final String baseUrl;
  TimetableService(this.baseUrl);

  Future<List<TimetableSlotModel>> fetchFacultySchedule(int facultyId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/timetable/faculty/$facultyId/schedule'),
    );
    if (res.statusCode != 200) throw Exception('Failed to load schedule');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['schedule'] as List)
        .map((e) => TimetableSlotModel.fromJson(e))
        .toList();
  }

  Future<Map<String, dynamic>> generateTimetable(int departmentId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/timetable/generate/sync'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'department_id': departmentId,
        'academic_year': '2025-26',
      }),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

// ─── Main timetable screen ────────────────────────────────────────────────────

class ScheduleScreen extends StatefulWidget {
  final String facultyId;

  const ScheduleScreen({
    super.key,
    required this.facultyId,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late final TimetableService _service;
  late TabController _tabController;

  List<TimetableSlotModel>? _slots;
  bool _loading = true;
  String? _error;

  // Today's weekday index (0=Mon … 5=Sat)
  int get _todayIndex {
    final wd = DateTime.now().weekday; // 1=Mon … 7=Sun
    return wd <= 6 ? wd - 1 : 0;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this, initialIndex: _todayIndex);
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    try {
      // Get token the same way your other screens do
      final token = await TokenService.getToken(); // or however you get token

      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/timetable/faculty/${widget.facultyId}/schedule'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Status: ${res.statusCode}');
      print('Body: ${res.body}');

      if (res.statusCode != 200) throw Exception('Status ${res.statusCode}: ${res.body}');

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final slots = (data['schedule'] as List)
          .map((e) => TimetableSlotModel.fromJson(e))
          .toList();
      setState(() {
        _slots = slots;
        _loading = false;
      });
    } catch (e) {
      print('Schedule error: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<TimetableSlotModel> _slotsForDay(int dayIndex) =>
      (_slots ?? []).where((s) => s.day == dayIndex).toList()
        ..sort((a, b) => a.period.compareTo(b.period));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Schedule'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: kDayNames.map((d) => Tab(text: d)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!)
          : TabBarView(
        controller: _tabController,
        children: List.generate(
          6,
              (i) => _DayView(
            slots: _slotsForDay(i),
            dayIndex: i,
          ),
        ),
      ),
    );
  }
}

// ─── Day view ─────────────────────────────────────────────────────────────────

class _DayView extends StatelessWidget {
  final List<TimetableSlotModel> slots;
  final int dayIndex;

  const _DayView({required this.slots, required this.dayIndex});

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.free_breakfast_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No classes today', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Build 8-period list (fill gaps with FREE)
    final byPeriod = {for (var s in slots) s.period: s};
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: 8,
      itemBuilder: (ctx, i) {
        final slot = byPeriod[i];
        return _PeriodCard(periodIndex: i, slot: slot);
      },
    );
  }
}

// ─── Period card ─────────────────────────────────────────────────────────────

class _PeriodCard extends StatelessWidget {
  final int periodIndex;
  final TimetableSlotModel? slot;

  const _PeriodCard({required this.periodIndex, this.slot});

  @override
  Widget build(BuildContext context) {
    final timeLabel = kPeriodLabels[periodIndex];
    final type = slot?.slotType ?? 'FREE';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 90,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                timeLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Card
          Expanded(child: _buildCard(context, type)),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, String type) {
    if (type == 'LUNCH') return _lunchCard(context);
    if (type == 'FREE') return _freeCard(context);
    if (type == 'FIP') return _fipCard(context);
    if (type == 'THUB') return _thubCard(context);
    if (slot?.isLabContinuation == true) return const SizedBox.shrink();

    final isLab = type == 'LAB';
    final color = isLab ? Colors.indigo : Colors.blue;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      color: color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeBadge(type: type),
                const Spacer(),
                if (slot?.room != null)
                  Text(
                    slot!.room!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              slot?.subjectName ?? '-',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (slot?.facultyName != null) ...[
              const SizedBox(height: 4),
              Text(
                slot!.facultyName!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lunchCard(BuildContext context) => Card(
    elevation: 0,
    color: Colors.orange.withOpacity(0.08),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: Colors.orange.withOpacity(0.2)),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.lunch_dining_outlined, color: Colors.orange, size: 18),
          SizedBox(width: 8),
          Text('Lunch Break', style: TextStyle(color: Colors.orange)),
        ],
      ),
    ),
  );

  Widget _freeCard(BuildContext context) => const SizedBox(height: 20);

  Widget _fipCard(BuildContext context) => Card(
    elevation: 0,
    color: Colors.teal.withOpacity(0.06),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: Colors.teal.withOpacity(0.2)),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.school_outlined, color: Colors.teal, size: 18),
          SizedBox(width: 8),
          Text('FIP', style: TextStyle(color: Colors.teal)),
        ],
      ),
    ),
  );

  Widget _thubCard(BuildContext context) => Card(
    elevation: 0,
    color: Colors.brown.withOpacity(0.08),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: Colors.brown.withOpacity(0.2)),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.hub_outlined, color: Colors.brown, size: 18),
          SizedBox(width: 8),
          Text('T-Hub Session', style: TextStyle(color: Colors.brown)),
        ],
      ),
    ),
  );
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'LAB' => ('Lab', Colors.indigo),
      'THEORY' => ('Theory', Colors.blue),
      'CRT' => ('CRT', Colors.purple),
      _ => (type, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
