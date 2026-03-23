import 'package:flutter/material.dart';
import '../../services/token_service.dart';

import 'rooms/create_room_screen.dart';
import 'rooms/view_rooms_screen.dart';
import 'sections/create_section_screen.dart';
import 'sections/view_sections_screen.dart';
import 'subjects/create_subject_screen.dart';
import 'subjects/view_subjects_screen.dart';
import 'mappings/create_mapping_screen.dart';
import 'mappings/view_mappings_screen.dart';
import 'timetable/generate_timetable_screen.dart';
import 'timetable/view_faculty_timetable_screen.dart';
import 'timetable/view_section_timetable_screen.dart';

class OperatorDashboardScreen extends StatelessWidget {
  final String name;
  final String department;
  final String token;

  const OperatorDashboardScreen({
    super.key,
    required this.name,
    required this.department,
    required this.token,
  });

  void open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> logout(BuildContext context) async {
    await TokenService.clearToken();

    if (!context.mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      "/login",
          (route) => false,
    );
  }

  Widget tile(
      BuildContext context, {
        required String title,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFEAF2FF),
              child: Icon(icon, color: Colors.indigo),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (
      "Create Room",
      Icons.meeting_room_outlined,
      CreateRoomScreen(token: token),
      ),
      (
      "View Rooms",
      Icons.domain_outlined,
      ViewRoomsScreen(token: token),
      ),
      (
      "Create Section",
      Icons.class_outlined,
      CreateSectionScreen(token: token),
      ),
      (
      "View Sections",
      Icons.view_list_outlined,
      ViewSectionsScreen(token: token),
      ),
      (
      "Create Subject",
      Icons.menu_book_outlined,
      CreateSubjectScreen(token: token),
      ),
      (
      "View Subjects",
      Icons.library_books_outlined,
      ViewSubjectsScreen(token: token),
      ),
      (
      "Create Faculty Mapping",
      Icons.people_alt_outlined,
      CreateFacultyMappingScreen(token: token),
      ),
      (
      "View Faculty Mappings",
      Icons.account_tree_outlined,
      ViewMappingsScreen(token: token),
      ),
      (
      "Generate Timetable",
      Icons.auto_awesome_outlined,
      GenerateTimetableScreen(token: token),
      ),
      (
      "View Section Timetable",
      Icons.grid_view_rounded,
      ViewSectionTimetableScreen(token: token),
      ),
      (
      "View Faculty Timetable",
      Icons.badge_outlined,
      ViewFacultyTimetableScreen(token: token),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text("Operator Dashboard"),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome, $name",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Department: $department",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return tile(
                  context,
                  title: item.$1,
                  icon: item.$2,
                  onTap: () => open(context, item.$3),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}