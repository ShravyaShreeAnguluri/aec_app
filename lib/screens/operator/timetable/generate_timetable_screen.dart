import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import '../../../widgets/app_page_shell.dart';
import '../../../widgets/app_primary_button.dart';
import '../../../widgets/app_text_field.dart';

class GenerateTimetableScreen extends StatefulWidget {
  final String token;

  const GenerateTimetableScreen({super.key, required this.token});

  @override
  State<GenerateTimetableScreen> createState() =>
      _GenerateTimetableScreenState();
}

class _GenerateTimetableScreenState extends State<GenerateTimetableScreen> {
  final Dio dio = Dio();

  final departmentIdController = TextEditingController();
  final academicYearController = TextEditingController(text: "2025-26");

  bool loading = false;
  Map<String, dynamic>? result;

  Future<void> generateTimetable() async {
    if (departmentIdController.text.trim().isEmpty ||
        academicYearController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Department ID and Academic Year are required")),
      );
      return;
    }

    // Confirmation dialog — generation deletes and rebuilds existing timetable
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Generate Timetable"),
        content: const Text(
          "This will DELETE the existing timetable for this department and "
              "generate a new one.\n\nMake sure all rooms, sections, subjects, and "
              "faculty mappings are set up correctly before proceeding.\n\n"
              "Continue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: const Text("Generate"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        loading = true;
        result = null;
      });

      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;

      final res = await dio.post(
        "${ApiService.baseUrl}/timetable/generate/sync",
        data: {
          "department_id": int.parse(departmentIdController.text.trim()),
          "academic_year": academicYearController.text.trim(),
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      setState(() {
        result = Map<String, dynamic>.from(res.data);
      });

      if (!mounted) return;

      final errors = (result!["errors"] as List?) ?? [];
      if (errors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Timetable generated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Generated with ${errors.length} error${errors.length == 1 ? '' : 's'}. See details below."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      // FIX: show actual backend error
      final msg = e.response?.data?["detail"]?.toString() ??
          "Failed to generate timetable";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 6)),
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

  Widget resultCard() {
    if (result == null) return const SizedBox.shrink();

    final success = result!["success"] == true;
    final sectionsProcessed = result!["sections_processed"] ?? 0;
    final errors = (result!["errors"] as List?) ?? [];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            color: Color(0x14000000),
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: success ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: success ? Colors.green : Colors.orange,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  success
                      ? "Timetable Generated Successfully"
                      : "Generated with Errors",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: success
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                    fontSize: 15,
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
                    const Icon(Icons.class_outlined,
                        size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(
                      "Sections processed: $sectionsProcessed",
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (errors.isEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.check,
                          size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      const Text(
                        "No errors — all subjects placed successfully",
                        style: TextStyle(
                            fontSize: 13, color: Colors.green),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 16, color: Colors.red.shade400),
                      const SizedBox(width: 6),
                      Text(
                        "${errors.length} error${errors.length == 1 ? '' : 's'} — some subjects could not be placed:",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...errors.asMap().entries.map(
                        (entry) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.shade100),
                      ),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${entry.key + 1}. ",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value.toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    departmentIdController.dispose();
    academicYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: "Generate Timetable",
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Instructions card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Before generating, make sure:\n"
                    "1. All rooms and labs are created\n"
                    "2. All sections are created (with correct timing and THUB/NON_THUB)\n"
                    "3. All subjects are created (with correct weekly hours and fixed settings)\n"
                    "4. All faculty-subject mappings are created\n\n"
                    "Generation will overwrite the existing timetable for this department.",
                style: TextStyle(height: 1.5),
              ),
            ),
            const SizedBox(height: 16),

            AppTextField(
              controller: departmentIdController,
              label: "Department ID",
              hint: "Enter department id",
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              controller: academicYearController,
              label: "Academic Year",
              hint: "Example: 2025-26",
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              text: loading ? "Generating..." : "Generate Timetable",
              loading: loading,
              onPressed: loading ? null : generateTimetable,
            ),
            resultCard(),
          ],
        ),
      ),
    );
  }
}