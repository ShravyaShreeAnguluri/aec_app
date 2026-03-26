import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import '../timetable/departmentdropdown.dart';
import '../timetable/timetableapp_theme.dart';

class ViewSectionsScreen extends StatefulWidget {
  final String token;
  const ViewSectionsScreen({super.key, required this.token});

  @override
  State<ViewSectionsScreen> createState() => _ViewSectionsScreenState();
}

class _ViewSectionsScreenState extends State<ViewSectionsScreen> {
  final Dio dio = Dio();

  int? selectedDepartmentId;
  int? selectedYear;
  final academicYearController = TextEditingController(text: "2025-26");

  List sections = [];
  bool loading = false;

  final List<String> dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

  // Year options — adjust if your college uses different years
  final List<int> yearOptions = [1, 2, 3, 4];

  Future<void> loadSections() async {
    if (selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a department")),
      );
      return;
    }
    if (selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a year")),
      );
      return;
    }
    if (academicYearController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the academic year")),
      );
      return;
    }
    setState(() => loading = true);
    try {
      final token = (await TokenService.getUserSession())["token"] ?? widget.token;
      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/sections",
        queryParameters: {
          "department_id": selectedDepartmentId,
          "academic_year": academicYearController.text.trim(),
          "year": selectedYear,           // NEW — filter by year on backend
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      setState(() => sections = res.data is List ? res.data : []);
    } on DioException catch (e) {
      setState(() => sections = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.response?.data?["detail"]?.toString() ?? "Failed to load sections"),
        ));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<int> parseCsv(dynamic value) {
    if (value == null) return [];
    return value
        .toString()
        .split(",")
        .map((e) => int.tryParse(e.trim()))
        .where((e) => e != null)
        .cast<int>()
        .toList();
  }

  String formatWorkingDays(dynamic value) {
    final days = parseCsv(value);
    if (days.isEmpty) return "-";
    final labels =
    days.where((d) => d >= 0 && d < dayNames.length).map((d) => dayNames[d]).toList();
    if (labels.length == 6) return "Mon–Sat";
    if (labels.length == 5) return "Mon–Fri";
    return labels.join(", ");
  }

  String _yearLabel(int y) {
    const suffix = ['st', 'nd', 'rd', 'th'];
    final s = y <= 4 ? suffix[y - 1] : 'th';
    return "$y$s Year";
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
      appBar: TimetableAppTheme.buildAppBar(context, "View Sections"),
      body: Column(
        children: [
          // ── Filter panel ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: TimetableAppTheme.primaryGradient),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              children: [
                // Department
                DepartmentDropdown(
                  token: widget.token,
                  value: selectedDepartmentId,
                  label: "Department",
                  onChanged: (id, _) {
                    setState(() {
                      selectedDepartmentId = id;
                      selectedYear = null;
                      sections = [];
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Academic year + Year row
                Row(
                  children: [
                    // Academic year text field
                    Expanded(
                      child: TextFormField(
                        controller: academicYearController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Academic Year",
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: "2025-26",
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.15),
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(TimetableAppTheme.radiusMd),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Year dropdown
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedYear,
                        dropdownColor: TimetableAppTheme.primary,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        iconEnabledColor: Colors.white70,
                        decoration: InputDecoration(
                          labelText: "Year",
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.15),
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(TimetableAppTheme.radiusMd),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        hint: const Text("Year",
                            style: TextStyle(color: Colors.white60, fontSize: 13)),
                        items: yearOptions
                            .map((y) => DropdownMenuItem(
                          value: y,
                          child: Text(_yearLabel(y),
                              style: const TextStyle(color: Colors.white)),
                        ))
                            .toList(),
                        onChanged: selectedDepartmentId == null
                            ? null
                            : (val) {
                          setState(() {
                            selectedYear = val;
                            sections = [];
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Load button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : loadSections,
                    icon: loading
                        ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: TimetableAppTheme.primary))
                        : const Icon(Icons.search_rounded, size: 18),
                    label: const Text("Load Sections",
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: TimetableAppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(TimetableAppTheme.radiusMd)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Count badge
          if (sections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${sections.length} section${sections.length == 1 ? '' : 's'} found"
                      "${selectedYear != null ? ' · ${_yearLabel(selectedYear!)}' : ''}",
                  style: const TextStyle(
                      fontSize: 12, color: TimetableAppTheme.textHint),
                ),
              ),
            ),

          // Content area
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : sections.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.class_outlined,
                      size: 60,
                      color: TimetableAppTheme.textHint.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  Text(
                    selectedDepartmentId == null
                        ? "Select a department"
                        : selectedYear == null
                        ? "Select a year"
                        : "No sections found",
                    style: const TextStyle(
                        color: TimetableAppTheme.textHint),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sections.length,
              itemBuilder: (_, i) => _SectionCard(
                section: sections[i],
                dayNames: dayNames,
                formatWorkingDays: formatWorkingDays,
                parseCsv: parseCsv,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final dynamic section;
  final List<String> dayNames;
  final String Function(dynamic) formatWorkingDays;
  final List<int> Function(dynamic) parseCsv;

  const _SectionCard({
    required this.section,
    required this.dayNames,
    required this.formatWorkingDays,
    required this.parseCsv,
  });

  String _yearLabel(int y) {
    const suffix = ['st', 'nd', 'rd', 'th'];
    final s = y <= 4 ? suffix[y - 1] : 'th';
    return "$y$s Year";
  }

  @override
  Widget build(BuildContext context) {
    final s = section;
    final category = s["category"]?.toString() ?? "";
    final isThub = category == "THUB";
    final year = s["year"] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TimetableAppTheme.radiusLg),
        boxShadow: TimetableAppTheme.cardShadow,
        border: Border.all(color: TimetableAppTheme.border.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isThub
                  ? Colors.orange.shade50
                  : TimetableAppTheme.accentLight.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(TimetableAppTheme.radiusLg)),
              border: Border(
                bottom: BorderSide(
                    color: isThub
                        ? Colors.orange.shade200
                        : TimetableAppTheme.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: isThub
                        ? const LinearGradient(
                        colors: [Color(0xFFE65100), Color(0xFFFF8F00)])
                        : TimetableAppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.class_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s["name"]?.toString() ?? "-",
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: TimetableAppTheme.textPrimary),
                      ),
                      if (year != null)
                        Text(
                          _yearLabel(year),
                          style: const TextStyle(
                              fontSize: 11,
                              color: TimetableAppTheme.textHint,
                              fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isThub
                        ? Colors.orange.shade100
                        : TimetableAppTheme.accentLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isThub
                          ? Colors.orange.shade900
                          : TimetableAppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              children: [
                TimetableAppTheme.infoChip("Year", s["year"]),
                TimetableAppTheme.infoChip("Sem", s["semester"]),
                TimetableAppTheme.infoChip("Room", s["classroom"]),
                TimetableAppTheme.infoChip(
                    "Days", formatWorkingDays(s["working_days"])),
                TimetableAppTheme.infoChip(
                    "Lunch after",
                    "P${(s["lunch_after_period"] ?? 3) + 1}"),
                TimetableAppTheme.infoChip(
                    "Lunch", "${s["lunch_duration_minutes"] ?? 60} min"),
                TimetableAppTheme.infoChip(
                    "Slot", "${s["slot_duration_minutes"] ?? 50} min"),
                TimetableAppTheme.infoChip("Start", s["start_time"]),
                if (isThub && s["thub_reserved_periods"] != null)
                  TimetableAppTheme.infoChip(
                    "T-Hub slots",
                    parseCsv(s["thub_reserved_periods"])
                        .map((p) => "P${p + 1}")
                        .join(", "),
                    bg: Colors.orange.shade50,
                    fg: Colors.orange.shade900,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}