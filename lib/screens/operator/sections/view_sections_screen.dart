import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import '../../../widgets/app_page_shell.dart';
import '../../../widgets/app_primary_button.dart';
import '../../../widgets/app_text_field.dart';

class ViewSectionsScreen extends StatefulWidget {
  final String token;

  const ViewSectionsScreen({super.key, required this.token});

  @override
  State<ViewSectionsScreen> createState() => _ViewSectionsScreenState();
}

class _ViewSectionsScreenState extends State<ViewSectionsScreen> {
  final Dio dio = Dio();

  final departmentIdController = TextEditingController();
  final academicYearController = TextEditingController(text: "2025-26");

  List sections = [];
  bool loading = false;

  final List<String> dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

  Future<void> loadSections() async {
    if (departmentIdController.text.trim().isEmpty ||
        academicYearController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Department ID and Academic Year are required")),
      );
      return;
    }

    try {
      setState(() => loading = true);

      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;

      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/sections",
        queryParameters: {
          "department_id": int.tryParse(departmentIdController.text.trim()),
          "academic_year": academicYearController.text.trim(),
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      setState(() {
        sections = res.data is List ? res.data : [];
      });
    } on DioException catch (e) {
      sections = [];
      if (mounted) {
        final msg = e.response?.data?["detail"]?.toString() ??
            "Failed to load sections";
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      sections = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<int> parseCsv(dynamic value) {
    if (value == null) return [];
    final text = value.toString().trim();
    if (text.isEmpty) return [];
    return text
        .split(",")
        .map((e) => int.tryParse(e.trim()))
        .where((e) => e != null)
        .cast<int>()
        .toList();
  }

  String formatWorkingDays(dynamic value) {
    final days = parseCsv(value);
    if (days.isEmpty) return "-";
    final labels = days
        .where((d) => d >= 0 && d < dayNames.length)
        .map((d) => dayNames[d])
        .toList();
    if (labels.length == 6) return "Mon–Sat";
    if (labels.length == 5 &&
        labels[0] == "Mon" &&
        labels[4] == "Fri") {
      return "Mon–Fri";
    }
    return labels.join(", ");
  }

  String formatThubReserved(dynamic value) {
    final periods = parseCsv(value);
    if (periods.isEmpty) return "None";
    return periods.map((p) => "P${p + 1}").join(", ");
  }

  Widget infoChip(String label, dynamic value, {Color? bg, Color? fg}) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFF2F5FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$label: ${value ?? '-'}",
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
          color: fg ?? const Color(0xFF374151),
        ),
      ),
    );
  }

  Widget sectionCard(dynamic s) {
    final category = s["category"]?.toString() ?? "";
    final isThub = category == "THUB";
    final isNonThub = category == "NON_THUB";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            color: Color(0x14000000),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s["name"]?.toString() ?? "-",
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isThub
                      ? Colors.orange.shade100
                      : isNonThub
                      ? Colors.blue.shade100
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isThub
                        ? Colors.orange.shade900
                        : isNonThub
                        ? Colors.blue.shade900
                        : Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            children: [
              infoChip("Year", s["year"]),
              infoChip("Sem", s["semester"]),
              infoChip("Room", s["classroom"]),
              infoChip("Days", formatWorkingDays(s["working_days"])),
              infoChip(
                "Lunch after",
                "P${(s["lunch_after_period"] ?? 3) + 1}",
              ),
              infoChip(
                "Lunch",
                "${s["lunch_duration_minutes"] ?? 60} min",
              ),
              infoChip(
                "Slot",
                "${s["slot_duration_minutes"] ?? 50} min",
              ),
              infoChip("Start", s["start_time"]),
              if (isThub)
                infoChip(
                  "T-Hub slots",
                  formatThubReserved(s["thub_reserved_periods"]),
                  bg: Colors.orange.shade50,
                  fg: Colors.orange.shade900,
                ),
            ],
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
      title: "View Sections",
      child: Column(
        children: [
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
          const SizedBox(height: 8),
          AppPrimaryButton(
            text: "Load Sections",
            loading: loading,
            onPressed: loadSections,
          ),
          if (sections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                "${sections.length} section${sections.length == 1 ? '' : 's'} found",
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : sections.isEmpty
                ? const Center(
                child: Text("No sections found. Load to view."))
                : ListView.separated(
              itemCount: sections.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 12),
              itemBuilder: (_, i) => sectionCard(sections[i]),
            ),
          ),
        ],
      ),
    );
  }
}