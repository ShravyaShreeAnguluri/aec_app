import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import '../../faculty_docs_screens/certificates_screen.dart';
import '../../faculty_docs_screens/home_screen.dart';
import '../../providers/certificate_provider.dart';
import '../../providers/document_provider.dart';
import '../../screens/attendance/attendance_menu_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/leave/leave_history_screen.dart';
import '../../screens/schedule/schedule_screen.dart';
import '../../services/api_service.dart';
import '../../screens/holidays/holiday_list_screen.dart';

class FacultyDashboardScreen extends StatefulWidget {
  final String email;
  final String name;
  final String facultyId;
  final String department;
  final String? designation;
  final String? qualification;
  final String? profileImage;
  final String role;

  const FacultyDashboardScreen({
    super.key,
    required this.email,
    required this.name,
    required this.facultyId,
    required this.department,
    this.designation,
    this.qualification,
    this.profileImage,
    required this.role,
  });

  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen> {
  int _currentIndex = 0;
  DateTime today = DateTime.now();
  Map leaveBalance = {};
  bool loadingLeaveBalance = true;
  Map<String, dynamic>? todayAttendance;
  bool loadingTodayAttendance = true;

  @override
  void initState() {
    super.initState();
    loadLeaveBalance();
    loadTodayAttendanceStatus();

    if (widget.role == "admin") {
      print("Admin logged in");
    }
    else if (widget.role == "hod") {
      print("HOD logged in");
    }
    else {
      print("Faculty logged in");
    }
  }

  Future<void> loadLeaveBalance() async {
    try {
      final data = await ApiService.getLeaveBalance();
      setState(() {
        leaveBalance = data;
        loadingLeaveBalance = false;
      });

    } catch (e) {
      setState(() {
        loadingLeaveBalance = false;
      });

    }
  }

  Future<void> loadTodayAttendanceStatus() async {
    try {
      final data = await ApiService.getTodayAttendanceStatus();

      if (!mounted) return;

      setState(() {
        todayAttendance = data;
        loadingTodayAttendance = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingTodayAttendance = false;
        todayAttendance = {
          "status": "ERROR",
          "message": "Unable to load attendance status",
          "remarks": "--",
          "clock_in_time": null,
          "clock_out_time": null,
          "working_hours": 0,
          "day_fraction": 0,
          "used_permission": false,
        };
      });
    }
  }

  // ── Navigation helpers ─────────────────────────────────────────────────
  // ✅ Pass widget.name so only THIS faculty's docs/certs are shown
  void _openFacultyDocs() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DocumentProvider()),
          ChangeNotifierProvider(create: (_) => CertificateProvider()),
        ],
        child: HomeScreen(facultyName: widget.name),  // ← name passed here
      ),
    ));
  }

  void _openCertificates() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => CertificateProvider(),
        child: CertificatesScreen(facultyName: widget.name), // ← name passed here
      ),
    ));
  }


  @override
  Widget build(BuildContext context) {
    final pages = [
      dashboardHome(),
      AttendanceMenuScreen(email: widget.email),
      LeaveHistoryScreen(),
      ScheduleScreen(facultyId: widget.facultyId),
      ProfileScreen(
        name: widget.name,
        email: widget.email,
        facultyId: widget.facultyId,
        department: widget.department,
        designation: widget.designation,
        qualification: widget.qualification,
        profileImage: widget.profileImage,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FB),
      body: pages[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF1E4D8F),
        unselectedItemColor: Colors.grey,
        onTap: (index) async {
          setState(() => _currentIndex = index);

          if (index == 0) {
            await loadTodayAttendanceStatus();
            await loadLeaveBalance();
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: "Attendance"),
          BottomNavigationBarItem(icon: Icon(Icons.event_note_outlined), label: "Leave"),
          BottomNavigationBarItem(icon: Icon(Icons.schedule_outlined), label: "Schedule"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    );
  }

  /// ---------------- HOME DASHBOARD ----------------
  Widget dashboardHome() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// 🔵 Welcome Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E4D8F), Color(0xFF4A79B8)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome Back 👋",
                      style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 5),
                  Text(
                    "Faculty Dashboard",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ════════════════════════════════════════════════════
            // 📁 Faculty Docs + Certificates cards
            // ════════════════════════════════════════════════════
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: _openFacultyDocs,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E4D8F),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                        color: const Color(0xFF1E4D8F).withOpacity(0.3),
                        blurRadius: 8, offset: const Offset(0, 4),
                      )],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.folder_open_rounded,
                            color: Colors.white, size: 32),
                        SizedBox(height: 10),
                        Text("Faculty Docs",
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 4),
                        Text("Notes, Assignments\n& Study Material",
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _openCertificates,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.3),
                        blurRadius: 8, offset: const Offset(0, 4),
                      )],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            color: Colors.white, size: 32),
                        SizedBox(height: 10),
                        Text("Certificates",
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 4),
                        Text("Achievements &\nTraining Records",
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 20),

            /// 📅 Calendar Card
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6)
                ],
              ),
              child: TableCalendar(
                focusedDay: today,
                firstDay: DateTime.utc(2020),
                lastDay: DateTime.utc(2030),
                calendarFormat: CalendarFormat.week,
                headerVisible: false,
                selectedDayPredicate: (day) => isSameDay(day, today),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() => today = selectedDay);
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: const BoxDecoration(
                    color: Color(0xFF1E4D8F),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Color(0xFFB87333),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// 📚 Today Schedule Preview
            buildCard(
              "Today's Classes",
              Column(
                children: [
                  scheduleRow("9:30 AM", "Machine Learning"),
                  scheduleRow("10:20 AM", "NLP"),
                  scheduleRow("11:10 AM", "CNS"),
                ],
              ),
            ),

            const SizedBox(height: 20),

            buildCard(
              "Today's Attendance",
              loadingTodayAttendance
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todayAttendance?["status"] ?? "UNKNOWN",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4D8F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(todayAttendance?["message"] ?? "-"),
                  const SizedBox(height: 8),
                  Text(
                    "Remarks: ${todayAttendance?["remarks"] ?? "--"}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E4D8F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Day Value: ${todayAttendance?["day_fraction"] ?? 0}",
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "LoggedIn: ${todayAttendance?["clock_in_time"] ?? "--"}",
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "LoggedOut: ${todayAttendance?["clock_out_time"] ?? "--"}",
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Working Hours: ${todayAttendance?["working_hours"] ?? 0}",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            /// 📝 Leave Summary
            buildCard(
              "Leave Summary",
              loadingLeaveBalance
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [

                  leaveItem(
                    "Available",
                    leaveBalance["total_allowed"].toString(),
                  ),

                  leaveItem(
                    "Used",
                    leaveBalance["used"].toString(),
                  ),

                  leaveItem(
                    "Remaining",
                    leaveBalance["remaining"].toString(),
                  ),

                ],
              ),
            ),
            const SizedBox(height: 15),

            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HolidayListScreen(isAdmin: false),
                  ),
                );
              },
              child: buildCard(
                "Holidays",
                Row(
                  children: const [
                    Icon(Icons.calendar_month, color: Color(0xFF1E4D8F), size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "View holiday list and calendar",
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------- Reusable Widgets ----------

  static Widget buildCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          child
        ],
      ),
    );
  }

  static Widget scheduleRow(String time, String subject) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(time),
          Text(subject,
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  static Widget leaveItem(String title, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E4D8F))),
        Text(title),
      ],
    );
  }
}
