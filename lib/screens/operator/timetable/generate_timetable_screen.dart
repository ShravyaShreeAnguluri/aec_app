import 'package:faculty_app/screens/operator/timetable/timetableapp_theme.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import 'departmentdropdown.dart';

class GenerateTimetableScreen extends StatefulWidget {
  final String token;
  const GenerateTimetableScreen({super.key, required this.token});

  @override
  State<GenerateTimetableScreen> createState() => _GenerateTimetableScreenState();
}

class _GenerateTimetableScreenState extends State<GenerateTimetableScreen> {
  final Dio dio = Dio();

  int? selectedDepartmentId;
  String? selectedDepartmentName;
  final academicYearController = TextEditingController(text: "2025-26");

  bool loading = false;
  Map<String, dynamic>? result;

  Future<void> generate() async {
    if (selectedDepartmentId == null) { _snack("Please select a department"); return; }
    if (academicYearController.text.trim().isEmpty) { _snack("Academic year is required"); return; }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TimetableAppTheme.radiusLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: TimetableAppTheme.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_outlined, color: TimetableAppTheme.primaryLight, size: 22),
            ),
            const SizedBox(width: 12),
            const Text("Generate Timetable", style: TextStyle(fontSize: 17)),
          ],
        ),
        content: const Text(
          "This will DELETE the existing timetable for this department and generate a new one.\n\n"
              "Make sure all rooms, sections, subjects and faculty mappings are set up correctly.\n\n"
              "Continue?",
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: TimetableAppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Generate"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() { loading = true; result = null; });
    try {
      final token = (await TokenService.getUserSession())["token"] ?? widget.token;
      final res = await dio.post(
        "${ApiService.baseUrl}/timetable/generate/sync",
        data: {
          "department_id": selectedDepartmentId,
          "academic_year": academicYearController.text.trim(),
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      setState(() => result = Map<String, dynamic>.from(res.data));
      if (!mounted) return;
      final errors = (result!["errors"] as List?) ?? [];
      _snack(
        errors.isEmpty ? "Timetable generated successfully! ✓" : "Generated with ${errors.length} error(s)",
        success: errors.isEmpty,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      _snack(e.response?.data?["detail"]?.toString() ?? "Failed to generate timetable");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? TimetableAppTheme.success : null,
      duration: const Duration(seconds: 5),
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
      appBar: TimetableAppTheme.buildAppBar(context, "Generate Timetable"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TimetableAppTheme.infoBanner(
              "Before generating, make sure:\n"
                  "1. All rooms and labs are created\n"
                  "2. All sections are created with correct timing\n"
                  "3. All subjects are created with correct weekly hours\n"
                  "4. All faculty–subject mappings are created\n\n"
                  "⚠ This will overwrite the existing timetable for this department.",
              icon: Icons.warning_amber_outlined,
            ),
            const SizedBox(height: 16),

            TimetableAppTheme.card(
              child: Column(
                children: [
                  TimetableAppTheme.sectionHeader("Department & Year"),
                  DepartmentDropdown(
                    token: widget.token,
                    value: selectedDepartmentId,
                    onChanged: (id, name) => setState(() {
                      selectedDepartmentId = id;
                      selectedDepartmentName = name;
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: academicYearController,
                    decoration: TimetableAppTheme.inputDecoration("Academic Year", hint: "2025-26"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TimetableAppTheme.primaryButton(
              text: loading ? "Generating…" : "Generate Timetable",
              loading: loading,
              onPressed: loading ? null : generate,
              icon: Icons.auto_awesome_outlined,
            ),

            if (result != null) ...[
              const SizedBox(height: 20),
              _ResultCard(result: result!),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final success = result["success"] == true;
    final sectionsProcessed = result["sections_processed"] ?? 0;
    final errors = (result["errors"] as List?) ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TimetableAppTheme.radiusLg),
        boxShadow: TimetableAppTheme.cardShadow,
        border: Border.all(
          color: success ? const Color(0xFFA5D6A7) : Colors.orange.shade200,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: success ? const Color(0xFFE8F5E9) : Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(TimetableAppTheme.radiusLg)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: success ? const Color(0xFFA5D6A7) : Colors.orange.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    success ? Icons.check_rounded : Icons.warning_amber_rounded,
                    color: success ? TimetableAppTheme.success : Colors.orange.shade800,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    success ? "Timetable Generated Successfully" : "Generated with Errors",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: success ? TimetableAppTheme.success : Colors.orange.shade800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.class_outlined, size: 16, color: TimetableAppTheme.textHint),
                    const SizedBox(width: 6),
                    Text(
                      "Sections processed: $sectionsProcessed",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (errors.isEmpty)
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: TimetableAppTheme.success),
                      const SizedBox(width: 6),
                      const Text("All subjects placed successfully", style: TextStyle(color: TimetableAppTheme.success, fontSize: 13)),
                    ],
                  )
                else ...[
                  Text(
                    "${errors.length} error${errors.length == 1 ? '' : 's'} — some subjects could not be placed:",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TimetableAppTheme.error),
                  ),
                  const SizedBox(height: 10),
                  ...errors.asMap().entries.map((entry) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${entry.key + 1}. ",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: TimetableAppTheme.error)),
                        Expanded(child: Text(entry.value.toString(), style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}