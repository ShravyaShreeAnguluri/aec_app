import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import 'create_subject_screen.dart';

class ViewSubjectsScreen extends StatefulWidget {
  final String token;

  const ViewSubjectsScreen({super.key, required this.token});

  @override
  State<ViewSubjectsScreen> createState() => _ViewSubjectsScreenState();
}

class _ViewSubjectsScreenState extends State<ViewSubjectsScreen> {
  final Dio dio = Dio();

  final Map<String, int> departmentOptions = const {
    "CSE": 1,
  };

  String? selectedDepartmentName = "CSE";
  final academicYearController = TextEditingController(text: "2025-26");

  String? selectedYear;
  String? selectedSemester;

  List subjects = [];
  bool loading = false;
  String searchQuery = "";

  int? get selectedDepartmentId {
    if (selectedDepartmentName == null) return null;
    return departmentOptions[selectedDepartmentName!];
  }

  Future<void> loadSubjects() async {
    if (selectedDepartmentId == null ||
        academicYearController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Department and Academic Year are required"),
        ),
      );
      return;
    }

    try {
      setState(() => loading = true);

      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;

      final Map<String, dynamic> queryParams = {
        "department_id": selectedDepartmentId,
        "academic_year": academicYearController.text.trim(),
      };

      if (selectedYear != null && selectedYear!.trim().isNotEmpty) {
        queryParams["year"] = int.parse(selectedYear!);
      }

      if (selectedSemester != null && selectedSemester!.trim().isNotEmpty) {
        queryParams["semester"] = int.parse(selectedSemester!);
      }

      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/subjects",
        queryParameters: queryParams,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      setState(() {
        subjects = res.data is List ? List.from(res.data) : [];
      });
    } on DioException catch (e) {
      subjects = [];
      if (mounted) {
        final msg = e.response?.data?["detail"]?.toString() ??
            "Failed to load subjects";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      subjects = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> deleteSubject(int subjectId) async {
    try {
      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;

      await dio.delete(
        "${ApiService.baseUrl}/timetable/subjects/$subjectId",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subject deleted successfully")),
      );
      loadSubjects();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?["detail"]?.toString() ??
          "Failed to delete subject";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Future<void> openEdit(dynamic subject) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateSubjectScreen(
          token: widget.token,
          subjectData: Map<String, dynamic>.from(subject),
        ),
      ),
    );

    if (changed == true) {
      loadSubjects();
    }
  }

  Future<void> confirmDelete(dynamic subject) async {
    final subjectId = int.tryParse((subject["id"] ?? "").toString());
    if (subjectId == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Subject"),
        content: Text(
          "Are you sure you want to delete '${subject["short_name"] ?? subject["name"] ?? "this subject"}'?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (result == true) {
      deleteSubject(subjectId);
    }
  }

  List get filteredSubjects {
    if (searchQuery.trim().isEmpty) return subjects;
    final q = searchQuery.trim().toLowerCase();
    return subjects.where((s) {
      final name = (s["name"] ?? "").toString().toLowerCase();
      final code = (s["code"] ?? "").toString().toLowerCase();
      final short = (s["short_name"] ?? "").toString().toLowerCase();
      return name.contains(q) || code.contains(q) || short.contains(q);
    }).toList();
  }

  Color _typeColor(String? type) {
    switch (type) {
      case "LAB":
        return const Color(0xFFE1F5FE);
      case "THEORY":
        return const Color(0xFFF3E5F5);
      case "FIP":
        return const Color(0xFFE8F5E9);
      case "THUB":
        return const Color(0xFFFFF8E1);
      case "PSA":
        return const Color(0xFFFCE4EC);
      default:
        return const Color(0xFFF2F5FA);
    }
  }

  Color _typeTextColor(String? type) {
    switch (type) {
      case "LAB":
        return const Color(0xFF0277BD);
      case "THEORY":
        return const Color(0xFF4527A0);
      case "FIP":
        return const Color(0xFF2E7D32);
      case "THUB":
        return const Color(0xFFE65100);
      case "PSA":
        return const Color(0xFFC2185B);
      default:
        return const Color(0xFF374151);
    }
  }

  Widget chip(String label, dynamic value, {Color? bg, Color? fg}) {
    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFF2F5FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$label: ${value ?? '-'}",
        style: TextStyle(
          fontSize: 11,
          color: fg ?? const Color(0xFF374151),
        ),
      ),
    );
  }

  Widget subjectCard(dynamic s) {
    final type = s["subject_type"]?.toString();
    final isFixed = s["is_fixed"] == true;
    final isLab = s["is_lab"] == true;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${s["short_name"] ?? "-"}  •  ${s["code"] ?? "-"}",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s["name"]?.toString() ?? "-",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _typeColor(type),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  type ?? "-",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _typeTextColor(type),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            children: [
              chip("Year", s["year"]),
              chip("Sem", s["semester"]),
              chip("Hours", s["weekly_hours"]),
              if (s["weekly_hours_thub"] != null)
                chip(
                  "THUB hrs",
                  s["weekly_hours_thub"],
                  bg: Colors.orange.shade50,
                  fg: Colors.orange.shade900,
                ),
              if (s["weekly_hours_non_thub"] != null)
                chip(
                  "NON_THUB hrs",
                  s["weekly_hours_non_thub"],
                  bg: Colors.blue.shade50,
                  fg: Colors.blue.shade900,
                ),
              if (isLab) ...[
                chip(
                  "Min span",
                  s["min_continuous_periods"],
                  bg: const Color(0xFFE1F5FE),
                  fg: const Color(0xFF0277BD),
                ),
                chip(
                  "Max span",
                  s["max_continuous_periods"],
                  bg: const Color(0xFFE1F5FE),
                  fg: const Color(0xFF0277BD),
                ),
              ],
              chip("Room type", s["requires_room_type"]),
              if (s["default_room_name"] != null)
                chip("Default room", s["default_room_name"]),
            ],
          ),
          if (isFixed) ...[
            const Divider(height: 12),
            Wrap(
              children: [
                chip(
                  "Fixed",
                  "YES",
                  bg: Colors.green.shade50,
                  fg: Colors.green.shade800,
                ),
                if (s["fixed_every_working_day"] == true)
                  chip(
                    "Every day",
                    "YES",
                    bg: Colors.green.shade50,
                    fg: Colors.green.shade800,
                  ),
                if (s["fixed_day"] != null) chip("Fixed day", s["fixed_day"]),
                if (s["fixed_days"] != null) chip("Fixed days", s["fixed_days"]),
                chip("Start period", "P${(s["fixed_start_period"] ?? 0) + 1}"),
                chip("Span", s["fixed_span"]),
              ],
            ),
          ],
          if (s["allowed_days"] != null || s["allowed_periods"] != null) ...[
            const Divider(height: 12),
            Wrap(
              children: [
                if (s["allowed_days"] != null)
                  chip(
                    "Allowed days",
                    s["allowed_days"],
                    bg: Colors.purple.shade50,
                    fg: Colors.purple.shade800,
                  ),
                if (s["allowed_periods"] != null)
                  chip(
                    "Allowed periods",
                    s["allowed_periods"],
                    bg: Colors.purple.shade50,
                    fg: Colors.purple.shade800,
                  ),
              ],
            ),
          ],
          if (s["no_faculty_required"] == true ||
              s["allow_same_day_repeat"] == true) ...[
            const SizedBox(height: 4),
            Wrap(
              children: [
                if (s["no_faculty_required"] == true)
                  chip("No faculty", "YES"),
                if (s["allow_same_day_repeat"] == true)
                  chip("Same-day repeat", "YES"),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openEdit(s),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text("Edit"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => confirmDelete(s),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text("Delete"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadSubjects();
  }

  @override
  void dispose() {
    academicYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredSubjects;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(title: const Text("View Subjects")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDepartmentName,
                  decoration: const InputDecoration(
                    labelText: "Department",
                    border: OutlineInputBorder(),
                  ),
                  items: departmentOptions.keys
                      .map(
                        (dept) => DropdownMenuItem<String>(
                      value: dept,
                      child: Text(dept),
                    ),
                  )
                      .toList(),
                  onChanged: (val) {
                    setState(() => selectedDepartmentName = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: academicYearController,
                  decoration: const InputDecoration(
                    labelText: "Academic Year",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedYear,
                        decoration: const InputDecoration(
                          labelText: "Year (optional)",
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: "1", child: Text("1")),
                          DropdownMenuItem(value: "2", child: Text("2")),
                          DropdownMenuItem(value: "3", child: Text("3")),
                          DropdownMenuItem(value: "4", child: Text("4")),
                        ],
                        onChanged: (val) {
                          setState(() => selectedYear = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedSemester,
                        decoration: const InputDecoration(
                          labelText: "Semester (optional)",
                          border: OutlineInputBorder(),
                        ),
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
                          setState(() => selectedSemester = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : loadSubjects,
                    child: Text(loading ? "Loading..." : "Load Subjects"),
                  ),
                ),
              ],
            ),
          ),
          if (subjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  labelText: "Search by name, code or short name",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (v) => setState(() => searchQuery = v),
              ),
            ),
          if (subjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${filtered.length} subject${filtered.length == 1 ? '' : 's'}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
              child: Text(
                subjects.isEmpty
                    ? "No subjects found. Load to view."
                    : "No results for '$searchQuery'",
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 12),
              itemBuilder: (_, i) => subjectCard(filtered[i]),
            ),
          ),
        ],
      ),
    );
  }
}