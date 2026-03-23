import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';

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
    try {
      setState(() => loading = true);

      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;

      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/faculty-subject-map",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      setState(() {
        mappings = res.data is List ? res.data : [];
      });
    } on DioException catch (e) {
      if (mounted) {
        // FIX: show actual error
        final msg = e.response?.data?["detail"]?.toString() ??
            "Failed to load mappings";
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List get filteredMappings {
    if (searchQuery.trim().isEmpty) return mappings;
    final q = searchQuery.trim().toLowerCase();
    return mappings.where((m) {
      final name = (m["faculty_name"] ?? "").toString().toLowerCase();
      final subj = (m["subject_name"] ?? "").toString().toLowerCase();
      final pid = (m["faculty_public_id"] ?? "").toString().toLowerCase();
      return name.contains(q) || subj.contains(q) || pid.contains(q);
    }).toList();
  }

  Widget infoChip(String label, dynamic value) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$label: ${value ?? '-'}",
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget boolChip(String label, bool value) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: value
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$label: ${value ? "Yes" : "No"}",
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: value ? Colors.green.shade800 : Colors.red.shade800,
        ),
      ),
    );
  }

  Widget mappingCard(dynamic m, int index) {
    final canHandleLab = m["can_handle_lab"] == true;
    final isPrimary = m["is_primary"] == true;

    // FIX: use human-readable names from backend response
    final facultyDisplay =
        "${m["faculty_name"] ?? "Unknown"} (${m["faculty_public_id"] ?? "-"})";
    final subjectDisplay =
        "${m["subject_name"] ?? "Unknown"} [${m["subject_short_name"] ?? m["subject_code"] ?? "-"}]";

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
          // FIX: show faculty name prominently instead of just "Mapping N"
          Row(
            children: [
              const Icon(Icons.person, size: 18, color: Color(0xFF4A90D9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  facultyDisplay,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B4A),
                  ),
                ),
              ),
              if (isPrimary)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Primary",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.menu_book, size: 15, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subjectDisplay,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            children: [
              infoChip("Priority", m["priority"]),
              infoChip("Max/Week", m["max_hours_per_week"]),
              infoChip("Max/Day", m["max_hours_per_day"]),
              boolChip("Can Handle Lab", canHandleLab),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadMappings();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredMappings;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text("Faculty Subject Mappings"),
        actions: [
          IconButton(
            onPressed: loadMappings,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                labelText: "Search by faculty name or subject",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "${filtered.length} mapping${filtered.length == 1 ? '' : 's'}",
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
              child: Text(searchQuery.isEmpty
                  ? "No mappings found"
                  : "No results for '$searchQuery'"),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 12),
              itemBuilder: (_, i) =>
                  mappingCard(filtered[i], i),
            ),
          ),
        ],
      ),
    );
  }
}