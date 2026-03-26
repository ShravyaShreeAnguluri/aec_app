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

  static const _bg = Color(0xFFF4F8FD);
  static const _card = Color(0xFFFFFFFF);
  static const _navy = Color(0xFF0D47A1);
  static const _navyMid = Color(0xFF1565C0);
  static const _navyLight = Color(0xFF1E88E5);
  static const _accent = Color(0xFF2196F3);
  static const _teal = Color(0xFF0288D1);
  static const _success = Color(0xFF2E7D32);
  static const _danger = Color(0xFFC62828);
  static const _warning = Color(0xFFEF6C00);
  static const _purple = Color(0xFF6A1B9A);
  static const _textPrimary = Color(0xFF102033);
  static const _textSub = Color(0xFF506070);
  static const _textMuted = Color(0xFF8A9AAA);
  static const _border = Color(0xFFE5EEF7);

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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

  Widget chip(String label, dynamic value, {Color? bg, Color? fg, IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFF2F5FA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: (fg ?? _textMuted).withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg ?? const Color(0xFF374151)),
            const SizedBox(width: 5),
          ],
          Text(
            "$label: ${value ?? '-'}",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg ?? const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget subjectCard(dynamic s) {
    final type = s["subject_type"]?.toString();
    final isFixed = s["is_fixed"] == true;
    final isLab = s["is_lab"] == true;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_navy, _navyLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s["name"]?.toString() ?? "-",
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${s["short_name"] ?? "-"} • ${s["code"] ?? "-"}",
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _typeColor(type),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    type ?? "-",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _typeTextColor(type),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              children: [
                chip("Year", s["year"], icon: Icons.school_outlined),
                chip("Sem", s["semester"], icon: Icons.layers_outlined),
                chip("Hours", s["weekly_hours"], icon: Icons.schedule_rounded),
                if (s["weekly_hours_thub"] != null)
                  chip(
                    "THUB hrs",
                    s["weekly_hours_thub"],
                    bg: Colors.orange.shade50,
                    fg: Colors.orange.shade900,
                    icon: Icons.hub_outlined,
                  ),
                if (s["weekly_hours_non_thub"] != null)
                  chip(
                    "NON_THUB hrs",
                    s["weekly_hours_non_thub"],
                    bg: Colors.blue.shade50,
                    fg: Colors.blue.shade900,
                    icon: Icons.account_tree_outlined,
                  ),
                if (isLab) ...[
                  chip(
                    "Min span",
                    s["min_continuous_periods"],
                    bg: const Color(0xFFE1F5FE),
                    fg: const Color(0xFF0277BD),
                    icon: Icons.linear_scale_rounded,
                  ),
                  chip(
                    "Max span",
                    s["max_continuous_periods"],
                    bg: const Color(0xFFE1F5FE),
                    fg: const Color(0xFF0277BD),
                    icon: Icons.straighten_rounded,
                  ),
                ],
                chip(
                  "Room type",
                  s["requires_room_type"],
                  icon: Icons.meeting_room_outlined,
                ),
                if (s["default_room_name"] != null)
                  chip(
                    "Default room",
                    s["default_room_name"],
                    bg: Colors.green.shade50,
                    fg: Colors.green.shade800,
                    icon: Icons.location_on_outlined,
                  ),
              ],
            ),
            if (isFixed) ...[
              const SizedBox(height: 4),
              const Divider(color: _border, height: 18),
              Wrap(
                children: [
                  chip(
                    "Fixed",
                    "YES",
                    bg: Colors.green.shade50,
                    fg: Colors.green.shade800,
                    icon: Icons.push_pin_outlined,
                  ),
                  if (s["fixed_every_working_day"] == true)
                    chip(
                      "Every day",
                      "YES",
                      bg: Colors.green.shade50,
                      fg: Colors.green.shade800,
                      icon: Icons.event_repeat_rounded,
                    ),
                  if (s["fixed_day"] != null)
                    chip("Fixed day", s["fixed_day"], icon: Icons.today_outlined),
                  if (s["fixed_days"] != null)
                    chip("Fixed days", s["fixed_days"], icon: Icons.view_week_outlined),
                  chip(
                    "Start period",
                    "P${(s["fixed_start_period"] ?? 0) + 1}",
                    icon: Icons.play_arrow_outlined,
                  ),
                  chip("Span", s["fixed_span"], icon: Icons.width_normal_rounded),
                ],
              ),
            ],
            if (s["allowed_days"] != null || s["allowed_periods"] != null) ...[
              const SizedBox(height: 4),
              const Divider(color: _border, height: 18),
              Wrap(
                children: [
                  if (s["allowed_days"] != null)
                    chip(
                      "Allowed days",
                      s["allowed_days"],
                      bg: Colors.purple.shade50,
                      fg: Colors.purple.shade800,
                      icon: Icons.date_range_outlined,
                    ),
                  if (s["allowed_periods"] != null)
                    chip(
                      "Allowed periods",
                      s["allowed_periods"],
                      bg: Colors.purple.shade50,
                      fg: Colors.purple.shade800,
                      icon: Icons.timer_outlined,
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
                    chip(
                      "No faculty",
                      "YES",
                      bg: Colors.blueGrey.shade50,
                      fg: Colors.blueGrey.shade800,
                      icon: Icons.person_off_outlined,
                    ),
                  if (s["allow_same_day_repeat"] == true)
                    chip(
                      "Same-day repeat",
                      "YES",
                      bg: Colors.blueGrey.shade50,
                      fg: Colors.blueGrey.shade800,
                      icon: Icons.repeat_rounded,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => openEdit(s),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text(
                      "Edit",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _danger,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => confirmDelete(s),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text(
                      "Delete",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, _navyMid, _navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -25,
            right: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -18,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'View Subjects',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Browse, search, edit and manage subject records',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _miniStat(
                        icon: Icons.apartment_rounded,
                        label: 'Department',
                        value: selectedDepartmentName ?? '-',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _miniStat(
                        icon: Icons.calendar_today_rounded,
                        label: 'Academic Year',
                        value: academicYearController.text.trim().isEmpty
                            ? '-'
                            : academicYearController.text.trim(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: _navy, size: 20),
              SizedBox(width: 8),
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedDepartmentName,
            decoration: _inputDecoration(
              'Department',
              Icons.apartment_rounded,
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
            decoration: _inputDecoration(
              'Academic Year',
              Icons.calendar_month_rounded,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedYear,
                  decoration: _inputDecoration(
                    'Year',
                    Icons.school_outlined,
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
                  decoration: _inputDecoration(
                    'Semester',
                    Icons.layers_outlined,
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
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: loading ? null : loadSubjects,
              icon: Icon(loading ? Icons.hourglass_top_rounded : Icons.search_rounded),
              label: Text(
                loading ? 'Loading...' : 'Load Subjects',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textSub, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: _navy),
      filled: true,
      fillColor: const Color(0xFFF8FBFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _accent, width: 1.3),
      ),
    );
  }

  Widget _buildSearchBar(int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, code or short name',
              hintStyle: const TextStyle(color: _textMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: _navy),
              filled: true,
              fillColor: const Color(0xFFF8FBFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _accent, width: 1.3),
              ),
            ),
            onChanged: (v) => setState(() => searchQuery = v),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 16, color: _textMuted),
              const SizedBox(width: 6),
              Text(
                '$count subject${count == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool searched}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _navy.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                searched ? Icons.search_off_rounded : Icons.menu_book_outlined,
                size: 38,
                color: _navy,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              searched ? 'No matching subjects found' : 'No subjects found',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searched
                  ? "Try another search keyword."
                  : 'Load subjects using the filters above to view records.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _textSub,
                height: 1.45,
              ),
            ),
          ],
        ),
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
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bg,
        foregroundColor: _textPrimary,
        centerTitle: true,
        title: const Text(
          'View Subjects',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: _navy,
                onRefresh: loadSubjects,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    _buildFiltersCard(),
                    const SizedBox(height: 14),
                    if (subjects.isNotEmpty) ...[
                      _buildSearchBar(filtered.length),
                      const SizedBox(height: 14),
                    ],
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 70),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (filtered.isEmpty)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.34,
                        child: _buildEmptyState(
                          searched: subjects.isNotEmpty,
                        ),
                      )
                    else
                      ...List.generate(
                        filtered.length,
                            (i) => Padding(
                          padding: EdgeInsets.only(bottom: i == filtered.length - 1 ? 0 : 12),
                          child: subjectCard(filtered[i]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 6,
        onPressed: () async {
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateSubjectScreen(token: widget.token),
            ),
          );
          if (changed == true) {
            loadSubjects();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Subject',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
