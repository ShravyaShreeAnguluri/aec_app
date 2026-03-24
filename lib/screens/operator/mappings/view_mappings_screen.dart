import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import '../timetable/timetableapp_theme.dart';

class ViewMappingsScreen extends StatefulWidget {
  final String token;
  const ViewMappingsScreen({super.key, required this.token});

  @override
  State<ViewMappingsScreen> createState() => _ViewMappingsScreenState();
}

class _ViewMappingsScreenState extends State<ViewMappingsScreen> {
  final Dio dio = Dio();
  List mappings = [];
  bool loading = true;
  String searchQuery = "";

  Future<void> loadMappings() async {
    setState(() => loading = true);
    try {
      final token = (await TokenService.getUserSession())["token"] ?? widget.token;
      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/faculty-subject-map",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      setState(() => mappings = res.data is List ? res.data : []);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.response?.data?["detail"]?.toString() ?? "Failed to load mappings"),
        ));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List get filtered {
    if (searchQuery.trim().isEmpty) return mappings;
    final q = searchQuery.trim().toLowerCase();
    return mappings.where((m) {
      return (m["faculty_name"] ?? "").toString().toLowerCase().contains(q) ||
          (m["subject_name"] ?? "").toString().toLowerCase().contains(q) ||
          (m["faculty_public_id"] ?? "").toString().toLowerCase().contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    loadMappings();
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    return Scaffold(
      backgroundColor: TimetableAppTheme.background,
      appBar: TimetableAppTheme.buildAppBar(context, "Faculty Mappings", actions: [
        IconButton(
          onPressed: loadMappings,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: "Refresh",
        ),
      ]),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: TimetableAppTheme.primaryGradient),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search by faculty name or subject…",
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TimetableAppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
          ),

          if (mappings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${list.length} mapping${list.length == 1 ? '' : 's'}",
                  style: const TextStyle(fontSize: 12, color: TimetableAppTheme.textHint),
                ),
              ),
            ),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                ? Center(
              child: Text(
                searchQuery.isEmpty ? "No mappings found" : "No results for '$searchQuery'",
                style: const TextStyle(color: TimetableAppTheme.textHint),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) => _MappingCard(mapping: list[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MappingCard extends StatelessWidget {
  final dynamic mapping;
  const _MappingCard({required this.mapping});

  @override
  Widget build(BuildContext context) {
    final m = mapping;
    final isPrimary = m["is_primary"] == true;
    final canHandleLab = m["can_handle_lab"] == true;
    final facultyDisplay = "${m["faculty_name"] ?? "Unknown"}  (${m["faculty_public_id"] ?? "-"})";
    final subjectDisplay = "${m["subject_name"] ?? "Unknown"} [${m["subject_short_name"] ?? m["subject_code"] ?? "-"}]";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TimetableAppTheme.radiusLg),
        boxShadow: TimetableAppTheme.cardShadow,
        border: Border.all(color: TimetableAppTheme.border.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: TimetableAppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.person_outline, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    facultyDisplay,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: TimetableAppTheme.textPrimary,
                    ),
                  ),
                ),
                if (isPrimary)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: const Text(
                      "Primary",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TimetableAppTheme.success),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.menu_book_outlined, size: 15, color: TimetableAppTheme.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    subjectDisplay,
                    style: const TextStyle(fontSize: 13, color: TimetableAppTheme.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              children: [
                TimetableAppTheme.infoChip("Priority", m["priority"]),
                TimetableAppTheme.infoChip("Max/Week", "${m["max_hours_per_week"]} hrs"),
                TimetableAppTheme.infoChip("Max/Day", "${m["max_hours_per_day"]} hrs"),
                TimetableAppTheme.boolChip("Lab", canHandleLab),
              ],
            ),
          ],
        ),
      ),
    );
  }
}