import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import '../timetable/timetableapp_theme.dart';

class ViewRoomsScreen extends StatefulWidget {
  final String token;
  const ViewRoomsScreen({super.key, required this.token});

  @override
  State<ViewRoomsScreen> createState() => _ViewRoomsScreenState();
}

class _ViewRoomsScreenState extends State<ViewRoomsScreen> {
  final Dio dio = Dio();
  List rooms = [];
  bool loading = true;
  String filter = "ALL";

  Future<void> loadRooms() async {
    setState(() => loading = true);
    try {
      final token = (await TokenService.getUserSession())["token"] ?? widget.token;
      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/rooms",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      setState(() => rooms = res.data is List ? res.data : []);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.response?.data?["detail"]?.toString() ?? "Failed to load rooms"),
        ));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List get filtered => filter == "ALL"
      ? rooms
      : rooms.where((r) => r["room_type"]?.toString() == filter).toList();

  @override
  void initState() {
    super.initState();
    loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    final classroomCount = rooms.where((r) => r["room_type"] == "CLASSROOM").length;
    final labCount = rooms.where((r) => r["room_type"] == "LAB").length;
    final list = filtered;

    return Scaffold(
      backgroundColor: TimetableAppTheme.background,
      appBar: TimetableAppTheme.buildAppBar(context, "Rooms & Labs", actions: [
        IconButton(
          onPressed: loadRooms,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: "Refresh",
        ),
      ]),
      body: Column(
        children: [
          // Stats + filter bar
          Container(
            decoration: const BoxDecoration(
              gradient: TimetableAppTheme.primaryGradient,
            ),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    _StatPill(label: "Classrooms", count: classroomCount, icon: Icons.meeting_room_outlined),
                    const SizedBox(width: 10),
                    _StatPill(label: "Labs", count: labCount, icon: Icons.science_outlined),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: ["ALL", "CLASSROOM", "LAB"].map((type) {
                    final selected = filter == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => filter = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? TimetableAppTheme.primary : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                ? _EmptyState(message: "No ${filter == 'ALL' ? '' : filter.toLowerCase() + ' '}rooms found")
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) => _RoomCard(room: list[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  const _StatPill({required this.label, required this.count, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(
              "$count $label",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final dynamic room;
  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    final isLab = room["room_type"]?.toString() == "LAB";
    final color = isLab ? const Color(0xFF0277BD) : TimetableAppTheme.primary;
    final bgColor = isLab ? const Color(0xFFE1F5FE) : const Color(0xFFE8EDF7);

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
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(13)),
              child: Icon(
                isLab ? Icons.science_outlined : Icons.meeting_room_outlined,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room["name"]?.toString() ?? "-",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: TimetableAppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      _tag(room["room_type"] ?? "-", color: color, bg: bgColor),
                      if (room["capacity"] != null) _tag("Cap: ${room["capacity"]}"),
                      if (room["department_id"] != null) _tag("Dept: ${room["department_id"]}"),
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

  Widget _tag(String label, {Color? color, Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? TimetableAppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TimetableAppTheme.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color ?? TimetableAppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.meeting_room_outlined, size: 60, color: TimetableAppTheme.textHint.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: TimetableAppTheme.textHint, fontSize: 15)),
        ],
      ),
    );
  }
}