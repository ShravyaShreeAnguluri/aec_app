import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';

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
  String filter = "ALL"; // ALL / CLASSROOM / LAB

  Future<void> loadRooms() async {
    try {
      setState(() => loading = true);

      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;

      final res = await dio.get(
        "${ApiService.baseUrl}/timetable/rooms",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      setState(() {
        rooms = res.data is List ? res.data : [];
      });
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?["detail"]?.toString() ??
            "Failed to load rooms";
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

  List get filteredRooms {
    if (filter == "ALL") return rooms;
    return rooms
        .where((r) => r["room_type"]?.toString() == filter)
        .toList();
  }

  Widget roomCard(dynamic room) {
    final isLab = room["room_type"]?.toString() == "LAB";

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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isLab
                  ? const Color(0xFFE1F5FE)
                  : const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isLab ? Icons.science_outlined : Icons.meeting_room_outlined,
              color: isLab
                  ? const Color(0xFF0277BD)
                  : const Color(0xFF4527A0),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room["name"]?.toString() ?? "-",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLab
                            ? const Color(0xFFE1F5FE)
                            : const Color(0xFFEDE7F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        room["room_type"] ?? "-",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isLab
                              ? const Color(0xFF0277BD)
                              : const Color(0xFF4527A0),
                        ),
                      ),
                    ),
                    if (room["capacity"] != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        "Cap: ${room["capacity"]}",
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                    if (room["department_id"] != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        "Dept: ${room["department_id"]}",
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredRooms;
    final classroomCount =
        rooms.where((r) => r["room_type"] == "CLASSROOM").length;
    final labCount = rooms.where((r) => r["room_type"] == "LAB").length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text("Rooms & Labs"),
        actions: [
          IconButton(
            onPressed: loadRooms,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary + Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  "$classroomCount classroom${classroomCount == 1 ? '' : 's'}, "
                      "$labCount lab${labCount == 1 ? '' : 's'}",
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF94A3B8)),
                ),
                const Spacer(),
                ...["ALL", "CLASSROOM", "LAB"].map((type) {
                  final selected = filter == type;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      label: Text(type),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => filter = type),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? const Center(child: Text("No rooms found"))
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  roomCard(filtered[index]),
            ),
          ),
        ],
      ),
    );
  }
}