import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';

class ViewFacultyTimetableScreen extends StatefulWidget {
  final String token;

  const ViewFacultyTimetableScreen({super.key, required this.token});

  @override
  State<ViewFacultyTimetableScreen> createState() =>
      _ViewFacultyTimetableScreenState();
}

class _ViewFacultyTimetableScreenState
    extends State<ViewFacultyTimetableScreen> {
  final Dio dio = Dio();

  final facultyIdController = TextEditingController();

  List schedule = [];
  String facultyName = "";
  bool loading = false;

  final List<String> dayNames = const ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

  // Subject color palette matching the reference image
  static const List<Color> _subjectColors = [
    Color(0xFF4A90D9), // blue
    Color(0xFF5BA85A), // green
    Color(0xFFE5A03A), // orange
    Color(0xFFD95B5B), // red
    Color(0xFF8E6BBF), // purple
    Color(0xFF3AAEAE), // teal
    Color(0xFFD97A3A), // amber
    Color(0xFF5B8ED9), // light blue
  ];

  Color _colorForSubject(String? subject) {
    if (subject == null || subject.isEmpty) return const Color(0xFF4A90D9);
    final idx = subject.codeUnitAt(0) % _subjectColors.length;
    return _subjectColors[idx];
  }

  Future<void> loadFacultyTimetable() async {
    if (facultyIdController.text.trim().isEmpty) return;

    try {
      setState(() => loading = true);

      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;

      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/faculty/${facultyIdController.text.trim()}/schedule",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      final data = Map<String, dynamic>.from(res.data);

      setState(() {
        facultyName = data["faculty_name"]?.toString() ?? "";
        schedule = data["schedule"] is List ? data["schedule"] : [];
      });
    } catch (e) {
      schedule = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load faculty timetable")),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String dayNameFromIndex(int index) {
    if (index >= 0 && index < dayNames.length) return dayNames[index];
    return "-";
  }

  // Build the weekly grid: rows = periods, columns = days
  Widget _buildTimetableGrid() {
    // Collect unique periods and days
    final Set<int> periodSet = {};
    final Set<int> daySet = {};
    for (final item in schedule) {
      final p = item["period"];
      final d = item["day_index"];
      if (p != null) periodSet.add(p as int);
      if (d != null) daySet.add(d as int);
    }

    final periods = periodSet.toList()..sort();
    final days = daySet.toList()..sort();

    if (periods.isEmpty || days.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            "No timetable loaded",
            style: TextStyle(color: Color(0xFF9AA5B4), fontSize: 15),
          ),
        ),
      );
    }

    // Map (day, period) -> item
    final Map<String, dynamic> cellMap = {};
    for (final item in schedule) {
      final key = "${item["day_index"]}_${item["period"]}";
      cellMap[key] = item;
    }

    const headerColor = Color(0xFF2E5FBF);
    const headerText = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 12,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  "Full Timetable",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B4A),
                  ),
                ),
                const Text(
                  " – By Faculty",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF4A90D9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder.all(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                children: [
                  // Header row
                  TableRow(
                    decoration: const BoxDecoration(color: headerColor),
                    children: [
                      _headerCell("", isFirst: true),
                      for (final d in days) _headerCell(dayNameFromIndex(d)),
                    ],
                  ),
                  // Data rows
                  for (final p in periods)
                    TableRow(
                      decoration: BoxDecoration(
                        color: periods.indexOf(p).isEven
                            ? Colors.white
                            : const Color(0xFFF8FAFC),
                      ),
                      children: [
                        // Period label cell
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 10),
                          child: Text(
                            "P$p",
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        // Subject cells
                        for (final d in days)
                          _gridCell(cellMap["${d}_$p"]),
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

  Widget _headerCell(String text, {bool isFirst = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: 10, horizontal: isFirst ? 10 : 16),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _gridCell(dynamic item) {
    if (item == null) {
      return const SizedBox(width: 100, height: 42);
    }
    final subject =
        item["subject_abbr"]?.toString() ?? item["slot_type"]?.toString() ?? "-";
    final section = item["section_name"]?.toString() ?? "";
    final color = _colorForSubject(subject);

    return Padding(
      padding: const EdgeInsets.all(5),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subject,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (section.isNotEmpty)
              Text(
                section,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 10,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  // Today's schedule list (items for first available day or all)
  Widget _buildTodayCard() {
    if (schedule.isEmpty) return const SizedBox.shrink();

    // Use first day found as "today" sample
    final int firstDay = (schedule.first["day_index"] as int?) ?? 0;
    final today = schedule
        .where((item) => item["day_index"] == firstDay)
        .toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2E5FBF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Schedule",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A90D9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ],
            ),
          ),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              dayNameFromIndex(firstDay),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...today.map((item) => _todayRow(item)),
          const SizedBox(height: 12),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E5FBF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: const Text(
                  "View Full Schedule",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _todayRow(dynamic item) {
    final subject =
        item["subject"]?.toString() ?? item["subject_abbr"]?.toString() ?? "-";
    final room = item["room"]?.toString() ?? "-";
    final period = item["period"]?.toString() ?? "-";
    final color = _colorForSubject(
        item["subject_abbr"]?.toString() ?? item["slot_type"]?.toString());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
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
                  "Period $period",
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subject,
                  style: const TextStyle(
                    color: Color(0xFF1A2B4A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "[Room $room]",
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget scheduleCard(dynamic item) {
    final subject =
        item["subject_abbr"]?.toString() ?? item["slot_type"]?.toString() ?? "-";
    final color = _colorForSubject(subject);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            color: Color(0x0A000000),
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                subject.length > 3 ? subject.substring(0, 3) : subject,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
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
                  item["subject"]?.toString() ?? subject,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF1A2B4A),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _chip(
                      Icons.calendar_today_outlined,
                      dayNameFromIndex(item["day_index"] ?? -1),
                    ),
                    _chip(Icons.access_time_outlined,
                        "Period ${item["period"] ?? "-"}"),
                    _chip(Icons.group_outlined,
                        item["section_name"]?.toString() ?? "-"),
                    _chip(Icons.meeting_room_outlined,
                        item["room"]?.toString() ?? "-"),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: item["is_fixed"] == true
                  ? const Color(0xFF4A90D9).withOpacity(0.12)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item["is_fixed"] == true ? "Fixed" : "Flex",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: item["is_fixed"] == true
                    ? const Color(0xFF2E5FBF)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    facultyIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E5FBF),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Faculty Timetable",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: const Color(0xFF2E5FBF),
            padding:
            const EdgeInsets.fromLTRB(16, 4, 16, 18),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: facultyIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter Faculty ID",
                      hintStyle:
                      const TextStyle(color: Colors.white60),
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: loading ? null : loadFacultyTimetable,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2E5FBF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    elevation: 0,
                  ),
                  child: loading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                          Color(0xFF2E5FBF)),
                    ),
                  )
                      : const Text(
                    "Load",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // Faculty name badge
          if (facultyName.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFEBF0FB),
              padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.person,
                      color: Color(0xFF2E5FBF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    facultyName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2B4A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E5FBF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${schedule.length} slots",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: loading
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2E5FBF),
              ),
            )
                : schedule.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 64,
                      color: const Color(0xFF94A3B8)
                          .withOpacity(0.5)),
                  const SizedBox(height: 12),
                  const Text(
                    "Enter a Faculty ID to load timetable",
                    style: TextStyle(
                      color: Color(0xFF9AA5B4),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Today's schedule card
                  _buildTodayCard(),
                  const SizedBox(height: 14),
                  // Weekly grid
                  _buildTimetableGrid(),
                  const SizedBox(height: 14),
                  // Detailed cards
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10, left: 2),
                    child: Text(
                      "All Slots",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2B4A),
                      ),
                    ),
                  ),
                  ...schedule
                      .map((item) => Padding(
                    padding: const EdgeInsets.only(
                        bottom: 10),
                    child: scheduleCard(item),
                  ))
                      .toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}