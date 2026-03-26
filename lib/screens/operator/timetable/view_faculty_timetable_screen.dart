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
  State<ViewFacultyTimetableScreen> createState() =>
      _ViewFacultyTimetableScreenState();
}

class _ViewFacultyTimetableScreenState
    extends State<ViewFacultyTimetableScreen> {
  final Dio dio = Dio();

  int? selectedDepartmentId;
  String? selectedfacultyPublicId;
  String? selectedfacultyName;

  List schedule = [];
  String facultyNameFromAPI = "";
  bool loading = false;

  final List<String> dayNames = const [
    "Mon",
    "Tue",
    "Wed",
    "Thu",
    "Fri",
    "Sat"
  ];

  static const List<Color> _subjectColors = [
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFE65100),
    Color(0xFFC62828),
    Color(0xFF6A1B9A),
    Color(0xFF00695C),
    Color(0xFF558B2F),
    Color(0xFF4527A0),
  ];

  Color _colorForSubject(String? subject) {
    if (subject == null || subject.isEmpty) return _subjectColors[0];
    return _subjectColors[subject.codeUnitAt(0) % _subjectColors.length];
  }

  Future<void> loadfacultyTimetable() async {
    if (selectedfacultyPublicId == null) {
      _snack("Please select a faculty member");
      return;
    }

    setState(() => loading = true);
    try {
      final token = (await TokenService.getUserSession())["token"] ??
          widget.token;
      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/faculty/$selectedfacultyPublicId/schedule",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      final data = Map<String, dynamic>.from(res.data);
      setState(() {
        facultyNameFromAPI =
            data["faculty_name"]?.toString() ?? selectedfacultyName ?? "";
        schedule = data["schedule"] is List ? data["schedule"] : [];
      });
    } on DioException catch (e) {
      setState(() => schedule = []);
      if (mounted) {
        _snack(e.response?.data?["detail"]?.toString() ??
            "Failed to load timetable");
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int get _uniqueDayCount {
    final set = <int>{};
    for (final item in schedule) {
      if (item["day_index"] is int) set.add(item["day_index"] as int);
    }
    return set.length;
  }

  int get _uniqueSectionCount {
    final set = <String>{};
    for (final item in schedule) {
      final value = item["section_name"]?.toString() ?? "";
      if (value.isNotEmpty) set.add(value);
    }
    return set.length;
  }

  Widget _buildHeroCard() {
    final displayName = facultyNameFromAPI.isNotEmpty
        ? facultyNameFromAPI
        : (selectedfacultyName ?? "Faculty Timetable");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: TimetableAppTheme.primary.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.school_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Faculty Timetable",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Weekly schedule for ${displayName.toUpperCase()}",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 12,
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
                child: _statCard(
                  Icons.grid_view_rounded,
                  "${schedule.length}",
                  "Slots",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  Icons.calendar_today_rounded,
                  "${_uniqueDayCount}",
                  "Days",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  Icons.groups_2_rounded,
                  "${_uniqueSectionCount}",
                  "Sections",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: TimetableAppTheme.primary, size: 18),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: TimetableAppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: TimetableAppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return TimetableAppTheme.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune_rounded,
                  color: TimetableAppTheme.primaryLight, size: 18),
              SizedBox(width: 8),
              Text(
                "Filter Faculty",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: TimetableAppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DepartmentDropdown(
            token: widget.token,
            value: selectedDepartmentId,
            label: "Department",
            onChanged: (id, _) => setState(() {
              selectedDepartmentId = id;
              selectedfacultyPublicId = null;
              selectedfacultyName = null;
              facultyNameFromAPI = "";
              schedule = [];
            }),
          ),
          const SizedBox(height: 12),
          FacultyDropdown(
            token: widget.token,
            departmentId: selectedDepartmentId,
            value: selectedfacultyPublicId,
            label: "Select faculty",
            onChanged: (pid, name) => setState(() {
              selectedfacultyPublicId = pid;
              selectedfacultyName = name;
              facultyNameFromAPI = "";
              schedule = [];
            }),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (loading || selectedfacultyPublicId == null)
                  ? null
                  : loadfacultyTimetable,
              icon: loading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.badge_outlined, size: 18),
              label: Text(loading ? "Loading..." : "Load Timetable"),
              style: ElevatedButton.styleFrom(
                backgroundColor: TimetableAppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                TimetableAppTheme.primary.withOpacity(0.45),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(TimetableAppTheme.radiusMd),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedFacultyCard() {
    if (facultyNameFromAPI.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: TimetableAppTheme.accentLight.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: TimetableAppTheme.primary.withOpacity(0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_rounded,
              color: TimetableAppTheme.primaryLight, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              facultyNameFromAPI,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: TimetableAppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: TimetableAppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "${schedule.length} slots",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(
                color: TimetableAppTheme.border,
                borderRadius: BorderRadius.circular(10),
              ),
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    gradient: TimetableAppTheme.primaryGradient,
                  ),
                  children: [
                    _hCell(""),
                    for (final d in days)
                      _hCell(d < dayNames.length ? dayNames[d] : "D$d"),
                  ],
                ),
                for (final p in periods)
                  TableRow(
                    decoration: BoxDecoration(
                      color: periods.indexOf(p).isEven
                          ? Colors.white
                          : TimetableAppTheme.surfaceAlt,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 10),
                        child: Text(
                          "P${p + 1}",
                          style: const TextStyle(
                            color: TimetableAppTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
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
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _gridCell(dynamic item) {
    if (item == null) return const SizedBox(width: 110, height: 66);
    final subject =
        item["subject_abbr"]?.toString() ?? item["slot_type"]?.toString() ?? "-";
    final section = item["section_name"]?.toString() ?? "";
    final color = _colorForSubject(subject);
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Container(
        constraints: const BoxConstraints(minWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            if (section.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                section,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color.withOpacity(0.85),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scheduleCard(dynamic item) {
    final subject =
        item["subject_abbr"]?.toString() ?? item["slot_type"]?.toString() ?? "-";
    final color = _colorForSubject(subject);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TimetableAppTheme.radiusLg),
        boxShadow: TimetableAppTheme.cardShadow,
        border: Border.all(
          color: TimetableAppTheme.border.withOpacity(0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  subject.length > 3 ? subject.substring(0, 3) : subject,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item["subject"]?.toString() ?? subject,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: TimetableAppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metaChip(
                        Icons.calendar_today_outlined,
                        item["day_index"] != null &&
                            (item["day_index"] as int) < dayNames.length
                            ? dayNames[item["day_index"]]
                            : "-",
                      ),
                      _metaChip(
                        Icons.access_time_outlined,
                        "Period ${(item["period"] ?? 0) + 1}",
                      ),
                      _metaChip(
                        Icons.group_outlined,
                        item["section_name"]?.toString() ?? "-",
                      ),
                      _metaChip(
                        Icons.meeting_room_outlined,
                        item["room"]?.toString() ?? "-",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TimetableAppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TimetableAppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: TimetableAppTheme.textHint),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: TimetableAppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        children: [
          Icon(
            Icons.badge_outlined,
            size: 62,
            color: TimetableAppTheme.textHint.withOpacity(0.40),
          ),
          const SizedBox(height: 12),
          const Text(
            "Select a faculty member to view timetable",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: TimetableAppTheme.textHint,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TimetableAppTheme.background,
      appBar: TimetableAppTheme.buildAppBar(context, "Faculty Timetable"),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(),
              const SizedBox(height: 14),
              _buildFilterCard(),
              const SizedBox(height: 14),
              _buildSelectedFacultyCard(),
              if (facultyNameFromAPI.isNotEmpty)
                const SizedBox(height: 14),
              if (schedule.isEmpty) ...[
                _buildEmptyState(),
              ] else ...[
                _buildTimetableGrid(),
                const SizedBox(height: 14),
                TimetableAppTheme.sectionHeader("All Slots"),
                const SizedBox(height: 8),
                ...schedule.map(_scheduleCard),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
