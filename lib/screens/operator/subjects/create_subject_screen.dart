import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import '../../../widgets/app_page_shell.dart';
import '../../../widgets/app_primary_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/app_dropdown_field.dart';

class CreateSubjectScreen extends StatefulWidget {
  final String token;

  const CreateSubjectScreen({super.key, required this.token});

  @override
  State<CreateSubjectScreen> createState() => _CreateSubjectScreenState();
}

class _CreateSubjectScreenState extends State<CreateSubjectScreen> {
  final Dio dio = Dio();

  final departmentIdController = TextEditingController();
  final yearController = TextEditingController();
  final semesterController = TextEditingController();
  final academicYearController = TextEditingController(text: "2025-26");

  final codeController = TextEditingController();
  final nameController = TextEditingController();
  final shortNameController = TextEditingController();

  final weeklyHoursController = TextEditingController(text: "0");
  final weeklyHoursThubController = TextEditingController();
  final weeklyHoursNonThubController = TextEditingController();

  final minContinuousController = TextEditingController(text: "1");
  final maxContinuousController = TextEditingController(text: "1");

  final defaultRoomController = TextEditingController();

  // Fixed subject fields
  final fixedDayController = TextEditingController();
  final fixedStartPeriodController = TextEditingController();
  final fixedSpanController = TextEditingController(text: "1");

  final notesController = TextEditingController();

  String subjectType = "THEORY";
  String requiresRoomType = "CLASSROOM";

  bool isLab = false;
  bool isFixed = false;
  bool fixedEveryWorkingDay = false; // FIX: was missing — needed for FIP
  bool noFacultyRequired = false;
  bool allowSameDayRepeat = false;
  bool loading = false;

  final List<String> dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  final List<bool> selectedAllowedDays = List.generate(6, (_) => false);
  final List<bool> selectedAllowedPeriods = List.generate(8, (_) => false);
  final List<bool> selectedFixedDays = List.generate(6, (_) => false);

  String? chipsToCsv(List<bool> values) {
    final result = <int>[];
    for (int i = 0; i < values.length; i++) {
      if (values[i]) result.add(i);
    }
    if (result.isEmpty) return null;
    return result.join(",");
  }

  /// FIX: Validates that exactly one fixed day option is set when isFixed=true.
  /// Returns an error message string or null if valid.
  String? _validateFixedOptions() {
    if (!isFixed) return null;

    final hasSingleDay = fixedDayController.text.trim().isNotEmpty;
    final hasChipDays = chipsToCsv(selectedFixedDays) != null;
    final hasEveryDay = fixedEveryWorkingDay;

    final count = [hasSingleDay, hasChipDays, hasEveryDay]
        .where((v) => v)
        .length;

    if (count == 0) {
      return "Fixed subject needs a day option: enter a day number, select day chips, or enable 'Fixed Every Working Day'.";
    }
    if (count > 1) {
      return "Fixed subject must use only ONE day option. Please clear the others.";
    }
    if (fixedStartPeriodController.text.trim().isEmpty) {
      return "Fixed subject needs a Fixed Start Period (e.g. 7 for last period).";
    }
    return null;
  }

  Future<void> createSubject() async {
    if (departmentIdController.text.trim().isEmpty ||
        yearController.text.trim().isEmpty ||
        semesterController.text.trim().isEmpty ||
        academicYearController.text.trim().isEmpty ||
        codeController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty ||
        shortNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    // FIX: validate fixed subject options before submitting
    final fixedError = _validateFixedOptions();
    if (fixedError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fixedError)),
      );
      return;
    }

    try {
      setState(() => loading = true);

      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;

      // FIX: Determine fixed day fields — only ONE must be non-null
      // If fixedEveryWorkingDay is true → all day fields null
      // If chip days selected → fixed_day = null, fixed_days = CSV
      // If single day typed → fixed_day = int, fixed_days = null
      final String? resolvedFixedDays = (isFixed && !fixedEveryWorkingDay)
          ? (fixedDayController.text.trim().isEmpty
          ? chipsToCsv(selectedFixedDays)
          : null)
          : null;

      final int? resolvedFixedDay = (isFixed && !fixedEveryWorkingDay)
          ? (fixedDayController.text.trim().isNotEmpty
          ? int.tryParse(fixedDayController.text.trim())
          : null)
          : null;

      await dio.post(
        "${ApiService.baseUrl}/timetable/subjects",
        data: {
          "department_id": int.parse(departmentIdController.text.trim()),
          "year": int.parse(yearController.text.trim()),
          "semester": int.parse(semesterController.text.trim()),
          "academic_year": academicYearController.text.trim(),
          "code": codeController.text.trim(),
          "name": nameController.text.trim(),
          "short_name": shortNameController.text.trim(),
          "subject_type": subjectType,
          "weekly_hours":
          int.tryParse(weeklyHoursController.text.trim()) ?? 0,
          "weekly_hours_thub":
          weeklyHoursThubController.text.trim().isEmpty
              ? null
              : int.tryParse(weeklyHoursThubController.text.trim()),
          "weekly_hours_non_thub":
          weeklyHoursNonThubController.text.trim().isEmpty
              ? null
              : int.tryParse(weeklyHoursNonThubController.text.trim()),
          "is_lab": isLab,
          "min_continuous_periods":
          int.tryParse(minContinuousController.text.trim()) ?? 1,
          "max_continuous_periods":
          int.tryParse(maxContinuousController.text.trim()) ?? 1,
          "requires_room_type": requiresRoomType,
          "default_room_name": defaultRoomController.text.trim().isEmpty
              ? null
              : defaultRoomController.text.trim(),
          "is_fixed": isFixed,
          // FIX: fixed_every_working_day now correctly sent
          "fixed_every_working_day": isFixed ? fixedEveryWorkingDay : false,
          // FIX: only one of these will be non-null
          "fixed_day": resolvedFixedDay,
          "fixed_days": resolvedFixedDays,
          // FIX: fixed_start_period sent as null when isFixed=false
          "fixed_start_period": isFixed
              ? int.tryParse(fixedStartPeriodController.text.trim())
              : null,
          "fixed_span":
          isFixed ? (int.tryParse(fixedSpanController.text.trim()) ?? 1) : 1,
          "allowed_days": chipsToCsv(selectedAllowedDays),
          "allowed_periods": chipsToCsv(selectedAllowedPeriods),
          "no_faculty_required": noFacultyRequired,
          "allow_same_day_repeat": allowSameDayRepeat,
          "notes": notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      // Reset form
      codeController.clear();
      nameController.clear();
      shortNameController.clear();
      weeklyHoursController.text = "0";
      weeklyHoursThubController.clear();
      weeklyHoursNonThubController.clear();
      minContinuousController.text = "1";
      maxContinuousController.text = "1";
      defaultRoomController.clear();
      fixedDayController.clear();
      fixedStartPeriodController.clear();
      fixedSpanController.text = "1";
      notesController.clear();

      for (int i = 0; i < selectedAllowedDays.length; i++) {
        selectedAllowedDays[i] = false;
      }
      for (int i = 0; i < selectedAllowedPeriods.length; i++) {
        selectedAllowedPeriods[i] = false;
      }
      for (int i = 0; i < selectedFixedDays.length; i++) {
        selectedFixedDays[i] = false;
      }

      if (!mounted) return;
      setState(() {
        isFixed = false;
        fixedEveryWorkingDay = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subject created successfully")),
      );
    } on DioException catch (e) {
      // FIX: show actual backend error message
      if (!mounted) return;
      final msg = e.response?.data?["detail"]?.toString() ??
          "Failed to create subject. Check all fields.";
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

  Widget sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget buildChips({
    required List<String> labels,
    required List<bool> values,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(labels.length, (i) {
          return FilterChip(
            label: Text(labels[i]),
            selected: values[i],
            onSelected: (val) {
              setState(() => values[i] = val);
            },
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    departmentIdController.dispose();
    yearController.dispose();
    semesterController.dispose();
    academicYearController.dispose();
    codeController.dispose();
    nameController.dispose();
    shortNameController.dispose();
    weeklyHoursController.dispose();
    weeklyHoursThubController.dispose();
    weeklyHoursNonThubController.dispose();
    minContinuousController.dispose();
    maxContinuousController.dispose();
    defaultRoomController.dispose();
    fixedDayController.dispose();
    fixedStartPeriodController.dispose();
    fixedSpanController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: "Create Subject",
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Examples:\n"
                    "• Theory → weekly_hours = 3, min/max continuous = 1\n"
                    "• Lab → is_lab = true, min/max continuous = 3\n"
                    "• FIP → type=FIP, is_fixed=true, fixed_every_working_day=true, fixed_start_period=7, no_faculty=true\n"
                    "• PSA → type=PSA, allowed_days selected, no_faculty=true",
                style: TextStyle(height: 1.5),
              ),
            ),
            const SizedBox(height: 12),

            // ── Basic Info ──────────────────────────────────────────
            AppTextField(
              controller: departmentIdController,
              label: "Department ID",
              hint: "Enter department id",
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              controller: academicYearController,
              label: "Academic Year",
              hint: "2025-26",
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
              controller: codeController,
              label: "Subject Code",
              hint: "Example: 231CS6T01",
            ),
            AppTextField(
              controller: nameController,
              label: "Subject Name",
              hint: "Example: Cloud Computing",
            ),
            AppTextField(
              controller: shortNameController,
              label: "Short Name",
              hint: "Example: CC",
            ),

            // ── Subject Type ────────────────────────────────────────
            AppDropdownField<String>(
              label: "Subject Type",
              value: subjectType,
              items: const [
                DropdownMenuItem(value: "THEORY", child: Text("THEORY")),
                DropdownMenuItem(value: "LAB", child: Text("LAB")),
                DropdownMenuItem(value: "ACTIVITY", child: Text("ACTIVITY")),
                DropdownMenuItem(value: "THUB", child: Text("THUB")),
                DropdownMenuItem(value: "FIP", child: Text("FIP")),
                DropdownMenuItem(value: "PSA", child: Text("PSA")),
                DropdownMenuItem(value: "OTHER", child: Text("OTHER")),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  subjectType = val;
                  if (val == "LAB") {
                    isLab = true;
                    requiresRoomType = "LAB";
                    minContinuousController.text = "3";
                    maxContinuousController.text = "3";
                  }
                  if (val == "FIP") {
                    isFixed = true;
                    fixedEveryWorkingDay = true;
                    noFacultyRequired = true;
                    requiresRoomType = "NONE";
                    weeklyHoursController.text = "0";
                  }
                  if (val == "THUB") {
                    noFacultyRequired = true;
                    requiresRoomType = "NONE";
                  }
                  if (val == "PSA") {
                    noFacultyRequired = true;
                    requiresRoomType = "NONE";
                  }
                });
              },
            ),

            const SizedBox(height: 4),
            Card(
              elevation: 0,
              color: const Color(0xFFF7F9FC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: isLab,
                    title: const Text("Is Lab"),
                    subtitle: const Text("Needs continuous periods + lab room"),
                    onChanged: (value) {
                      setState(() {
                        isLab = value;
                        if (value) {
                          subjectType = "LAB";
                          requiresRoomType = "LAB";
                          minContinuousController.text = "3";
                          maxContinuousController.text = "3";
                        }
                      });
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: isFixed,
                    title: const Text("Is Fixed Subject"),
                    subtitle: const Text(
                        "Has a fixed day/period (FIP, PSA, etc.)"),
                    onChanged: (value) {
                      setState(() {
                        isFixed = value;
                        if (!value) fixedEveryWorkingDay = false;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: noFacultyRequired,
                    title: const Text("No Faculty Required"),
                    subtitle: const Text(
                        "For FIP, THUB blocks, PSA activity"),
                    onChanged: (value) {
                      setState(() => noFacultyRequired = value);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: allowSameDayRepeat,
                    title: const Text("Allow Same Day Repeat"),
                    subtitle: const Text(
                        "Subject can appear twice on same day"),
                    onChanged: (value) {
                      setState(() => allowSameDayRepeat = value);
                    },
                  ),
                ],
              ),
            ),

            // ── Weekly Hours ────────────────────────────────────────
            sectionTitle("Weekly Hours"),
            AppTextField(
              controller: weeklyHoursController,
              label: "Default Weekly Hours",
              hint: "Use 0 for FIP/THUB/PSA",
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              controller: weeklyHoursThubController,
              label: "Weekly Hours for THUB sections (optional)",
              hint: "Leave empty to use default",
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              controller: weeklyHoursNonThubController,
              label: "Weekly Hours for NON_THUB sections (optional)",
              hint: "Leave empty to use default",
              keyboardType: TextInputType.number,
            ),

            // ── Room Settings ───────────────────────────────────────
            sectionTitle("Room Settings"),
            AppDropdownField<String>(
              label: "Required Room Type",
              value: requiresRoomType,
              items: const [
                DropdownMenuItem(
                    value: "CLASSROOM", child: Text("CLASSROOM")),
                DropdownMenuItem(value: "LAB", child: Text("LAB")),
                DropdownMenuItem(
                    value: "NONE",
                    child: Text("NONE (FIP / THUB / PSA)")),
              ],
              onChanged: (val) {
                if (val != null) setState(() => requiresRoomType = val);
              },
            ),
            AppTextField(
              controller: defaultRoomController,
              label: "Default Room Name (optional)",
              hint: "e.g. LAB-1 / BGB-111",
            ),

            // ── Lab Continuous Periods ──────────────────────────────
            if (isLab) ...[
              sectionTitle("Lab Continuous Periods"),
              AppTextField(
                controller: minContinuousController,
                label: "Minimum Continuous Periods",
                hint: "Usually 3 for labs",
                keyboardType: TextInputType.number,
              ),
              AppTextField(
                controller: maxContinuousController,
                label: "Maximum Continuous Periods",
                hint: "Usually 3 for labs",
                keyboardType: TextInputType.number,
              ),
            ],

            // ── Allowed Days / Periods (theory only) ────────────────
            if (!isLab) ...[
              sectionTitle("Allowed Days (optional — leave blank for any day)"),
              buildChips(labels: dayNames, values: selectedAllowedDays),
              const SizedBox(height: 12),
              sectionTitle(
                  "Allowed Periods (optional — leave blank for any period)"),
              buildChips(
                labels: List.generate(8, (i) => "P${i + 1}"),
                values: selectedAllowedPeriods,
              ),
            ],

            // ── Fixed Subject Settings ──────────────────────────────
            if (isFixed) ...[
              sectionTitle("Fixed Subject Settings"),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Choose EXACTLY ONE day option:\n"
                      "• Option A: Enable 'Fixed Every Working Day' (for FIP)\n"
                      "• Option B: Select days using chips below\n"
                      "• Option C: Type a single day number in the field",
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
              const SizedBox(height: 10),

              // FIX: fixed_every_working_day toggle — was completely missing
              Card(
                elevation: 0,
                color: fixedEveryWorkingDay
                    ? Colors.green.shade50
                    : const Color(0xFFF7F9FC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SwitchListTile(
                  value: fixedEveryWorkingDay,
                  title: const Text("Fixed Every Working Day"),
                  subtitle: const Text(
                      "Use for FIP — placed last period every day"),
                  onChanged: (value) {
                    setState(() {
                      fixedEveryWorkingDay = value;
                      // Clear other day options when this is enabled
                      if (value) {
                        fixedDayController.clear();
                        for (int i = 0; i < selectedFixedDays.length; i++) {
                          selectedFixedDays[i] = false;
                        }
                      }
                    });
                  },
                ),
              ),

              if (!fixedEveryWorkingDay) ...[
                const SizedBox(height: 10),
                sectionTitle("Option B: Select Fixed Days"),
                buildChips(labels: dayNames, values: selectedFixedDays),
                const SizedBox(height: 8),
                sectionTitle("Option C: Single Fixed Day Number"),
                // Using plain TextField here because we need onChanged to
                // auto-clear chips — AppTextField does not expose onChanged.
                TextField(
                  controller: fixedDayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Fixed Day (0=Mon, 1=Tue ... 5=Sat)",
                    hintText: "Example: 0 for Monday",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    // When operator types a day number, clear the chip selection
                    // so that only ONE fixed-day option is active at a time.
                    if (fixedDayController.text.trim().isNotEmpty) {
                      setState(() {
                        for (int i = 0; i < selectedFixedDays.length; i++) {
                          selectedFixedDays[i] = false;
                        }
                      });
                    }
                  },
                ),
              ],

              const SizedBox(height: 4),
              AppTextField(
                controller: fixedStartPeriodController,
                label: "Fixed Start Period Index (0-based)",
                hint: "0=P1, 1=P2 ... 7=P8 (last period for FIP)",
                keyboardType: TextInputType.number,
              ),
              AppTextField(
                controller: fixedSpanController,
                label: "Fixed Span (number of periods)",
                hint: "1 for FIP, 2 or 3 for multi-period fixed",
                keyboardType: TextInputType.number,
              ),
            ],

            // ── Notes ───────────────────────────────────────────────
            AppTextField(
              controller: notesController,
              label: "Notes (optional)",
              hint: "Any special instructions",
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              text: "Create Subject",
              loading: loading,
              onPressed: createSubject,
            ),
          ],
        ),
      ),
    );
  }
}