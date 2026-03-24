import 'package:faculty_app/screens/operator/timetable/timetableapp_theme.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import 'departmentdropdown.dart';

class ViewSectionTimetableScreen extends StatefulWidget {
  final String token;
  const ViewSectionTimetableScreen({super.key, required this.token});

  @override
  State<ViewSectionTimetableScreen> createState() => _ViewSectionTimetableScreenState();
}

class _ViewSectionTimetableScreenState extends State<ViewSectionTimetableScreen> {
  final Dio dio = Dio();

  int? selectedDepartmentId;
  final academicYearController = TextEditingController(text: "2025-26");
  int? selectedSectionId;
  String? selectedSectionName;

  List schedule = [];
  List periodLabels = [];
  String sectionName = "";
  String sectionCategory = "";
  List<int> workingDayIndexes = [0, 1, 2, 3, 4, 5];
  bool loading = false;

  final List<String> allDayNames = const ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

  Future<void> loadSectionTimetable() async {
    if (selectedSectionId == null) { _snack("Please select a section"); return; }

    setState(() => loading = true);
    try {
      final token = (await TokenService.getUserSession())["token"] ?? widget.token;
      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/section/$selectedSectionId",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      final data = Map<String, dynamic>.from(res.data);
      final meta = data["meta"] as Map<String, dynamic>? ?? {};

      List<int> parsedDays = [0, 1, 2, 3, 4, 5];
      final wd = meta["working_days"];
      if (wd != null) {
        final parsed = wd.toString().split(",")
            .map((e) => int.tryParse(e.trim()))
            .where((e) => e != null)
            .cast<int>()
            .toList();
        if (parsed.isNotEmpty) parsedDays = parsed;
      }

      setState(() {
        sectionName = data["section_name"]?.toString() ?? selectedSectionName ?? "";
        sectionCategory = data["category"]?.toString() ?? "";
        schedule = data["schedule"] is List ? data["schedule"] : [];
        periodLabels = meta["period_labels"] is List ? List.from(meta["period_labels"]) : [];
        workingDayIndexes = parsedDays;
      });
    } on DioException catch (e) {
      schedule = [];
      periodLabels = [];
      if (mounted) _snack(e.response?.data?["detail"]?.toString() ?? "Failed to load timetable");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Map<int, Map<int, dynamic>> buildGrid() {
    final Map<int, Map<int, dynamic>> grid = {};
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
    if (slot == null || (slot is Map && slot.isEmpty)) return Colors.white;
    final type = (slot["slot_type"] ?? "").toString().toUpperCase();
    switch (type) {
      case "LUNCH": return const Color(0xFFFFF3CD);
      case "BLOCKED": return const Color(0xFFF1F3F5);
      case "THUB": return const Color(0xFFFFE082);
      case "LAB": return const Color(0xFFE1F5FE);
      case "FIP": return const Color(0xFFE8F5E9);
      case "PSA": return const Color(0xFFFCE4EC);
      case "ACTIVITY": return const Color(0xFFF3E5F5);
      default: return Colors.white;
    }
  }

  Widget timetableCell(dynamic slot) {
    if (slot == null || (slot is Map && slot.isEmpty)) return const SizedBox.shrink();
    final type = slot["slot_type"]?.toString() ?? "";
    if (type == "LUNCH") {
      return Center(child: Text(slot["subject"] ?? "LUNCH",
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF795548))));
    }
    if (type == "BLOCKED") {
      return const Center(child: Text("—", style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 18)));
    }
    if (type == "THUB") {
      return const Center(child: Text("T-Hub", textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFFE65100))));
    }
    final subject = slot["subject_abbr"]?.toString() ?? type;
    final faculty = slot["faculty_name"]?.toString() ?? "";
    final room = slot["room"]?.toString() ?? "";
    final isLabCont = slot["is_lab_continuation"] == true;
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLabCont) const Text("↑ LAB", style: TextStyle(fontSize: 9, color: Color(0xFF0277BD))),
          Text(subject, textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                  color: type == "FIP" ? const Color(0xFF2E7D32) : type == "PSA" ? const Color(0xFFC2185B) : TimetableAppTheme.primary)),
          if (faculty.isNotEmpty && !isLabCont) ...[
            const SizedBox(height: 3),
            Text(faculty, textAlign: TextAlign.center, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: Color(0xFF546E7A))),
          ],
          if (room.isNotEmpty && !isLabCont) ...[
            const SizedBox(height: 1),
            Text(room, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, color: Color(0xFF90A4AE))),
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
          width: 13, height: 13,
          decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFFDDDDDD)),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: TimetableAppTheme.textSecondary)),
        const SizedBox(width: 10),
      ],
    );
  }

  @override
  void dispose() {
    academicYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = buildGrid();

    return Scaffold(
      backgroundColor: TimetableAppTheme.background,
      appBar: TimetableAppTheme.buildAppBar(context, "Section Timetable"),
      body: Column(
        children: [
          // Search panel
          Container(
            decoration: const BoxDecoration(gradient: TimetableAppTheme.primaryGradient),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              children: [
                DepartmentDropdown(
                  token: widget.token,
                  value: selectedDepartmentId,
                  label: "Department",
                  onChanged: (id, _) => setState(() {
                    selectedDepartmentId = id;
                    selectedSectionId = null;
                    selectedSectionName = null;
                    schedule = [];
                  }),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: academicYearController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Academic Year",
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.15),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(TimetableAppTheme.radiusMd),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SectionDropdown(
                  token: widget.token,
                  departmentId: selectedDepartmentId,
                  academicYear: academicYearController.text.trim(),
                  value: selectedSectionId,
                  label: "Section",
                  onChanged: (id, name) => setState(() {
                    selectedSectionId = id;
                    selectedSectionName = name;
                    schedule = [];
                  }),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (loading || selectedSectionId == null) ? null : loadSectionTimetable,
                    icon: loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: TimetableAppTheme.primary))
                        : const Icon(Icons.grid_view_rounded, size: 18),
                    label: const Text("Load Timetable"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: TimetableAppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TimetableAppTheme.radiusMd)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Section badge
          if (sectionName.isNotEmpty)
            Container(
              color: TimetableAppTheme.accentLight.withOpacity(0.6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.class_outlined, color: TimetableAppTheme.primaryLight, size: 18),
                  const SizedBox(width: 8),
                  Text(sectionName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: TimetableAppTheme.textPrimary)),
                  const SizedBox(width: 8),
                  if (sectionCategory.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: sectionCategory == "THUB" ? Colors.orange.shade100 : TimetableAppTheme.accentLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(sectionCategory,
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: sectionCategory == "THUB" ? Colors.orange.shade900 : TimetableAppTheme.primary,
                          )),
                    ),
                ],
              ),
            ),

          // Legend
          if (schedule.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                _legendItem(const Color(0xFFFFF3CD), "Lunch"),
                _legendItem(const Color(0xFFFFE082), "T-Hub"),
                _legendItem(const Color(0xFFE1F5FE), "Lab"),
                _legendItem(const Color(0xFFE8F5E9), "FIP"),
                _legendItem(const Color(0xFFFCE4EC), "PSA"),
                _legendItem(Colors.white, "Theory"),
              ]),
            ),

          // Grid
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : schedule.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view_rounded, size: 60, color: TimetableAppTheme.textHint.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  const Text("Select a section and load timetable", style: TextStyle(color: TimetableAppTheme.textHint)),
                ],
              ),
            )
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(TimetableAppTheme.primary),
                  headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                  dataRowMinHeight: 80,
                  dataRowMaxHeight: 100,
                  horizontalMargin: 12,
                  columnSpacing: 4,
                  columns: [
                    const DataColumn(label: Text("Day")),
                    for (int i = 0; i < 8; i++)
                      DataColumn(
                        label: SizedBox(
                          width: 115,
                          child: Text(
                            i < periodLabels.length ? periodLabels[i].toString() : "P${i + 1}",
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                  rows: workingDayIndexes.map((day) {
                    return DataRow(cells: [
                      DataCell(SizedBox(
                        width: 36,
                        child: Text(
                          day < allDayNames.length ? allDayNames[day] : "D$day",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: TimetableAppTheme.textPrimary),
                        ),
                      )),
                      for (int period = 0; period < 8; period++)
                        DataCell(Container(
                          width: 115, height: 90,
                          decoration: BoxDecoration(
                            color: cellColor(grid[day]?[period]),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
                          ),
                          child: timetableCell(grid[day]?[period]),
                        )),
                    ]);
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