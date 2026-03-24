import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import '../timetable/departmentdropdown.dart';
import '../timetable/timetableapp_theme.dart';

class CreateFacultyMappingScreen extends StatefulWidget {
  final String token;
  const CreateFacultyMappingScreen({super.key, required this.token});

  @override
  State<CreateFacultyMappingScreen> createState() => _CreateFacultyMappingScreenState();
}

class _CreateFacultyMappingScreenState extends State<CreateFacultyMappingScreen> {
  final Dio dio = Dio();

  int? selectedDepartmentId;
  String? selectedFacultyPublicId;
  String? selectedFacultyName;
  final academicYearController = TextEditingController(text: "2025-26");

  int year = 3;
  int semester = 6;
  List subjects = [];
  int? selectedSubjectId;

  int priority = 1;
  int maxHoursPerWeek = 6;
  int maxHoursPerDay = 7;
  bool canHandleLab = true;
  bool isPrimary = true;

  bool loadingSubjects = false;
  bool loading = false;

  Future<void> loadSubjects() async {
    if (selectedDepartmentId == null || academicYearController.text.trim().isEmpty) {
      _snack("Select a department and academic year first");
      return;
    }
    setState(() => loadingSubjects = true);
    try {
      final token = (await TokenService.getUserSession())["token"] ?? widget.token;
      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/subjects",
        queryParameters: {
          "department_id": selectedDepartmentId,
          "year": year,
          "semester": semester,
          "academic_year": academicYearController.text.trim(),
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      if (!mounted) return;
      setState(() {
        subjects = List.from(res.data);
        selectedSubjectId = subjects.isNotEmpty ? int.parse(subjects.first["id"].toString()) : null;
      });
      if (subjects.isEmpty) _snack("No subjects found for this selection");
    } on DioException catch (e) {
      if (!mounted) return;
      _snack(e.response?.data?["detail"]?.toString() ?? "Failed to load subjects");
    } finally {
      if (mounted) setState(() => loadingSubjects = false);
    }
  }

  Future<void> createMapping() async {
    if (selectedFacultyPublicId == null) { _snack("Please select a faculty member"); return; }
    if (selectedSubjectId == null) { _snack("Please load and select a subject"); return; }

    setState(() => loading = true);
    try {
      final token = (await TokenService.getUserSession())["token"] ?? widget.token;
      await dio.post(
        "${ApiService.baseUrl}/timetable/faculty-subject-map",
        data: {
          "faculty_public_id": selectedFacultyPublicId,
          "subject_id": selectedSubjectId,
          "priority": priority,
          "max_hours_per_week": maxHoursPerWeek,
          "max_hours_per_day": maxHoursPerDay,
          "can_handle_lab": canHandleLab,
          "is_primary": isPrimary,
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      if (!mounted) return;
      setState(() {
        selectedFacultyPublicId = null;
        selectedFacultyName = null;
        selectedSubjectId = null;
        subjects = [];
        priority = 1;
        maxHoursPerWeek = 6;
        maxHoursPerDay = 7;
        canHandleLab = true;
        isPrimary = true;
      });
      _snack("Faculty mapping created successfully ✓", success: true);
    } on DioException catch (e) {
      if (!mounted) return;
      _snack(e.response?.data?["detail"]?.toString() ?? "Failed to create mapping");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? TimetableAppTheme.success : null,
      duration: const Duration(seconds: 4),
    ));
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
      appBar: TimetableAppTheme.buildAppBar(context, "Create Faculty Mapping"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TimetableAppTheme.infoBanner(
              "Steps:\n"
                  "1. Select department and faculty from the dropdowns\n"
                  "2. Set academic year, year & semester\n"
                  "3. Tap 'Load Subjects' then select the subject\n"
                  "4. Set workload limits and tap 'Create Mapping'",
            ),
            const SizedBox(height: 16),

            // Faculty selection
            TimetableAppTheme.card(
              child: Column(
                children: [
                  TimetableAppTheme.sectionHeader("Faculty & Department"),
                  DepartmentDropdown(
                    token: widget.token,
                    value: selectedDepartmentId,
                    onChanged: (id, _) => setState(() {
                      selectedDepartmentId = id;
                      selectedFacultyPublicId = null;
                      selectedFacultyName = null;
                      subjects = [];
                      selectedSubjectId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  FacultyDropdown(
                    token: widget.token,
                    departmentId: selectedDepartmentId,
                    value: selectedFacultyPublicId,
                    onChanged: (pid, name) => setState(() {
                      selectedFacultyPublicId = pid;
                      selectedFacultyName = name;
                    }),
                  ),
                  if (selectedFacultyPublicId != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: TimetableAppTheme.accentLight,
                        borderRadius: BorderRadius.circular(TimetableAppTheme.radiusMd),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: TimetableAppTheme.primaryLight, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            "Selected: $selectedFacultyName ($selectedFacultyPublicId)",
                            style: const TextStyle(color: TimetableAppTheme.primaryLight, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Subject filter
            TimetableAppTheme.card(
              child: Column(
                children: [
                  TimetableAppTheme.sectionHeader("Subject Filter"),
                  TextFormField(
                    controller: academicYearController,
                    decoration: TimetableAppTheme.inputDecoration("Academic Year", hint: "2025-26"),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _dropdown<int>(
                        label: "Year",
                        value: year,
                        items: {1: "1st Year", 2: "2nd Year", 3: "3rd Year", 4: "4th Year"},
                        onChanged: (v) { if (v != null) setState(() => year = v); },
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _dropdown<int>(
                        label: "Semester",
                        value: semester,
                        items: {for (int i = 1; i <= 8; i++) i: "Sem $i"},
                        onChanged: (v) { if (v != null) setState(() => semester = v); },
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TimetableAppTheme.primaryButton(
                    text: "Load Subjects",
                    loading: loadingSubjects,
                    onPressed: loadSubjects,
                    icon: Icons.download_outlined,
                  ),
                  if (subjects.isNotEmpty && selectedSubjectId != null) ...[
                    const SizedBox(height: 14),
                    TimetableAppTheme.sectionHeader("Select Subject"),
                    DropdownButtonFormField<int>(
                      value: selectedSubjectId,
                      decoration: TimetableAppTheme.inputDecoration(
                        "Subject",
                        prefixIcon: const Icon(Icons.menu_book_outlined, size: 18),
                      ),
                      isExpanded: true,
                      items: subjects.map<DropdownMenuItem<int>>((s) {
                        return DropdownMenuItem<int>(
                          value: int.parse(s["id"].toString()),
                          child: Text("${s["short_name"]} — ${s["name"]}", overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) { if (v != null) setState(() => selectedSubjectId = v); },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Workload rules
            TimetableAppTheme.card(
              child: Column(
                children: [
                  TimetableAppTheme.sectionHeader("Workload Rules"),
                  _dropdown<int>(
                    label: "Priority",
                    value: priority,
                    items: {1: "1 — Primary teacher", 2: "2 — Backup", 3: "3 — Second backup"},
                    onChanged: (v) { if (v != null) setState(() => priority = v); },
                  ),
                  const SizedBox(height: 12),
                  _dropdown<int>(
                    label: "Max Hours Per Week (this subject)",
                    value: maxHoursPerWeek,
                    items: {3: "3 hrs/week", 4: "4 hrs/week", 5: "5 hrs/week", 6: "6 hrs/week", 8: "8 hrs/week", 10: "10 hrs/week", 15: "15 hrs/week", 20: "20 hrs/week"},
                    onChanged: (v) { if (v != null) setState(() => maxHoursPerWeek = v); },
                  ),
                  const SizedBox(height: 12),
                  _dropdown<int>(
                    label: "Max Hours Per Day",
                    value: maxHoursPerDay,
                    items: {2: "2/day", 3: "3/day", 4: "4/day", 5: "5/day", 6: "6/day", 7: "7/day (max)"},
                    onChanged: (v) { if (v != null) setState(() => maxHoursPerDay = v); },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: TimetableAppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(TimetableAppTheme.radiusMd),
                      border: Border.all(color: TimetableAppTheme.border),
                    ),
                    child: Column(
                      children: [
                        _switchTile(
                          title: "Can handle LAB sessions",
                          subtitle: "Enable if faculty can take lab sessions for this subject",
                          value: canHandleLab,
                          onChanged: (v) => setState(() => canHandleLab = v),
                          isFirst: true,
                        ),
                        const Divider(height: 1, indent: 16),
                        _switchTile(
                          title: "Primary Faculty",
                          subtitle: "Preferred first during timetable generation",
                          value: isPrimary,
                          onChanged: (v) => setState(() => isPrimary = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            TimetableAppTheme.primaryButton(
              text: "Create Mapping",
              loading: loading,
              onPressed: createMapping,
              icon: Icons.link_outlined,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
    bool isFirst = false,
  }) {
    return SwitchListTile(
      value: value,
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: TimetableAppTheme.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: TimetableAppTheme.textHint)),
      onChanged: onChanged,
      activeColor: TimetableAppTheme.primaryLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: isFirst ? const Radius.circular(TimetableAppTheme.radiusMd) : Radius.zero,
          topRight: isFirst ? const Radius.circular(TimetableAppTheme.radiusMd) : Radius.zero,
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required Map<T, String> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: TimetableAppTheme.inputDecoration(label),
      items: items.entries.map((e) => DropdownMenuItem<T>(value: e.key, child: Text(e.value))).toList(),
      onChanged: onChanged,
    );
  }
}