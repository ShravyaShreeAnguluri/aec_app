import 'package:faculty_app/screens/operator/timetable/timetableapp_theme.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import 'departmentdropdown.dart';

class ViewFacultyTimetableScreen extends StatefulWidget {
  final String token;
  const ViewFacultyTimetableScreen({super.key, required this.token});

  @override
  State<ViewFacultyTimetableScreen> createState() => _ViewFacultyTimetableScreenState();
}

class _ViewFacultyTimetableScreenState extends State<ViewFacultyTimetableScreen> {
  final Dio dio = Dio();

  int? selectedDepartmentId;
  String? selectedfacultyPublicId;
  String? selectedfacultyName;

  List schedule = [];
  String facultyNameFromAPI = "";
  bool loading = false;

  final List<String> dayNames = const ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

  static const List<Color> _subjectColors = [
    Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFFE65100),
    Color(0xFFC62828), Color(0xFF6A1B9A), Color(0xFF00695C),
    Color(0xFF558B2F), Color(0xFF4527A0),
  ];

  Color _colorForSubject(String? subject) {
    if (subject == null || subject.isEmpty) return _subjectColors[0];
    return _subjectColors[subject.codeUnitAt(0) % _subjectColors.length];
  }

  Future<void> loadfacultyTimetable() async {
    if (selectedfacultyPublicId == null) { _snack("Please select a faculty member"); return; }

    setState(() => loading = true);
    try {
      final token = (await TokenService.getUserSession())["token"] ?? widget.token;
      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/faculty/$selectedfacultyPublicId/schedule",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      final data = Map<String, dynamic>.from(res.data);
      setState(() {
        facultyNameFromAPI = data["faculty_name"]?.toString() ?? selectedfacultyName ?? "";
        schedule = data["schedule"] is List ? data["schedule"] : [];
      });
    } on DioException catch (e) {
      schedule = [];
      if (mounted) _snack(e.response?.data?["detail"]?.toString() ?? "Failed to load timetable");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildTimetableGrid() {
    final Set<int> periodSet = {};
    final Set<int> daySet = {};
    for (final item in schedule) {
      if (item["period"] != null) periodSet.add(item["period"] as int);
      if (item["day_index"] != null) daySet.add(item["day_index"] as int);
    }
    final periods = periodSet.toList()..sort();
    final days = daySet.toList()..sort();

    if (periods.isEmpty || days.isEmpty) {
      return const SizedBox.shrink();
    }

    final Map<String, dynamic> cellMap = {};
    for (final item in schedule) {
      cellMap["${item["day_index"]}_${item["period"]}"] = item;
    }

    return TimetableAppTheme.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TimetableAppTheme.sectionHeader("Weekly Grid"),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(color: TimetableAppTheme.border, borderRadius: BorderRadius.circular(8)),
              children: [
                TableRow(
                  decoration: const BoxDecoration(gradient: TimetableAppTheme.primaryGradient),
                  children: [
                    _hCell(""),
                    for (final d in days)
                      _hCell(d < dayNames.length ? dayNames[d] : "D$d"),
                  ],
                ),
                for (final p in periods)
                  TableRow(
                    decoration: BoxDecoration(
                      color: periods.indexOf(p).isEven ? Colors.white : TimetableAppTheme.surfaceAlt,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        child: Text("P${p + 1}",
                            style: const TextStyle(color: TimetableAppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                      for (final d in days) _gridCell(cellMap["${d}_$p"]),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
          textAlign: TextAlign.center),
    );
  }

  Widget _gridCell(dynamic item) {
    if (item == null) return const SizedBox(width: 90, height: 44);
    final subject = item["subject_abbr"]?.toString() ?? item["slot_type"]?.toString() ?? "-";
    final section = item["section_name"]?.toString() ?? "";
    final color = _colorForSubject(subject);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subject, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                overflow: TextOverflow.ellipsis),
            if (section.isNotEmpty)
              Text(section, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _scheduleCard(dynamic item) {
    final subject = item["subject_abbr"]?.toString() ?? item["slot_type"]?.toString() ?? "-";
    final color = _colorForSubject(subject);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TimetableAppTheme.radiusLg),
        boxShadow: TimetableAppTheme.cardShadow,
        border: Border.all(color: TimetableAppTheme.border.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text(
                  subject.length > 3 ? subject.substring(0, 3) : subject,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item["subject"]?.toString() ?? subject,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: TimetableAppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 10, children: [
                    _chip(Icons.calendar_today_outlined, item["day_index"] != null && (item["day_index"] as int) < dayNames.length ? dayNames[item["day_index"]] : "-"),
                    _chip(Icons.access_time_outlined, "Period ${(item["period"] ?? 0) + 1}"),
                    _chip(Icons.group_outlined, item["section_name"]?.toString() ?? "-"),
                    _chip(Icons.meeting_room_outlined, item["room"]?.toString() ?? "-"),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: TimetableAppTheme.textHint),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 12, color: TimetableAppTheme.textSecondary)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TimetableAppTheme.background,
      appBar: TimetableAppTheme.buildAppBar(context, "faculty Timetable"),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: TimetableAppTheme.primaryGradient),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              children: [
                DepartmentDropdown(
                  token: widget.token,
                  value: selectedDepartmentId,
                  label: "Department",
                  onChanged: (id, _) => setState(() {
                    selectedDepartmentId = id;
                    selectedfacultyPublicId = null;
                    selectedfacultyName = null;
                    schedule = [];
                  }),
                ),
                const SizedBox(height: 10),
                FacultyDropdown(
                  token: widget.token,
                  departmentId: selectedDepartmentId,
                  value: selectedfacultyPublicId,
                  label: "Select faculty",
                  onChanged: (pid, name) => setState(() {
                    selectedfacultyPublicId = pid;
                    selectedfacultyName = name;
                    schedule = [];
                  }),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (loading || selectedfacultyPublicId == null) ? null : loadfacultyTimetable,
                    icon: loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: TimetableAppTheme.primary))
                        : const Icon(Icons.badge_outlined, size: 18),
                    label: const Text("Load Timetable"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: TimetableAppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TimetableAppTheme.radiusMd)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (facultyNameFromAPI.isNotEmpty)
            Container(
              color: TimetableAppTheme.accentLight.withOpacity(0.6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                const Icon(Icons.person, color: TimetableAppTheme.primaryLight, size: 18),
                const SizedBox(width: 8),
                Text(facultyNameFromAPI,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TimetableAppTheme.textPrimary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: TimetableAppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text("${schedule.length} slots",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : schedule.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_outlined, size: 60, color: TimetableAppTheme.textHint.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  const Text("Select a faculty member to view timetable",
                      style: TextStyle(color: TimetableAppTheme.textHint)),
                ],
              ),
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimetableGrid(),
                  const SizedBox(height: 14),
                  TimetableAppTheme.sectionHeader("All Slots"),
                  const SizedBox(height: 4),
                  ...schedule.map(_scheduleCard),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}