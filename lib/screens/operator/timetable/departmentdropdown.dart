import 'package:faculty_app/screens/operator/timetable/timetableapp_theme.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../../services/api_service.dart';
import '../../../services/token_service.dart';

/// A reusable dropdown that auto-loads departments from the API
/// and returns the selected department's id + name.
class DepartmentDropdown extends StatefulWidget {
  final String token;
  final int? value;
  final void Function(int id, String name)? onChanged;
  final String label;

  const DepartmentDropdown({
    super.key,
    required this.token,
    this.value,
    this.onChanged,
    this.label = "Department",
  });

  @override
  State<DepartmentDropdown> createState() => _DepartmentDropdownState();
}

class _DepartmentDropdownState extends State<DepartmentDropdown> {
  final Dio dio = Dio();
  List<Map<String, dynamic>> departments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;
      final res = await dio.get(
        "${ApiService.baseUrl}/departments",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      if (!mounted) return;
      setState(() {
        departments = List<Map<String, dynamic>>.from(
          (res.data as List).map((e) => Map<String, dynamic>.from(e)),
        );
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return DropdownButtonFormField<int>(
        decoration: TimetableAppTheme.inputDecoration(widget.label),
        items: const [],
        onChanged: null,
        hint: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text("Loading departments…"),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: widget.value,
      decoration: TimetableAppTheme.inputDecoration(
        widget.label,
        prefixIcon: const Icon(Icons.domain_outlined, size: 18),
      ),
      items: departments.map((d) {
        final id = int.parse(d["id"].toString());
        final name = d["name"]?.toString() ?? d["code"]?.toString() ?? "Dept $id";
        return DropdownMenuItem<int>(value: id, child: Text(name));
      }).toList(),
      onChanged: (id) {
        if (id == null) return;
        final dept = departments.firstWhere((d) => int.parse(d["id"].toString()) == id);
        final name = dept["name"]?.toString() ?? dept["code"]?.toString() ?? "$id";
        widget.onChanged?.call(id, name);
      },
    );
  }
}

/// Faculty search dropdown: loads all faculty for given department,
/// lets operator search/select by name instead of typing an ID.
class FacultyDropdown extends StatefulWidget {
  final String token;
  final int? departmentId;
  final String? value; // selected faculty_public_id
  final void Function(String publicId, String name)? onChanged;
  final String label;

  const FacultyDropdown({
    super.key,
    required this.token,
    this.departmentId,
    this.value,
    this.onChanged,
    this.label = "Faculty",
  });

  @override
  State<FacultyDropdown> createState() => _FacultyDropdownState();
}

class _FacultyDropdownState extends State<FacultyDropdown> {
  final Dio dio = Dio();
  List<Map<String, dynamic>> faculty = [];
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FacultyDropdown old) {
    super.didUpdateWidget(old);
    if (old.departmentId != widget.departmentId) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;

      final Map<String, dynamic> params = {};
      if (widget.departmentId != null) {
        params["department_id"] = widget.departmentId;
      }

      final res = await dio.get(
        "${ApiService.baseUrl}/faculty-list",
        queryParameters: params,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      if (!mounted) return;
      setState(() {
        faculty = List<Map<String, dynamic>>.from(
          (res.data is List ? res.data : (res.data["items"] ?? [])).map(
                (e) => Map<String, dynamic>.from(e),
          ),
        );
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = "Failed to load faculty";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return DropdownButtonFormField<String>(
        decoration: TimetableAppTheme.inputDecoration(widget.label),
        items: const [],
        onChanged: null,
        hint: const Row(children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text("Loading faculty…"),
        ]),
      );
    }
    if (error != null) {
      return Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: TimetableAppTheme.inputDecoration(widget.label),
            items: const [],
            onChanged: null,
            hint: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]);
    }

    return DropdownButtonFormField<String>(
      value: widget.value,
      decoration: TimetableAppTheme.inputDecoration(
        widget.label,
        prefixIcon: const Icon(Icons.person_outline, size: 18),
      ),
      isExpanded: true,
      items: faculty.map((f) {
        final pid = f["faculty_id"]?.toString() ?? f["public_id"]?.toString() ?? "";
        final name = f["name"]?.toString() ?? pid;
        return DropdownMenuItem<String>(
          value: pid,
          child: Text(
            "$name  ($pid)",
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (pid) {
        if (pid == null) return;
        final f = faculty.firstWhere(
              (x) => (x["faculty_id"]?.toString() ?? x["public_id"]?.toString()) == pid,
          orElse: () => {},
        );
        final name = f["name"]?.toString() ?? pid;
        widget.onChanged?.call(pid, name);
      },
    );
  }
}

/// Section dropdown: loads sections for a given department + academic year,
/// lets operator pick by name.
class SectionDropdown extends StatefulWidget {
  final String token;
  final int? departmentId;
  final String academicYear;
  final int? value; // selected section id
  final void Function(int id, String name)? onChanged;
  final String label;

  const SectionDropdown({
    super.key,
    required this.token,
    this.departmentId,
    required this.academicYear,
    this.value,
    this.onChanged,
    this.label = "Section",
  });

  @override
  State<SectionDropdown> createState() => _SectionDropdownState();
}

class _SectionDropdownState extends State<SectionDropdown> {
  final Dio dio = Dio();
  List<Map<String, dynamic>> sections = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.departmentId != null) _load();
  }

  @override
  void didUpdateWidget(SectionDropdown old) {
    super.didUpdateWidget(old);
    if (old.departmentId != widget.departmentId ||
        old.academicYear != widget.academicYear) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.departmentId == null) return;
    setState(() => loading = true);
    try {
      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;
      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/sections",
        queryParameters: {
          "department_id": widget.departmentId,
          "academic_year": widget.academicYear,
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      if (!mounted) return;
      setState(() {
        sections = List<Map<String, dynamic>>.from(
          (res.data as List).map((e) => Map<String, dynamic>.from(e)),
        );
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.departmentId == null) {
      return DropdownButtonFormField<int>(
        decoration: TimetableAppTheme.inputDecoration(widget.label),
        items: const [],
        onChanged: null,
        hint: const Text("Select a department first"),
      );
    }
    if (loading) {
      return DropdownButtonFormField<int>(
        decoration: TimetableAppTheme.inputDecoration(widget.label),
        items: const [],
        onChanged: null,
        hint: const Row(children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text("Loading sections…"),
        ]),
      );
    }

    return DropdownButtonFormField<int>(
      value: widget.value,
      decoration: TimetableAppTheme.inputDecoration(
        widget.label,
        prefixIcon: const Icon(Icons.class_outlined, size: 18),
      ),
      isExpanded: true,
      items: sections.map((s) {
        final id = int.parse(s["id"].toString());
        final name = s["name"]?.toString() ?? "Section $id";
        final cat = s["category"]?.toString() ?? "";
        return DropdownMenuItem<int>(
          value: id,
          child: Text(
            cat.isNotEmpty ? "$name  [$cat]" : name,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (id) {
        if (id == null) return;
        final s = sections.firstWhere((x) => int.parse(x["id"].toString()) == id);
        widget.onChanged?.call(id, s["name"]?.toString() ?? "$id");
      },
    );
  }
}