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
  final Map<String, dynamic>? subjectData;

  const CreateSubjectScreen({
    super.key,
    required this.token,
    this.subjectData,
  });

  @override
  State<CreateSubjectScreen> createState() => _CreateSubjectScreenState();
}

class _CreateSubjectScreenState extends State<CreateSubjectScreen> {
  final Dio dio = Dio();

  // ---------- Department dropdown ----------
  // Add more departments here if needed
  final Map<String, int> departmentOptions = const {
    "CSE": 1,
  };

  String? selectedDepartmentName;

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

  final fixedDayController = TextEditingController();
  final fixedStartPeriodController = TextEditingController();
  final fixedSpanController = TextEditingController(text: "1");

  final notesController = TextEditingController();

  String subjectType = "THEORY";
  String requiresRoomType = "CLASSROOM";

  bool isLab = false;
  bool isFixed = false;
  bool fixedEveryWorkingDay = false;
  bool noFacultyRequired = false;
  bool allowSameDayRepeat = false;
  bool loading = false;

  final List<String> dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  final List<bool> selectedAllowedDays = List.generate(6, (_) => false);
  final List<bool> selectedAllowedPeriods = List.generate(8, (_) => false);
  final List<bool> selectedFixedDays = List.generate(6, (_) => false);

  bool get isEditMode => widget.subjectData != null;

  int? get editingSubjectId {
    final value = widget.subjectData?["id"];
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  String? chipsToCsv(List<bool> values) {
    final result = <int>[];
    for (int i = 0; i < values.length; i++) {
      if (values[i]) result.add(i);
    }
    if (result.isEmpty) return null;
    return result.join(",");
  }

  void setCsvToChips(String? csv, List<bool> target) {
    for (int i = 0; i < target.length; i++) {
      target[i] = false;
    }
    if (csv == null || csv.trim().isEmpty) return;

    final parts = csv.split(",");
    for (final p in parts) {
      final index = int.tryParse(p.trim());
      if (index != null && index >= 0 && index < target.length) {
        target[index] = true;
      }
    }
  }

  String? _validateFixedOptions() {
    if (!isFixed) return null;

    final hasSingleDay = fixedDayController.text.trim().isNotEmpty;
    final hasChipDays = chipsToCsv(selectedFixedDays) != null;
    final hasEveryDay = fixedEveryWorkingDay;

    final count = [hasSingleDay, hasChipDays, hasEveryDay].where((v) => v).length;

    if (count == 0) {
      return "Fixed subject needs one day option.";
    }
    if (count > 1) {
      return "Fixed subject must use only one day option.";
    }
    if (fixedStartPeriodController.text.trim().isEmpty) {
      return "Fixed subject needs Fixed Start Period.";
    }
    return null;
  }

  void prefillIfEdit() {
    final s = widget.subjectData;
    if (s == null) return;

    final deptId = int.tryParse((s["department_id"] ?? "").toString());
    if (deptId != null) {
      for (final entry in departmentOptions.entries) {
        if (entry.value == deptId) {
          selectedDepartmentName = entry.key;
          break;
        }
      }
    }

    academicYearController.text = (s["academic_year"] ?? "2025-26").toString();
    yearController.text = (s["year"] ?? "").toString();
    semesterController.text = (s["semester"] ?? "").toString();

    codeController.text = (s["code"] ?? "").toString();
    nameController.text = (s["name"] ?? "").toString();
    shortNameController.text = (s["short_name"] ?? "").toString();

    subjectType = (s["subject_type"] ?? "THEORY").toString();
    requiresRoomType = (s["requires_room_type"] ?? "CLASSROOM").toString();

    isLab = s["is_lab"] == true;
    isFixed = s["is_fixed"] == true;
    fixedEveryWorkingDay = s["fixed_every_working_day"] == true;
    noFacultyRequired = s["no_faculty_required"] == true;
    allowSameDayRepeat = s["allow_same_day_repeat"] == true;

    weeklyHoursController.text = (s["weekly_hours"] ?? 0).toString();
    weeklyHoursThubController.text =
        s["weekly_hours_thub"]?.toString() ?? "";
    weeklyHoursNonThubController.text =
        s["weekly_hours_non_thub"]?.toString() ?? "";

    minContinuousController.text =
        (s["min_continuous_periods"] ?? 1).toString();
    maxContinuousController.text =
        (s["max_continuous_periods"] ?? 1).toString();

    defaultRoomController.text = s["default_room_name"]?.toString() ?? "";

    fixedDayController.text = s["fixed_day"]?.toString() ?? "";
    fixedStartPeriodController.text =
        s["fixed_start_period"]?.toString() ?? "";
    fixedSpanController.text = (s["fixed_span"] ?? 1).toString();

    notesController.text = s["notes"]?.toString() ?? "";

    setCsvToChips(s["allowed_days"]?.toString(), selectedAllowedDays);
    setCsvToChips(s["allowed_periods"]?.toString(), selectedAllowedPeriods);
    setCsvToChips(s["fixed_days"]?.toString(), selectedFixedDays);
  }

  Future<void> submitSubject() async {
    final selectedDepartmentId =
    selectedDepartmentName == null ? null : departmentOptions[selectedDepartmentName!];

    if (selectedDepartmentId == null ||
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

      final payload = {
        "department_id": selectedDepartmentId,
        "year": int.parse(yearController.text.trim()),
        "semester": int.parse(semesterController.text.trim()),
        "academic_year": academicYearController.text.trim(),
        "code": codeController.text.trim(),
        "name": nameController.text.trim(),
        "short_name": shortNameController.text.trim(),
        "subject_type": subjectType,
        "weekly_hours": int.tryParse(weeklyHoursController.text.trim()) ?? 0,
        "weekly_hours_thub": weeklyHoursThubController.text.trim().isEmpty
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
        "fixed_every_working_day": isFixed ? fixedEveryWorkingDay : false,
        "fixed_day": resolvedFixedDay,
        "fixed_days": resolvedFixedDays,
        "fixed_start_period":
        isFixed ? int.tryParse(fixedStartPeriodController.text.trim()) : null,
        "fixed_span":
        isFixed ? (int.tryParse(fixedSpanController.text.trim()) ?? 1) : 1,
        "allowed_days": chipsToCsv(selectedAllowedDays),
        "allowed_periods": chipsToCsv(selectedAllowedPeriods),
        "no_faculty_required": noFacultyRequired,
        "allow_same_day_repeat": allowSameDayRepeat,
        "notes": notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      };

      if (isEditMode && editingSubjectId != null) {
        await dio.put(
          "${ApiService.baseUrl}/timetable/subjects/$editingSubjectId",
          data: payload,
          options: Options(headers: {"Authorization": "Bearer $token"}),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Subject updated successfully")),
        );
        Navigator.pop(context, true);
      } else {
        await dio.post(
          "${ApiService.baseUrl}/timetable/subjects",
          data: payload,
          options: Options(headers: {"Authorization": "Bearer $token"}),
        );

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
          isLab = false;
          subjectType = "THEORY";
          requiresRoomType = "CLASSROOM";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Subject created successfully")),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;

      String msg = "Failed to save subject";
      final detail = e.response?.data?["detail"];

      if (detail is String) {
        msg = detail;
      } else if (detail is Map && detail["message"] != null) {
        msg = detail["message"].toString();
        if (detail["errors"] is List && (detail["errors"] as List).isNotEmpty) {
          msg += "\n${(detail["errors"] as List).join("\n")}";
        }
      }

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
  void initState() {
    super.initState();
    selectedDepartmentName = departmentOptions.keys.first;

    if (yearController.text.isEmpty) {
      yearController.text = "3";
    }
    if (semesterController.text.isEmpty) {
      semesterController.text = "6";
    }

    prefillIfEdit();
  }

  @override
  void dispose() {
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
      title: isEditMode ? "Update Subject" : "Create Subject",
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
              child: Text(
                isEditMode
                    ? "Update the subject details below."
                    : "Examples:\n"
                    "• Theory → weekly_hours = 3, \nmin/max continuous = 1\n"
                    "• Lab → is_lab = true, \n min/max continuous = 3\n"
                    "• FIP → type=FIP, \nis_fixed=true, \nfixed_every_working_day=true, \nfixed_start_period=7, \nno_faculty=true\n"
                    "• PSA → type=PSA, \nallowed_days selected, \nno_faculty=true",
                style: const TextStyle(height: 1.5),
              ),
            ),
            const SizedBox(height: 12),

            AppDropdownField<String>(
              label: "Department",
              value: selectedDepartmentName ?? departmentOptions.keys.first,
              items: departmentOptions.keys
                  .map(
                    (dept) => DropdownMenuItem<String>(
                  value: dept,
                  child: Text(dept),
                ),
              )
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() => selectedDepartmentName = val);
              },
            ),

            AppTextField(
              controller: academicYearController,
              label: "Academic Year",
              hint: "2025-26",
            ),

            Row(
              children: [
                Expanded(
                  child: AppDropdownField<String>(
                    label: "Year",
                    value: yearController.text,
                    items: const [
                      DropdownMenuItem(value: "1", child: Text("1")),
                      DropdownMenuItem(value: "2", child: Text("2")),
                      DropdownMenuItem(value: "3", child: Text("3")),
                      DropdownMenuItem(value: "4", child: Text("4")),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => yearController.text = val);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppDropdownField<String>(
                    label: "Semester",
                    value: semesterController.text,
                    items: const [
                      DropdownMenuItem(value: "1", child: Text("1")),
                      DropdownMenuItem(value: "2", child: Text("2")),
                      DropdownMenuItem(value: "3", child: Text("3")),
                      DropdownMenuItem(value: "4", child: Text("4")),
                      DropdownMenuItem(value: "5", child: Text("5")),
                      DropdownMenuItem(value: "6", child: Text("6")),
                      DropdownMenuItem(value: "7", child: Text("7")),
                      DropdownMenuItem(value: "8", child: Text("8")),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => semesterController.text = val);
                    },
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

                  if (val == "THUB" || val == "PSA") {
                    noFacultyRequired = true;
                    requiresRoomType = "NONE";
                  }

                  if (val == "THEORY" && !isEditMode) {
                    isLab = false;
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
                    subtitle: const Text("Has a fixed day/period"),
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
                    subtitle: const Text("For FIP / THUB / PSA"),
                    onChanged: (value) {
                      setState(() => noFacultyRequired = value);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: allowSameDayRepeat,
                    title: const Text("Allow Same Day Repeat"),
                    subtitle: const Text("Subject can appear twice on same day"),
                    onChanged: (value) {
                      setState(() => allowSameDayRepeat = value);
                    },
                  ),
                ],
              ),
            ),

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

            sectionTitle("Room Settings"),
            AppDropdownField<String>(
              label: "Required Room Type",
              value: requiresRoomType,
              items: const [
                DropdownMenuItem(value: "CLASSROOM", child: Text("CLASSROOM")),
                DropdownMenuItem(value: "LAB", child: Text("LAB")),
                DropdownMenuItem(
                  value: "NONE",
                  child: Text("NONE (FIP / THUB / PSA)"),
                ),
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

            if (!isLab) ...[
              sectionTitle("Allowed Days (optional)"),
              buildChips(labels: dayNames, values: selectedAllowedDays),
              const SizedBox(height: 12),
              sectionTitle("Allowed Periods (optional)"),
              buildChips(
                labels: List.generate(8, (i) => "P${i + 1}"),
                values: selectedAllowedPeriods,
              ),
            ],

            if (isFixed) ...[
              sectionTitle("Fixed Subject Settings"),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Choose exactly one day option:\n"
                      "• Fixed Every Working Day\n"
                      "• Select fixed days using chips\n"
                      "• Enter one fixed day number",
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
              const SizedBox(height: 10),

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
                  subtitle: const Text("Use for FIP"),
                  onChanged: (value) {
                    setState(() {
                      fixedEveryWorkingDay = value;
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
                sectionTitle("Select Fixed Days"),
                buildChips(labels: dayNames, values: selectedFixedDays),
                const SizedBox(height: 8),
                sectionTitle("Single Fixed Day Number"),
                TextField(
                  controller: fixedDayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Fixed Day (0=Mon ... 5=Sat)",
                    hintText: "Example: 0 for Monday",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
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
                hint: "0=P1, 1=P2 ... 7=P8",
                keyboardType: TextInputType.number,
              ),
              AppTextField(
                controller: fixedSpanController,
                label: "Fixed Span",
                hint: "1 for FIP, 2 or 3 for multi-period fixed",
                keyboardType: TextInputType.number,
              ),
            ],

            AppTextField(
              controller: notesController,
              label: "Notes (optional)",
              hint: "Any special instructions",
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              text: isEditMode ? "Update Subject" : "Create Subject",
              loading: loading,
              onPressed: submitSubject,
            ),
          ],
        ),
      ),
    );
  }
}