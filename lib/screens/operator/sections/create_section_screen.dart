import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import '../timetable/departmentdropdown.dart';
import '../timetable/timetableapp_theme.dart';

class CreateSectionScreen extends StatefulWidget {
  final String token;
  const CreateSectionScreen({super.key, required this.token});

  @override
  State<CreateSectionScreen> createState() => _CreateSectionScreenState();
}

class _CreateSectionScreenState extends State<CreateSectionScreen> {
  final Dio dio = Dio();

  int? selectedDepartmentId;
  final sectionNameController = TextEditingController();
  final academicYearController = TextEditingController(text: "2025-26");
  final classroomController = TextEditingController();
  final totalPeriodsController = TextEditingController(text: "8");
  final startTimeController = TextEditingController(text: "09:30");

  int year = 3;
  int semester = 6;
  int slotDurationMinutes = 50;
  int lunchDurationMinutes = 60;
  int lunchSlot = 3;
  String category = "NON_THUB";
  bool loading = false;

  final List<String> dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  List<bool> selectedDays = [true, true, true, true, true, false];
  List<bool> selectedThubSlots = List.generate(8, (_) => false);

  String getWorkingDays() {
    final days = <int>[];
    for (int i = 0; i < selectedDays.length; i++) {
      if (selectedDays[i]) days.add(i);
    }
    return days.join(",");
  }

  String? getThubSlots() {
    final slots = <int>[];
    for (int i = 0; i < selectedThubSlots.length; i++) {
      if (selectedThubSlots[i]) slots.add(i);
    }
    return slots.isEmpty ? null : slots.join(",");
  }

  Future<void> createSection() async {
    if (selectedDepartmentId == null) { _snack("Please select a department"); return; }
    if (sectionNameController.text.trim().isEmpty) { _snack("Section name is required"); return; }
    if (category == "THUB" && getThubSlots() == null) {
      _snack("THUB sections must have reserved periods selected");
      return;
    }
    if (category == "NON_THUB" && getThubSlots() != null) {
      _snack("NON_THUB sections should not have THUB reserved periods");
      return;
    }
    final startTime = startTimeController.text.trim();
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(startTime)) {
      _snack("Start time must be in HH:MM format");
      return;
    }

    setState(() => loading = true);
    try {
      final token = (await TokenService.getUserSession())["token"] ?? widget.token;
      await dio.post(
        "${ApiService.baseUrl}/timetable/sections",
        data: {
          "department_id": selectedDepartmentId,
          "name": sectionNameController.text.trim(),
          "year": year,
          "semester": semester,
          "academic_year": academicYearController.text.trim(),
          "category": category,
          "classroom": classroomController.text.trim().isEmpty ? null : classroomController.text.trim(),
          "total_periods_per_day": int.parse(totalPeriodsController.text.trim()),
          "working_days": getWorkingDays(),
          "lunch_after_period": lunchSlot,
          "thub_reserved_periods": getThubSlots(),
          "start_time": startTime,
          "slot_duration_minutes": slotDurationMinutes,
          "lunch_duration_minutes": lunchDurationMinutes,
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      if (!mounted) return;
      sectionNameController.clear();
      classroomController.clear();
      startTimeController.text = "09:30";
      setState(() {
        selectedDays = [true, true, true, true, true, false];
        selectedThubSlots = List.generate(8, (_) => false);
        lunchSlot = 3;
      });
      _snack("Section created successfully ✓", success: true);
    } on DioException catch (e) {
      if (!mounted) return;
      _snack(e.response?.data?["detail"]?.toString() ?? "Failed to create section");
    } catch (e) {
      if (!mounted) return;
      _snack("Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? TimetableAppTheme.success : null,
    ));
  }

  @override
  void dispose() {
    sectionNameController.dispose();
    academicYearController.dispose();
    classroomController.dispose();
    totalPeriodsController.dispose();
    startTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TimetableAppTheme.background,
      appBar: TimetableAppTheme.buildAppBar(context, "Create Section"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TimetableAppTheme.infoBanner(
              "Examples:\n"
                  "• 2nd Yr NON_THUB → Mon–Fri, lunch = 50 min\n"
                  "• 2nd Yr THUB → Mon–Sat, select THUB periods (P1,P2,P3), lunch = 50 min\n"
                  "• 3rd Yr → Mon–Sat, lunch = 60 min\n"
                  "• Start time is usually 09:30",
            ),
            const SizedBox(height: 16),

            TimetableAppTheme.card(
              child: Column(
                children: [
                  TimetableAppTheme.sectionHeader("Basic Info"),
                  DepartmentDropdown(
                    token: widget.token,
                    value: selectedDepartmentId,
                    onChanged: (id, _) => setState(() => selectedDepartmentId = id),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: sectionNameController,
                    decoration: TimetableAppTheme.inputDecoration(
                      "Section Name",
                      hint: "e.g. CSE-A / CSE-1 / CSE-9",
                      prefixIcon: const Icon(Icons.class_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  // Category chips
                  TimetableAppTheme.sectionHeader("Category"),
                  Row(
                    children: ["NON_THUB", "THUB", "REGULAR"].map((cat) {
                      final selected = category == cat;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              category = cat;
                              if (cat == "NON_THUB") selectedDays[5] = false;
                              else selectedDays[5] = true;
                              if (cat != "THUB") {
                                for (int i = 0; i < selectedThubSlots.length; i++) selectedThubSlots[i] = false;
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                gradient: selected ? TimetableAppTheme.primaryGradient : null,
                                color: selected ? null : TimetableAppTheme.surfaceAlt,
                                borderRadius: BorderRadius.circular(TimetableAppTheme.radiusMd),
                                border: Border.all(color: selected ? Colors.transparent : TimetableAppTheme.border),
                              ),
                              child: Text(
                                cat == "NON_THUB" ? "NON_THUB" : cat,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: selected ? Colors.white : TimetableAppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: classroomController,
                    decoration: TimetableAppTheme.inputDecoration("Classroom (optional)", hint: "e.g. BGB-111"),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: totalPeriodsController,
                    keyboardType: TextInputType.number,
                    decoration: TimetableAppTheme.inputDecoration("Total Periods Per Day (incl. lunch)", hint: "8"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            TimetableAppTheme.card(
              child: Column(
                children: [
                  TimetableAppTheme.sectionHeader("Timing Settings"),
                  TextFormField(
                    controller: startTimeController,
                    decoration: TimetableAppTheme.inputDecoration("Start Time (HH:MM)", hint: "09:30",
                        prefixIcon: const Icon(Icons.access_time_outlined, size: 18)),
                  ),
                  const SizedBox(height: 12),
                  _dropdown<int>(
                    label: "Slot Duration (minutes)",
                    value: slotDurationMinutes,
                    items: {50: "50 minutes", 55: "55 minutes", 60: "60 minutes"},
                    onChanged: (v) { if (v != null) setState(() => slotDurationMinutes = v); },
                  ),
                  const SizedBox(height: 12),
                  _dropdown<int>(
                    label: "Lunch Break Duration",
                    value: lunchDurationMinutes,
                    items: {50: "50 minutes", 60: "60 minutes"},
                    onChanged: (v) { if (v != null) setState(() => lunchDurationMinutes = v); },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            TimetableAppTheme.card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TimetableAppTheme.sectionHeader("Working Days"),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(dayNames.length, (i) {
                      final selected = selectedDays[i];
                      return GestureDetector(
                        onTap: () => setState(() => selectedDays[i] = !selectedDays[i]),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 50,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            gradient: selected ? TimetableAppTheme.primaryGradient : null,
                            color: selected ? null : TimetableAppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(TimetableAppTheme.radiusMd),
                            border: Border.all(color: selected ? Colors.transparent : TimetableAppTheme.border),
                          ),
                          child: Text(
                            dayNames[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: selected ? Colors.white : TimetableAppTheme.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TimetableAppTheme.sectionHeader("Lunch After Period"),
                  _dropdown<int>(
                    label: "Lunch Slot",
                    value: lunchSlot,
                    items: {for (int i = 0; i < 8; i++) i: "After Period ${i + 1}"},
                    onChanged: (v) { if (v != null) setState(() => lunchSlot = v); },
                  ),
                ],
              ),
            ),

            if (category == "THUB") ...[
              const SizedBox(height: 12),
              TimetableAppTheme.card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TimetableAppTheme.sectionHeader("THUB Reserved Periods"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(8, (i) {
                        final selected = selectedThubSlots[i];
                        return GestureDetector(
                          onTap: () => setState(() => selectedThubSlots[i] = !selectedThubSlots[i]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 50,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: selected ? Colors.orange.shade600 : TimetableAppTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(TimetableAppTheme.radiusMd),
                              border: Border.all(
                                color: selected ? Colors.orange.shade600 : TimetableAppTheme.border,
                              ),
                            ),
                            child: Text(
                              "P${i + 1}",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: selected ? Colors.white : TimetableAppTheme.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            TimetableAppTheme.primaryButton(
              text: "Create Section",
              loading: loading,
              onPressed: createSection,
              icon: Icons.add_circle_outline,
            ),
            const SizedBox(height: 32),
          ],
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