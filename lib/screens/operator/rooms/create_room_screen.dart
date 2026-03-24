import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import '../timetable/departmentdropdown.dart';
import '../timetable/timetableapp_theme.dart';

class CreateRoomScreen extends StatefulWidget {
  final String token;
  const CreateRoomScreen({super.key, required this.token});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final Dio dio = Dio();

  int? selectedDepartmentId;
  final roomNameController = TextEditingController();
  final capacityController = TextEditingController();

  String roomType = "CLASSROOM";
  bool loading = false;

  Future<void> createRoom() async {
    final name = roomNameController.text.trim();
    if (name.isEmpty) {
      _snack("Room name is required");
      return;
    }

    setState(() => loading = true);
    try {
      final token = (await TokenService.getUserSession())["token"] ?? widget.token;
      await dio.post(
        "${ApiService.baseUrl}/timetable/rooms",
        data: {
          "department_id": selectedDepartmentId,
          "name": name,
          "room_type": roomType,
          "capacity": capacityController.text.trim().isEmpty
              ? null
              : int.tryParse(capacityController.text.trim()),
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (!mounted) return;
      roomNameController.clear();
      capacityController.clear();
      setState(() => roomType = "CLASSROOM");
      _snack("Room created successfully ✓", success: true);
    } on DioException catch (e) {
      if (!mounted) return;
      _snack(e.response?.data?["detail"]?.toString() ?? "Failed to create room");
    } catch (e) {
      if (!mounted) return;
      _snack("Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? TimetableAppTheme.success : null,
    ));
  }

  @override
  void dispose() {
    roomNameController.dispose();
    capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TimetableAppTheme.background,
      appBar: TimetableAppTheme.buildAppBar(context, "Create Room"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TimetableAppTheme.infoBanner(
              "Examples:\n"
                  "• Classroom: BGB-111, BGB-204, BGB-212\n"
                  "• Lab: LAB-1, LAB-2, LAB-3, CNS-LAB\n\n"
                  "Create all rooms and labs before creating sections.",
            ),
            const SizedBox(height: 16),

            TimetableAppTheme.card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TimetableAppTheme.sectionHeader("Room Details"),
                  const SizedBox(height: 4),

                  // Department (optional)
                  DepartmentDropdown(
                    token: widget.token,
                    value: selectedDepartmentId,
                    label: "Department (optional — leave if shared)",
                    onChanged: (id, _) => setState(() => selectedDepartmentId = id),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: roomNameController,
                    decoration: TimetableAppTheme.inputDecoration(
                      "Room Name",
                      hint: "e.g. BGB-111 or LAB-1",
                      prefixIcon: const Icon(Icons.meeting_room_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Room type chips
                  TimetableAppTheme.sectionHeader("Room Type"),
                  Row(
                    children: ["CLASSROOM", "LAB"].map((type) {
                      final selected = roomType == type;
                      final isLab = type == "LAB";
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: isLab ? 0 : 8),
                          child: GestureDetector(
                            onTap: () => setState(() => roomType = type),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: selected ? TimetableAppTheme.primaryGradient : null,
                                color: selected ? null : TimetableAppTheme.surfaceAlt,
                                borderRadius: BorderRadius.circular(TimetableAppTheme.radiusMd),
                                border: Border.all(
                                  color: selected ? Colors.transparent : TimetableAppTheme.border,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isLab ? Icons.science_outlined : Icons.meeting_room_outlined,
                                    size: 18,
                                    color: selected ? Colors.white : TimetableAppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    type,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: selected ? Colors.white : TimetableAppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    decoration: TimetableAppTheme.inputDecoration(
                      "Capacity (optional)",
                      hint: "e.g. 60",
                      prefixIcon: const Icon(Icons.people_outline, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            TimetableAppTheme.primaryButton(
              text: "Create Room",
              loading: loading,
              onPressed: createRoom,
              icon: Icons.add_circle_outline,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}