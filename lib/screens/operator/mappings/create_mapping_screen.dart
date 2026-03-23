import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_page_shell.dart';
import '../../../widgets/app_primary_button.dart';
import '../../../widgets/app_text_field.dart';

class CreateFacultyMappingScreen extends StatefulWidget {
  final String token;

  const CreateFacultyMappingScreen({
    super.key,
    required this.token,
  });

  @override
  State<CreateFacultyMappingScreen> createState() =>
      _CreateFacultyMappingScreenState();
}

class _CreateFacultyMappingScreenState
    extends State<CreateFacultyMappingScreen> {
  final Dio dio = Dio();

  final facultyPublicIdController = TextEditingController();
  final departmentIdController = TextEditingController(text: "1");
  final academicYearController = TextEditingController(text: "2025-26");

  int year = 3;
  int semester = 6;

  List subjects = [];
  int? selectedSubjectId;

  int priority = 1;
  // FIX: changed default max_hours_per_week from 30 to 6 (realistic per-subject value)
  int maxHoursPerWeek = 6;
  int maxHoursPerDay = 7;
  bool canHandleLab = true;
  bool isPrimary = true;

  bool loadingSubjects = false;
  bool loading = false;

  Future<void> loadSubjects() async {
    if (departmentIdController.text.trim().isEmpty ||
        academicYearController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Department ID and Academic Year are required"),
        ),
      );
      return;
    }

    try {
      setState(() => loadingSubjects = true);

      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;

      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/subjects",
        queryParameters: {
          "department_id": int.parse(departmentIdController.text.trim()),
          "year": year,
          "semester": semester,
          "academic_year": academicYearController.text.trim(),
        },
        options: Options(
          headers: {"Authorization": "Bearer $token"},
        ),
      );

      if (!mounted) return;

      setState(() {
        subjects = List.from(res.data);
        selectedSubjectId = subjects.isNotEmpty
            ? int.parse(subjects.first["id"].toString())
            : null;
      });

      if (subjects.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No subjects found for this selection")),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      // FIX: show actual backend error
      final msg = e.response?.data?["detail"]?.toString() ??
          "Failed to load subjects";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => loadingSubjects = false);
    }
  }

  Future<void> createMapping() async {
    if (facultyPublicIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Faculty Public ID is required")),
      );
      return;
    }

    if (selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please load and select a subject")),
      );
      return;
    }

    try {
      setState(() => loading = true);

      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;

      await dio.post(
        "${ApiService.baseUrl}/timetable/faculty-subject-map",
        data: {
          "faculty_public_id": facultyPublicIdController.text.trim(),
          "subject_id": selectedSubjectId,
          "priority": priority,
          "max_hours_per_week": maxHoursPerWeek,
          "max_hours_per_day": maxHoursPerDay,
          "can_handle_lab": canHandleLab,
          "is_primary": isPrimary,
        },
        options: Options(
          headers: {"Authorization": "Bearer $token"},
        ),
      );

      if (!mounted) return;

      // Reset for next mapping
      facultyPublicIdController.clear();
      setState(() {
        selectedSubjectId = null;
        subjects = [];
        priority = 1;
        maxHoursPerWeek = 6;
        maxHoursPerDay = 7;
        canHandleLab = true;
        isPrimary = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Faculty mapping created successfully")),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      // FIX: show actual backend error
      final msg = e.response?.data?["detail"]?.toString() ??
          "Failed to create mapping";
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
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

  Widget infoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        "Steps:\n"
            "1. Enter Faculty Public ID (e.g. FAC001)\n"
            "2. Select Department, Year, Semester and Academic Year\n"
            "3. Tap 'Load Subjects'\n"
            "4. Select the Subject\n"
            "5. Set workload limits and tap 'Create Mapping'\n\n"
            "Note: max_hours_per_week should be the total hours this faculty\n"
            "teaches THIS subject across all sections per week.",
        style: TextStyle(height: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    facultyPublicIdController.dispose();
    departmentIdController.dispose();
    academicYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: "Create Faculty Mapping",
      child: SingleChildScrollView(
        child: Column(
          children: [
            infoCard(),
            const SizedBox(height: 12),

            AppTextField(
              controller: facultyPublicIdController,
              label: "Faculty Public ID",
              hint: "Example: FAC001",
            ),
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

            sectionTitle("Subject Filter"),
            AppDropdownField<int>(
              label: "Year",
              value: year,
              items: const [
                DropdownMenuItem(value: 1, child: Text("1st Year")),
                DropdownMenuItem(value: 2, child: Text("2nd Year")),
                DropdownMenuItem(value: 3, child: Text("3rd Year")),
                DropdownMenuItem(value: 4, child: Text("4th Year")),
              ],
              onChanged: (value) {
                if (value != null) setState(() => year = value);
              },
            ),
            AppDropdownField<int>(
              label: "Semester",
              value: semester,
              items: const [
                DropdownMenuItem(value: 1, child: Text("Semester 1")),
                DropdownMenuItem(value: 2, child: Text("Semester 2")),
                DropdownMenuItem(value: 3, child: Text("Semester 3")),
                DropdownMenuItem(value: 4, child: Text("Semester 4")),
                DropdownMenuItem(value: 5, child: Text("Semester 5")),
                DropdownMenuItem(value: 6, child: Text("Semester 6")),
                DropdownMenuItem(value: 7, child: Text("Semester 7")),
                DropdownMenuItem(value: 8, child: Text("Semester 8")),
              ],
              onChanged: (value) {
                if (value != null) setState(() => semester = value);
              },
            ),
            const SizedBox(height: 8),
            AppPrimaryButton(
              text: "Load Subjects",
              loading: loadingSubjects,
              onPressed: loadSubjects,
            ),

            if (subjects.isNotEmpty && selectedSubjectId != null) ...[
              const SizedBox(height: 14),
              sectionTitle("Select Subject"),
              AppDropdownField<int>(
                label: "Subject",
                value: selectedSubjectId!,
                items: subjects.map<DropdownMenuItem<int>>((s) {
                  return DropdownMenuItem<int>(
                    value: int.parse(s["id"].toString()),
                    child: Text(
                      "${s["short_name"]} — ${s["name"]}",
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => selectedSubjectId = value);
                },
              ),
            ],

            sectionTitle("Mapping Rules"),
            AppDropdownField<int>(
              label: "Priority (1 = highest / primary)",
              value: priority,
              items: const [
                DropdownMenuItem(value: 1, child: Text("1 — Primary teacher")),
                DropdownMenuItem(value: 2, child: Text("2 — Backup teacher")),
                DropdownMenuItem(value: 3, child: Text("3 — Second backup")),
              ],
              onChanged: (value) {
                if (value != null) setState(() => priority = value);
              },
            ),

            // FIX: max_hours_per_week options now realistic for per-subject workload
            AppDropdownField<int>(
              label: "Max Hours Per Week (for this subject)",
              value: maxHoursPerWeek,
              items: const [
                DropdownMenuItem(value: 3, child: Text("3 hrs/week")),
                DropdownMenuItem(value: 4, child: Text("4 hrs/week")),
                DropdownMenuItem(value: 5, child: Text("5 hrs/week")),
                DropdownMenuItem(value: 6, child: Text("6 hrs/week")),
                DropdownMenuItem(value: 8, child: Text("8 hrs/week")),
                DropdownMenuItem(value: 10, child: Text("10 hrs/week")),
                DropdownMenuItem(value: 15, child: Text("15 hrs/week")),
                DropdownMenuItem(value: 20, child: Text("20 hrs/week")),
              ],
              onChanged: (value) {
                if (value != null) setState(() => maxHoursPerWeek = value);
              },
            ),

            AppDropdownField<int>(
              label: "Max Hours Per Day (college rule = 7)",
              value: maxHoursPerDay,
              items: const [
                DropdownMenuItem(value: 2, child: Text("2 per day")),
                DropdownMenuItem(value: 3, child: Text("3 per day")),
                DropdownMenuItem(value: 4, child: Text("4 per day")),
                DropdownMenuItem(value: 5, child: Text("5 per day")),
                DropdownMenuItem(value: 6, child: Text("6 per day")),
                DropdownMenuItem(value: 7, child: Text("7 per day (max)")),
              ],
              onChanged: (value) {
                if (value != null) setState(() => maxHoursPerDay = value);
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
                    value: canHandleLab,
                    title: const Text("Can handle LAB sessions"),
                    subtitle: const Text(
                        "Enable if faculty can take lab sessions for this subject"),
                    onChanged: (value) {
                      setState(() => canHandleLab = value);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: isPrimary,
                    title: const Text("Primary Faculty"),
                    subtitle: const Text(
                        "Primary faculty is preferred first during generation"),
                    onChanged: (value) {
                      setState(() => isPrimary = value);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            AppPrimaryButton(
              text: "Create Mapping",
              onPressed: createMapping,
              loading: loading,
            ),
          ],
        ),
      ),
    );
  }
}