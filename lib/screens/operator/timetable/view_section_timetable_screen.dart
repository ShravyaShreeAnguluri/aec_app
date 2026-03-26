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
  State<ViewSectionTimetableScreen> createState() =>
      _ViewSectionTimetableScreenState();
}

class _ViewSectionTimetableScreenState
    extends State<ViewSectionTimetableScreen> {
  final Dio dio = Dio();

  int? selectedDepartmentId;
  int? selectedYear;
  final academicYearController = TextEditingController(text: "2025-26");

  List _sections = [];
  bool _sectionsLoading = false;

  int? selectedSectionId;
  String? selectedSectionName;

  List schedule = [];
  List periodLabels = [];
  String sectionName = "";
  String sectionCategory = "";
  int? sectionYear;
  List<int> workingDayIndexes = [0, 1, 2, 3, 4, 5];
  bool loading = false;

  final List<String> allDayNames = const [
    "Mon",
    "Tue",
    "Wed",
    "Thu",
    "Fri",
    "Sat"
  ];
  final List<int> yearOptions = [1, 2, 3, 4];

  String _yearLabel(int y) {
    const suffix = ['st', 'nd', 'rd', 'th'];
    final s = y <= 4 ? suffix[y - 1] : 'th';
    return "$y${s} Year";
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadSections() async {
    if (selectedDepartmentId == null || selectedYear == null) return;

    setState(() {
      _sectionsLoading = true;
      _sections = [];
      selectedSectionId = null;
      selectedSectionName = null;
      schedule = [];
      sectionName = "";
      sectionCategory = "";
    });

    try {
      final token = (await TokenService.getUserSession())["token"] ??
          widget.token;
      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/sections",
        queryParameters: {
          "department_id": selectedDepartmentId,
          "academic_year": academicYearController.text.trim(),
          "year": selectedYear,
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      setState(() => _sections = res.data is List ? res.data : []);
    } on DioException catch (e) {
      if (mounted) {
        _snack(e.response?.data?["detail"]?.toString() ??
            "Failed to load sections");
      }
    } finally {
      if (mounted) setState(() => _sectionsLoading = false);
    }
  }

  Future<void> loadSectionTimetable() async {
    if (selectedSectionId == null) {
      _snack("Please select a section");
      return;
    }
    setState(() => loading = true);
    try {
      final token = (await TokenService.getUserSession())["token"] ??
          widget.token;
      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/section/$selectedSectionId",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      final data = Map<String, dynamic>.from(res.data);
      final meta = data["meta"] as Map<String, dynamic>? ?? {};

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
        sectionName = data["section_name"]?.toString() ?? selectedSectionName ?? "";
        sectionCategory = data["category"]?.toString() ?? "";
        sectionYear = data["year"] as int?;
        schedule = data["schedule"] is List ? data["schedule"] : [];
        periodLabels =
        meta["period_labels"] is List ? List.from(meta["period_labels"]) : [];
        workingDayIndexes = parsedDays;
      });
    } on DioException catch (e) {
      setState(() {
        schedule = [];
        periodLabels = [];
      });
      if (mounted) {
        _snack(e.response?.data?["detail"]?.toString() ??
            "Failed to load timetable");
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
      case "LUNCH":
        return const Color(0xFFFFF3CD);
      case "BLOCKED":
        return const Color(0xFFF1F3F5);
      case "THUB":
        return const Color(0xFFFFE082);
      case "LAB":
        return const Color(0xFFE1F5FE);
      case "FIP":
        return const Color(0xFFE8F5E9);
      case "PSA":
        return const Color(0xFFFCE4EC);
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
    if (type == "LUNCH") {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            slot["subject"] ?? "LUNCH",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: Color(0xFF795548),
            ),
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
        child: Padding(
          padding: EdgeInsets.all(6),
          child: Text(
            "T-Hub",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: Color(0xFFE65100),
            ),
          ),
        ),
      );
    }
    final subject = slot["subject_abbr"]?.toString() ?? type;
    final faculty = slot["faculty_name"]?.toString() ?? "";
    final room = slot["room"]?.toString() ?? "";
    final isLabCont = slot["is_lab_continuation"] == true;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLabCont)
            const Text(
              "↑ LAB",
              style: TextStyle(fontSize: 9, color: Color(0xFF0277BD)),
            ),
          Text(
            subject,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: type == "FIP"
                  ? const Color(0xFF2E7D32)
                  : type == "PSA"
                  ? const Color(0xFFC2185B)
                  : TimetableAppTheme.primary,
            ),
          ),
          if (faculty.isNotEmpty && !isLabCont) ...[
            const SizedBox(height: 3),
            Text(
              faculty,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: Color(0xFF546E7A)),
            ),
          ],
          if (room.isNotEmpty && !isLabCont) ...[
            const SizedBox(height: 2),
            Text(
              room,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: Color(0xFF90A4AE)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendPill(Color color, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TimetableAppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFFDDDDDD)),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: TimetableAppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: TimetableAppTheme.primary.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.table_chart_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Section Timetable",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sectionName.isNotEmpty
                          ? "Weekly schedule for $sectionName"
                          : "Weekly plan for selected section",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _heroStat(
                  Icons.apartment_rounded,
                  selectedSectionName ?? "-",
                  "Section",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroStat(
                  Icons.school_outlined,
                  selectedYear != null ? _yearLabel(selectedYear!) : "-",
                  "Year",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroStat(
                  Icons.grid_on_rounded,
                  "${schedule.length}",
                  "Slots",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: TimetableAppTheme.primary, size: 18),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: TimetableAppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: TimetableAppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return TimetableAppTheme.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.filter_alt_outlined,
                  color: TimetableAppTheme.primaryLight, size: 18),
              SizedBox(width: 8),
              Text(
                "Filter Section",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: TimetableAppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DepartmentDropdown(
            token: widget.token,
            value: selectedDepartmentId,
            label: "Department",
            onChanged: (id, _) {
              setState(() {
                selectedDepartmentId = id;
                selectedYear = null;
                _sections = [];
                selectedSectionId = null;
                selectedSectionName = null;
                schedule = [];
                sectionName = "";
                sectionCategory = "";
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: academicYearController,
                  decoration: InputDecoration(
                    labelText: "Academic Year",
                    hintText: "2025-26",
                    filled: true,
                    fillColor: TimetableAppTheme.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(TimetableAppTheme.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) {
                    if (selectedDepartmentId != null && selectedYear != null) {
                      _loadSections();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedYear,
                  decoration: InputDecoration(
                    labelText: "Year",
                    filled: true,
                    fillColor: TimetableAppTheme.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(TimetableAppTheme.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: yearOptions
                      .map(
                        (y) => DropdownMenuItem<int>(
                      value: y,
                      child: Text(_yearLabel(y)),
                    ),
                  )
                      .toList(),
                  onChanged: selectedDepartmentId == null
                      ? null
                      : (val) {
                    setState(() {
                      selectedYear = val;
                      _sections = [];
                      selectedSectionId = null;
                      selectedSectionName = null;
                      schedule = [];
                      sectionName = "";
                      sectionCategory = "";
                    });
                    _loadSections();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (selectedDepartmentId != null && selectedYear != null) ...[
            _sectionsLoading
                ? Container(
              height: 52,
              decoration: BoxDecoration(
                color: TimetableAppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(
                    TimetableAppTheme.radiusMd),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text("Loading sections..."),
                ],
              ),
            )
                : _sections.isEmpty
                ? Container(
              height: 52,
              decoration: BoxDecoration(
                color: TimetableAppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(
                    TimetableAppTheme.radiusMd),
                border: Border.all(color: TimetableAppTheme.border),
              ),
              child: const Center(
                child: Text(
                  "No sections found for selected year",
                  style: TextStyle(
                    fontSize: 12,
                    color: TimetableAppTheme.textSecondary,
                  ),
                ),
              ),
            )
                : DropdownButtonFormField<int>(
              value: selectedSectionId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: "Section",
                filled: true,
                fillColor: TimetableAppTheme.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                      TimetableAppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _sections.map<DropdownMenuItem<int>>((sec) {
                final id = sec["id"] as int;
                final name = sec["name"]?.toString() ?? "?";
                final cat = sec["category"]?.toString() ?? "";
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(
                    cat.isNotEmpty ? "$name [$cat]" : name,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                final sec = _sections.firstWhere(
                      (s) => s["id"] == val,
                  orElse: () => {},
                );
                setState(() {
                  selectedSectionId = val;
                  selectedSectionName = sec["name"]?.toString();
                  schedule = [];
                  sectionName = "";
                  sectionCategory = "";
                });
              },
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (loading || selectedSectionId == null)
                  ? null
                  : loadSectionTimetable,
              icon: loading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.grid_view_rounded, size: 18),
              label: Text(loading ? "Loading..." : "Load Timetable"),
              style: ElevatedButton.styleFrom(
                backgroundColor: TimetableAppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                TimetableAppTheme.primary.withOpacity(0.45),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(TimetableAppTheme.radiusMd),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionInfoCard() {
    if (sectionName.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: TimetableAppTheme.accentLight.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: TimetableAppTheme.primary.withOpacity(0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.class_outlined,
              color: TimetableAppTheme.primaryLight, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sectionYear != null
                      ? "$sectionName · ${_yearLabel(sectionYear!)}"
                      : sectionName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: TimetableAppTheme.textPrimary,
                  ),
                ),
                if (schedule.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    "${schedule.length} timetable slots loaded",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TimetableAppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (sectionCategory.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: sectionCategory.toUpperCase() == "THUB"
                    ? Colors.orange.shade100
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                sectionCategory,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: sectionCategory.toUpperCase() == "THUB"
                      ? Colors.orange.shade900
                      : TimetableAppTheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    if (schedule.isEmpty) return const SizedBox.shrink();
    return Wrap(
      children: [
        _legendPill(const Color(0xFFFFF3CD), "Lunch"),
        _legendPill(const Color(0xFFFFE082), "T-Hub"),
        _legendPill(const Color(0xFFE1F5FE), "Lab"),
        _legendPill(const Color(0xFFE8F5E9), "FIP"),
        _legendPill(const Color(0xFFFCE4EC), "PSA"),
        _legendPill(Colors.white, "Theory"),
      ],
    );
  }

  Widget _buildEmptyState() {
    final text = selectedDepartmentId == null
        ? "Select a department to begin"
        : selectedYear == null
        ? "Select a year"
        : selectedSectionId == null
        ? "Select a section"
        : "Tap 'Load Timetable' to view";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        children: [
          Icon(
            Icons.grid_view_rounded,
            size: 62,
            color: TimetableAppTheme.textHint.withOpacity(0.40),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: TimetableAppTheme.textHint,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard() {
    final grid = buildGrid();
    return TimetableAppTheme.card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor:
            WidgetStateProperty.all(TimetableAppTheme.primary),
            headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
            dataRowMinHeight: 88,
            dataRowMaxHeight: 112,
            horizontalMargin: 10,
            columnSpacing: 4,
            columns: [
              const DataColumn(label: Text("Day")),
              for (int i = 0; i < 8; i++)
                DataColumn(
                  label: SizedBox(
                    width: 132,
                    child: Text(
                      i < periodLabels.length
                          ? periodLabels[i].toString()
                          : "P${i + 1}",
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
            ],
            rows: workingDayIndexes.map((day) {
              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 44,
                      child: Text(
                        day < allDayNames.length ? allDayNames[day] : "D$day",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: TimetableAppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  for (int period = 0; period < 8; period++)
                    DataCell(
                      Container(
                        width: 132,
                        constraints: const BoxConstraints(minHeight: 94),
                        decoration: BoxDecoration(
                          color: cellColor(grid[day]?[period]),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFE0E0E0),
                            width: 0.6,
                          ),
                        ),
                        child: Center(
                          child: timetableCell(grid[day]?[period]),
                        ),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    academicYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TimetableAppTheme.background,
      appBar: TimetableAppTheme.buildAppBar(context, "Section Timetable"),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(),
              const SizedBox(height: 14),
              _buildFilterCard(),
              const SizedBox(height: 14),
              _buildSectionInfoCard(),
              if (sectionName.isNotEmpty)
                const SizedBox(height: 14),
              _buildLegend(),
              if (schedule.isNotEmpty)
                const SizedBox(height: 6),
              if (schedule.isEmpty) _buildEmptyState() else _buildTableCard(),
            ],
          ),
        ),
      ),
    );
  }
}
