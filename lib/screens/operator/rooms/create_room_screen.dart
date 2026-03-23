import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/token_service.dart';
import '../../../widgets/app_page_shell.dart';
import '../../../widgets/app_primary_button.dart';
import '../../../widgets/app_text_field.dart';

class CreateRoomScreen extends StatefulWidget {
  final String token;

  const CreateRoomScreen({super.key, required this.token});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final Dio dio = Dio();

  final departmentIdController = TextEditingController();
  final roomNameController = TextEditingController();
  final capacityController = TextEditingController();

  String roomType = "CLASSROOM";
  bool loading = false;

  Future<void> createRoom() async {
    if (roomNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Room name is required")),
      );
      return;
    }

    try {
      setState(() => loading = true);

      final token =
          (await TokenService.getUserSession())["token"] ?? widget.token;

      await dio.post(
        "${ApiService.baseUrl}/timetable/rooms",
        data: {
          "department_id": departmentIdController.text.trim().isEmpty
              ? null
              : int.tryParse(departmentIdController.text.trim()),
          "name": roomNameController.text.trim(),
          "room_type": roomType,
          "capacity": capacityController.text.trim().isEmpty
              ? null
              : int.tryParse(capacityController.text.trim()),
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (!mounted) return;

      // Reset form
      roomNameController.clear();
      capacityController.clear();
      setState(() => roomType = "CLASSROOM");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Room created successfully")),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      // FIX: show actual backend error
      final msg = e.response?.data?["detail"]?.toString() ??
          "Failed to create room";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    departmentIdController.dispose();
    roomNameController.dispose();
    capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: "Create Room",
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Examples:\n"
                    "• Classroom: BGB-111, BGB-204, BGB-212\n"
                    "• Lab: LAB-1, LAB-2, LAB-3, CNS-LAB\n\n"
                    "Create all rooms and labs first before creating sections and subjects.",
                style: TextStyle(height: 1.5),
              ),
            ),
            const SizedBox(height: 16),

            AppTextField(
              controller: departmentIdController,
              label: "Department ID (optional)",
              hint: "Leave empty for shared rooms/labs",
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: roomNameController,
              label: "Room Name",
              hint: "e.g. BGB-111 or LAB-1",
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: roomType,
              decoration: const InputDecoration(
                labelText: "Room Type",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: "CLASSROOM",
                  child: Text("CLASSROOM — regular teaching room"),
                ),
                DropdownMenuItem(
                  value: "LAB",
                  child: Text("LAB — lab session room"),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => roomType = value);
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: capacityController,
              label: "Capacity (optional)",
              hint: "e.g. 60",
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              text: "Create Room",
              loading: loading,
              onPressed: createRoom,
            ),
          ],
        ),
      ),
    );
  }
}