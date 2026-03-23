import 'package:flutter/material.dart';
import '../../screens/holidays/holiday_list_screen.dart';
import '../../screens/leave/leave_approval_screen.dart';
import '../../screens/leave/leave_history_screen.dart';
import '../../screens/attendance/attendance_menu_screen.dart';
import '../../services/api_service.dart';

class DeanDashboardScreen extends StatefulWidget {
  final String name;

  const DeanDashboardScreen({
    super.key,
    required this.name,
  });

  @override
  State<DeanDashboardScreen> createState() => _DeanDashboardScreenState();
}

class _DeanDashboardScreenState extends State<DeanDashboardScreen> {
  List todayLeaves = [];
  bool loadingLeaves = true;

  @override
  void initState() {
    super.initState();
    loadTodayLeaves();
  }

  Future<void> loadTodayLeaves() async {

    try {

      final data = await ApiService.getTodayHodLeaves();

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
        title: const Text("Dean Dashboard"),
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

      body: Padding(
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

            const SizedBox(height: 20),

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
                      "HODs on Leave Today",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    ...todayLeaves.map((leave) {

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),

                        child: Row(
                          children: [

                            const Icon(Icons.person, size: 18),

                            const SizedBox(width: 8),

                            Text(
                              "${leave["faculty_name"]} • ${leave["leave_type"]}",
                            ),

                          ],
                        ),
                      );

                    }).toList()

                  ],
                ),
              ),
            
            const SizedBox(height: 30),

            buildCard(
              icon: Icons.access_time,
              title: "My Attendance",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttendanceMenuScreen(email: ""),
                  ),
                );
              },
            ),

            const SizedBox(height: 15),

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

            buildCard(
              icon: Icons.assignment,
              title: "HOD Leave Requests",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LeaveApprovalScreen(role: "dean"),
                  ),
                );
              },
            ),

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

          ],
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
}