import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import '../../../widgets/app_page_shell.dart';
import '../../../widgets/app_primary_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/app_dropdown_field.dart';

class CreateSectionScreen extends StatefulWidget {
  final String token;

  const CreateSectionScreen({super.key, required this.token});

  @override
  State<CreateSectionScreen> createState() => _CreateSectionScreenState();
}

class _CreateSectionScreenState extends State<CreateSectionScreen> {
  final Dio dio = Dio();

  final departmentIdController = TextEditingController();
  final sectionNameController = TextEditingController();
  final yearController = TextEditingController();
  final semesterController = TextEditingController();
  final academicYearController = TextEditingController(text: "2025-26");
  final classroomController = TextEditingController();
  final totalPeriodsController = TextEditingController(text: "8");

  // FIX: added start_time, slot_duration_minutes, lunch_duration_minutes
  final startTimeController = TextEditingController(text: "09:30");
  int slotDurationMinutes = 50;
  int lunchDurationMinutes = 60; // II yr = 50 min, III yr = 60 min

  String category = "NON_THUB";
  bool loading = false;

  final List<String> dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  List<bool> selectedDays = [true, true, true, true, true, false];

  List<bool> selectedThubSlots = List.generate(8, (_) => false);

  int lunchSlot = 3;

  String getWorkingDays() {
    List<int> days = [];
    for (int i = 0; i < selectedDays.length; i++) {
      if (selectedDays[i]) days.add(i);
    }
    return days.join(",");
  }

  String? getThubSlots() {
    List<int> slots = [];
    for (int i = 0; i < selectedThubSlots.length; i++) {
      if (selectedThubSlots[i]) slots.add(i);
    }
    if (slots.isEmpty) return null;
    return slots.join(",");
  }

  Future<void> createSection() async {
    if (sectionNameController.text.trim().isEmpty ||
        departmentIdController.text.trim().isEmpty ||
        yearController.text.trim().isEmpty ||
        semesterController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Department ID, Name, Year and Semester are required")),
      );
      return;
    }

    // FIX: warn if THUB section has no reserved slots set
    if (category == "THUB" && getThubSlots() == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "THUB sections must have THUB Reserved Periods selected (e.g. P1, P2, P3)."),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // FIX: warn if NON_THUB section has thub slots selected
    if (category == "NON_THUB" && getThubSlots() != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "NON_THUB sections should not have THUB reserved periods. Please clear them."),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Validate start_time format
    final startTime = startTimeController.text.trim();
    final timeRegex = RegExp(r'^\d{2}:\d{2}$');
    if (!timeRegex.hasMatch(startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Start time must be in HH:MM format, e.g. 09:30")),
      );
      return;
    }

    try {
      setState(() => loading = true);

      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;

      await dio.post(
        "${ApiService.baseUrl}/timetable/sections",
        data: {
          "department_id": int.tryParse(departmentIdController.text.trim()),
          "name": sectionNameController.text.trim(),
          "year": int.parse(yearController.text.trim()),
          "semester": int.parse(semesterController.text.trim()),
          "academic_year": academicYearController.text.trim(),
          "category": category,
          "classroom": classroomController.text.trim().isEmpty
              ? null
              : classroomController.text.trim(),
          "total_periods_per_day":
          int.parse(totalPeriodsController.text.trim()),
          "working_days": getWorkingDays(),
          "lunch_after_period": lunchSlot,
          "thub_reserved_periods": getThubSlots(),
          // FIX: now sending all three timing fields
          "start_time": startTime,
          "slot_duration_minutes": slotDurationMinutes,
          "lunch_duration_minutes": lunchDurationMinutes,
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (!mounted) return;

      // Reset form
      sectionNameController.clear();
      yearController.clear();
      semesterController.clear();
      classroomController.clear();
      startTimeController.text = "09:30";
      setState(() {
        selectedDays = [true, true, true, true, true, false];
        selectedThubSlots = List.generate(8, (_) => false);
        lunchSlot = 3;
        lunchDurationMinutes = 60;
        slotDurationMinutes = 50;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Section created successfully")),
      );
    } on DioException catch (e) {
      // FIX: show actual backend error
      if (!mounted) return;
      final msg = e.response?.data?["detail"]?.toString() ??
          "Failed to create section. Check all fields.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    departmentIdController.dispose();
    sectionNameController.dispose();
    yearController.dispose();
    semesterController.dispose();
    academicYearController.dispose();
    classroomController.dispose();
    totalPeriodsController.dispose();
    startTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: "Create Section",
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Info box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Examples:\n"
                    "• 2nd Year NON_THUB → Mon–Fri (uncheck Sat), lunch=50min\n"
                    "• 2nd Year THUB → Mon–Sat, select THUB periods (P1,P2,P3), lunch=50min\n"
                    "• 3rd Year → Mon–Sat, lunch=60min\n"
                    "• Start time is usually 09:30 for all sections",
                style: TextStyle(height: 1.5),
              ),
            ),
            const SizedBox(height: 12),

            AppTextField(
              controller: departmentIdController,
              label: "Department ID",
              hint: "Enter department id",
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              controller: sectionNameController,
              label: "Section Name",
              hint: "Example: CSE-A / CSE-1 / CSE-9",
            ),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: yearController,
                    label: "Year",
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextField(
                    controller: semesterController,
                    label: "Semester",
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            AppTextField(
              controller: academicYearController,
              label: "Academic Year",
              hint: "2025-26",
            ),
            AppDropdownField<String>(
              label: "Category",
              value: category,
              items: const [
                DropdownMenuItem(value: "NON_THUB", child: Text("NON_THUB")),
                DropdownMenuItem(value: "THUB", child: Text("THUB")),
                DropdownMenuItem(value: "REGULAR", child: Text("REGULAR")),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    category = val;
                    // Auto-set Saturday based on category
                    if (val == "NON_THUB") {
                      selectedDays[5] = false; // Sat off for NON_THUB II yr
                    } else {
                      selectedDays[5] = true; // Sat on for THUB / III yr
                    }
                    // Clear THUB slots if switching away from THUB
                    if (val != "THUB") {
                      for (int i = 0;
                      i < selectedThubSlots.length;
                      i++) {
                        selectedThubSlots[i] = false;
                      }
                    }
                  });
                }
              },
            ),
            AppTextField(
              controller: classroomController,
              label: "Classroom (optional)",
              hint: "e.g. BGB-111 / BGB-204",
            ),
            AppTextField(
              controller: totalPeriodsController,
              label: "Total Periods Per Day (including lunch)",
              hint: "8 = 7 teaching + 1 lunch",
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),
            // ── Timing Settings ─────────────────────────────────────
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Timing Settings",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(height: 10),
            AppTextField(
              controller: startTimeController,
              label: "Start Time (HH:MM)",
              hint: "09:30",
            ),
            const SizedBox(height: 12),
            // FIX: slot_duration_minutes now collected from operator
            AppDropdownField<int>(
              label: "Slot Duration (minutes per period)",
              value: slotDurationMinutes,
              items: const [
                DropdownMenuItem(value: 50, child: Text("50 minutes")),
                DropdownMenuItem(value: 55, child: Text("55 minutes")),
                DropdownMenuItem(value: 60, child: Text("60 minutes")),
              ],
              onChanged: (v) {
                if (v != null) setState(() => slotDurationMinutes = v);
              },
            ),
            const SizedBox(height: 4),
            // FIX: lunch_duration_minutes now collected from operator
            AppDropdownField<int>(
              label: "Lunch Break Duration (minutes)",
              value: lunchDurationMinutes,
              items: const [
                DropdownMenuItem(
                    value: 50,
                    child: Text("50 min")),
                DropdownMenuItem(
                    value: 60,
                    child: Text("60 min")),
              ],
              onChanged: (v) {
                if (v != null) setState(() => lunchDurationMinutes = v);
              },
            ),

            const SizedBox(height: 16),
            // ── Working Days ─────────────────────────────────────────
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Working Days",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: List.generate(dayNames.length, (i) {
                return FilterChip(
                  label: Text(dayNames[i]),
                  selected: selectedDays[i],
                  onSelected: (val) {
                    setState(() => selectedDays[i] = val);
                  },
                );
              }),
            ),

            const SizedBox(height: 16),
            // ── Lunch Slot ───────────────────────────────────────────
            DropdownButtonFormField<int>(
              value: lunchSlot,
              decoration: const InputDecoration(
                labelText: "Lunch After Period",
                border: OutlineInputBorder(),
              ),
              items: List.generate(8, (i) {
                return DropdownMenuItem(
                  value: i,
                  child: Text("After Period ${i + 1}  (slot index $i)"),
                );
              }),
              onChanged: (val) {
                if (val != null) setState(() => lunchSlot = val);
              },
            ),

            const SizedBox(height: 16),
            // ── THUB Reserved Periods ────────────────────────────────
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "THUB Reserved Periods",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            if (category != "THUB")
              const Text(
                "Only needed for THUB sections",
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            Wrap(
              spacing: 8,
              children: List.generate(8, (i) {
                return FilterChip(
                  label: Text("P${i + 1}"),
                  selected: selectedThubSlots[i],
                  onSelected: category == "THUB"
                      ? (val) {
                    setState(() => selectedThubSlots[i] = val);
                  }
                      : null, // disabled for NON_THUB / REGULAR
                );
              }),
            ),

            const SizedBox(height: 20),
            AppPrimaryButton(
              text: "Create Section",
              loading: loading,
              onPressed: createSection,
            ),
          ],
        ),
      ),
    );
  }
}