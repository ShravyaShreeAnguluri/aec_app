import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';

class ViewSectionTimetableScreen extends StatefulWidget {
  final String token;

  const ViewSectionTimetableScreen({super.key, required this.token});

  @override
  State<ViewSectionTimetableScreen> createState() =>
      _ViewSectionTimetableScreenState();
}

class _ViewSectionTimetableScreenState
    extends State<ViewSectionTimetableScreen> {
  final Dio dio = Dio();

  final sectionIdController = TextEditingController();

  List schedule = [];
  List periodLabels = [];
  String sectionName = "";
  String sectionCategory = "";
  // FIX: store actual working day indexes from the API meta
  List<int> workingDayIndexes = [0, 1, 2, 3, 4, 5]; // default Mon–Sat
  bool loading = false;

  final List<String> allDayNames = const [
    "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
  ];

  Future<void> loadSectionTimetable() async {
    if (sectionIdController.text.trim().isEmpty) return;

    try {
      setState(() => loading = true);

      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;

      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/section/${sectionIdController.text.trim()}",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      final data = Map<String, dynamic>.from(res.data);
      final meta = data["meta"] as Map<String, dynamic>? ?? {};

      // FIX: parse working_days from section meta to show only actual days
      List<int> parsedDays = [0, 1, 2, 3, 4, 5];
      final wd = meta["working_days"];
      if (wd != null) {
        final parsed = wd
            .toString()
            .split(",")
            .map((e) => int.tryParse(e.trim()))
            .where((e) => e != null)
            .cast<int>()
            .toList();
        if (parsed.isNotEmpty) parsedDays = parsed;
      }

      setState(() {
        sectionName = data["section_name"]?.toString() ?? "";
        sectionCategory = data["category"]?.toString() ?? "";
        schedule = data["schedule"] is List ? data["schedule"] : [];
        periodLabels = meta["period_labels"] is List
            ? List.from(meta["period_labels"])
            : [];
        workingDayIndexes = parsedDays;
      });
    } on DioException catch (e) {
      schedule = [];
      periodLabels = [];
      if (mounted) {
        final msg = e.response?.data?["detail"]?.toString() ??
            "Failed to load section timetable";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      schedule = [];
      periodLabels = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Map<int, Map<int, dynamic>> buildGrid(List<dynamic> schedule) {
    final Map<int, Map<int, dynamic>> grid = {};

    // FIX: only build grid for actual working days, not hardcoded 0–5
    for (final day in workingDayIndexes) {
      grid[day] = {};
      for (int period = 0; period < 8; period++) {
        grid[day]![period] = {};
      }
    }

    for (final slot in schedule) {
      final int? day = slot["day_index"] as int?;
      final int? period = slot["period"] as int?;
      if (day != null && period != null && grid.containsKey(day)) {
        grid[day]![period] = slot;
      }
    }

    return grid;
  }

  Color cellColor(dynamic slot) {
    if (slot == null || (slot is Map && slot.isEmpty)) {
      return Colors.white;
    }

    final type = (slot["slot_type"] ?? "").toString().toUpperCase();

    switch (type) {
      case "LUNCH":
        return const Color(0xFFFFF3CD);
      case "BLOCKED":
        return const Color(0xFFF1F3F5);
      case "THUB":
        return const Color(0xFFFFE082); // yellow for T-Hub
      case "LAB":
        return const Color(0xFFE1F5FE); // light blue for labs
      case "FIP":
        return const Color(0xFFE8F5E9); // light green for FIP
      case "PSA":
        return const Color(0xFFFCE4EC); // light pink for PSA
      case "ACTIVITY":
        return const Color(0xFFF3E5F5);
      default:
        return Colors.white;
    }
  }

  Widget timetableCell(dynamic slot) {
    if (slot == null || (slot is Map && slot.isEmpty)) {
      return const SizedBox.shrink();
    }

    final type = slot["slot_type"]?.toString() ?? "";
    final subject = slot["subject_abbr"]?.toString() ?? type;
    final faculty = slot["faculty_name"]?.toString() ?? "";
    final room = slot["room"]?.toString() ?? "";
    final isLabContinuation = slot["is_lab_continuation"] == true;

    // Special display for structural slots
    if (type == "LUNCH") {
      return Center(
        child: Text(
          slot["subject"] ?? "LUNCH",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: Color(0xFF795548),
          ),
        ),
      );
    }

    if (type == "BLOCKED") {
      return const Center(
        child: Text(
          "—",
          style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 18),
        ),
      );
    }

    if (type == "THUB") {
      return const Center(
        child: Text(
          "T-Hub",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: Color(0xFFE65100),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLabContinuation)
            const Text(
              "↑ LAB",
              style: TextStyle(
                  fontSize: 9, color: Color(0xFF0277BD)),
            ),
          Text(
            subject,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: type == "FIP"
                  ? const Color(0xFF2E7D32)
                  : type == "PSA"
                  ? const Color(0xFFC2185B)
                  : const Color(0xFF1A237E),
            ),
          ),
          if (faculty.isNotEmpty && !isLabContinuation) ...[
            const SizedBox(height: 3),
            Text(
              faculty,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 9, color: Color(0xFF546E7A)),
            ),
          ],
          if (room.isNotEmpty && !isLabContinuation) ...[
            const SizedBox(height: 1),
            Text(
              room,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 9, color: Color(0xFF90A4AE)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFFDDDDDD)),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 10),
      ],
    );
  }

  @override
  void dispose() {
    sectionIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = buildGrid(schedule);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(title: const Text("Section Timetable")),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: sectionIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Section ID",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => loadSectionTimetable(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: loading ? null : loadSectionTimetable,
                  child: loading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text("Load"),
                ),
              ],
            ),
          ),

          if (sectionName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    sectionName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  if (sectionCategory.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: sectionCategory == "THUB"
                            ? Colors.orange.shade100
                            : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        sectionCategory,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: sectionCategory == "THUB"
                              ? Colors.orange.shade900
                              : Colors.blue.shade900,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Legend
          if (schedule.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _legendItem(const Color(0xFFFFF3CD), "Lunch"),
                  _legendItem(const Color(0xFFFFE082), "T-Hub"),
                  _legendItem(const Color(0xFFE1F5FE), "Lab"),
                  _legendItem(const Color(0xFFE8F5E9), "FIP"),
                  _legendItem(const Color(0xFFFCE4EC), "PSA"),
                  _legendItem(Colors.white, "Theory"),
                ],
              ),
            ),

          // Timetable grid
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : schedule.isEmpty
                ? const Center(child: Text("No timetable loaded"))
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFF1A237E),
                  ),
                  headingTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  dataRowMinHeight: 80,
                  dataRowMaxHeight: 100,
                  horizontalMargin: 12,
                  columnSpacing: 4,
                  columns: [
                    const DataColumn(
                      label: Text("Day"),
                    ),
                    for (int i = 0; i < 8; i++)
                      DataColumn(
                        label: SizedBox(
                          width: 115,
                          child: Text(
                            i < periodLabels.length
                                ? periodLabels[i].toString()
                                : "P${i + 1}",
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                  // FIX: only render rows for actual working days
                  rows: workingDayIndexes.map((day) {
                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 36,
                            child: Text(
                              day < allDayNames.length
                                  ? allDayNames[day]
                                  : "D$day",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        for (int period = 0; period < 8; period++)
                          DataCell(
                            Container(
                              width: 115,
                              height: 90,
                              decoration: BoxDecoration(
                                color: cellColor(
                                    grid[day]?[period]),
                                borderRadius:
                                BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                  width: 0.5,
                                ),
                              ),
                              child: timetableCell(
                                  grid[day]?[period]),
                            ),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}