import 'package:flutter/material.dart';
import '../../screens/holidays/holiday_list_screen.dart';
import '../../screens/leave/leave_approval_screen.dart';
import '../../screens/leave/leave_history_screen.dart';
import '../../screens/attendance/attendance_menu_screen.dart';
import '../../services/api_service.dart';
import 'dart:async';

class HodDashboardScreen extends StatefulWidget {
  final String name;
  final String department;

  const HodDashboardScreen({
    super.key,
    required this.name,
    required this.department,
  });

  @override
  State<HodDashboardScreen> createState() => _HodDashboardScreenState();
}

class _HodDashboardScreenState extends State<HodDashboardScreen> {

  Timer? statsTimer;
  List todayLeaves = [];
  bool loadingLeaves = true;

  Map stats = {};
  bool loadingStats = true;

  Future loadStats() async {

    try {

      final data = await ApiService.getLeaveStats();

      setState(() {
        stats = data;
        loadingStats = false;
      });

    } catch (e) {
      setState(() {
        loadingStats = false;
      });
    }

  }

  @override
  void initState() {
    super.initState();

    loadTodayLeaves();
    loadStats();

    /// auto refresh every 20 seconds
    statsTimer = Timer.periodic(
      const Duration(seconds: 20),
          (timer) {
        loadStats();
        loadTodayLeaves();
      },
    );
  }

  Future<void> loadTodayLeaves() async {
    try {

      final data = await ApiService.getTodayDepartmentLeaves();

      setState(() {
        todayLeaves = data;
        loadingLeaves = false;
      });

    } catch (e) {

      setState(() {
        loadingLeaves = false;
      });

    }
  }

  void logout(BuildContext context) {

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [

          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),

          ElevatedButton(
            onPressed: () {

              Navigator.pop(context);

              Navigator.pushNamedAndRemoveUntil(
                context,
                "/login",
                    (route) => false,
              );

            },
            child: const Text("Logout"),
          ),

        ],
      ),
    );

  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FB),

      appBar: AppBar(
        title: const Text("HOD Dashboard"),
        backgroundColor: const Color(0xFF1E4D8F),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              logout(context);
            },
          )
        ],
      ),

        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                "Welcome ${widget.name}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                "Department: ${widget.department}",
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 30),

              const SizedBox(height: 25),

              /// Faculty On Leave Today
              if (loadingLeaves)
                const Center(child: CircularProgressIndicator()),

              if (!loadingLeaves && todayLeaves.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const Text(
                        "Faculty on Leave Today",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 10),

                      ...todayLeaves.map((leave) {

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),

                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(10),
                          ),

                          child: Row(
                            children: [

                              const Icon(Icons.event_busy, color: Colors.red),

                              const SizedBox(width: 10),

                              Expanded(
                                child: Text(
                                  "${leave["faculty_name"]}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              Text(
                                leave["leave_type"],
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),

                            ],
                          ),
                        );

                      }).toList()

                  ],
                ),
              ),

              /// Attendance (same as faculty)
              buildCard(
                icon: Icons.access_time,
                title: "My Attendance",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AttendanceMenuScreen(
                        email: "", // use logged email if needed
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 15),

              /// My Leave
              buildCard(
                icon: Icons.event_note,
                title: "My Leaves",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeaveHistoryScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 15),

              /// Leave Requests
              buildCard(
                icon: Icons.assignment,
                title: "Leave Requests",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeaveApprovalScreen(role: "hod"),
                    ),
                  );
                },
              ),

              const SizedBox(height: 15),

              buildCard(
                icon: Icons.calendar_month, 
                title: "Holidays",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HolidayListScreen(isAdmin: false),
                    ),
                  );
                },
              ),

              const SizedBox(height: 15),

              /// Department Faculty
              buildCard(
                icon: Icons.people,
                title: "Department Faculty",
                onTap: () {
                  // next feature
                },
              ),

              const SizedBox(height: 15),

              /// Department Attendance
              buildCard(
                icon: Icons.bar_chart,
                title: "Department Attendance",
                onTap: () {
                  // next feature
                },
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget buildCard({
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
  Widget statItem(String title, String value) {

    return Column(
      children: [

        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E4D8F),
          ),
        ),

        const SizedBox(height: 4),

        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),

      ],
    );

  }

  @override
  void dispose() {
    statsTimer?.cancel();
    super.dispose();
  }
}
