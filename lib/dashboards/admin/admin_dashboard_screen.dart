import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../services/token_service.dart';
import '../../services/app_config.dart';
import 'admin_faculty_screen.dart';
import '../../screens/holidays/holiday_list_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String name;

  const AdminDashboardScreen({
    super.key,
    required this.name,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _generatingTimetable = false;

  // ─── Generate Timetable ───────────────────────────────────────────────────

  Future<void> _generateTimetable() async {
    // Ask for confirmation first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Generate Timetable"),
        content: const Text(
          "This will automatically generate the timetable for all CSE sections.\n\n"
              "Any existing timetable will be replaced.\n\n"
              "Continue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E4D8F),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Generate", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _generatingTimetable = true);

    try {
      final token = await TokenService.getToken();

      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/timetable/generate/sync'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'department_id': 1,       // CSE department id — change if different
          'academic_year': '2025-26',
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        _showResult(
          success: true,
          sectionsCount: data['sections_scheduled'] ?? 0,
          errors: List<String>.from(data['errors'] ?? []),
        );
      } else {
        _showError('Generation failed: ${data['message'] ?? res.body}');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _generatingTimetable = false);
    }
  }

  void _showResult({
    required bool success,
    required int sectionsCount,
    required List<String> errors,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.warning,
              color: success ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text("Timetable Generated"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Sections scheduled: $sectionsCount"),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                "Warnings:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...errors.take(5).map((e) => Text(
                "• $e",
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              )),
              if (errors.length > 5)
                Text("... and ${errors.length - 5} more"),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E4D8F),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text("Error"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // ─── Logout ───────────────────────────────────────────────────────────────

  void logout() async {
    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text("Logout"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TokenService.clearToken();
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
            (route) => false,
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FB),
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: const Color(0xFF1E4D8F),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: logout,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Welcome card ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E4D8F), Color(0xFF4A79B8)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Welcome Admin 👋",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // ── Menu cards ────────────────────────────────────────────
            buildAdminCard(
              icon: Icons.people,
              title: "Manage Faculty",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminFacultyScreen(),
                ),
              ),
            ),

            const SizedBox(height: 15),

            buildAdminCard(
              icon: Icons.event_available,
              title: "Holiday Management",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HolidayListScreen(isAdmin: true),
                ),
              ),
            ),

            const SizedBox(height: 15),

            buildAdminCard(
              icon: Icons.upgrade,
              title: "Upgrade Faculty to HOD",
              onTap: () {},
            ),

            const SizedBox(height: 15),

            buildAdminCard(
              icon: Icons.analytics,
              title: "Attendance Reports",
              onTap: () {},
            ),

            const SizedBox(height: 15),

            // ── NEW: Generate Timetable card ──────────────────────────
            _generatingTimetable
                ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 15),
                  Text(
                    "Generating timetable...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : buildAdminCard(
              icon: Icons.calendar_month,
              title: "Generate Timetable",
              onTap: _generateTimetable,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAdminCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: const Color(0xFF1E4D8F)),
            const SizedBox(width: 15),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}