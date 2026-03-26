import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/location_service.dart';
import 'camera_screen.dart';
import 'attendance_verify_screen.dart';
import 'attendance_history_screen.dart';
import 'attendance_report_screen.dart';
import '../../services/api_service.dart';

class AttendanceMenuScreen extends StatefulWidget {
  final String email;

  const AttendanceMenuScreen({super.key, required this.email});

  @override
  State<AttendanceMenuScreen> createState() => _AttendanceMenuScreenState();
}

class _AttendanceMenuScreenState extends State<AttendanceMenuScreen> {
  bool isProcessing = false;
  DateTime currentTime = DateTime.now();
  Map<String, dynamic>? todayStatus;

  static const _blue = Color(0xFF1E4D8F);
  static const _blueDark = Color(0xFF163A6B);
  static const _blueSoft = Color(0xFF2D63AE);
  static const _green = Color(0xFF0F6E56);
  static const _greenDark = Color(0xFF0A5A47);
  static const _bgLight = Color(0xFFF4F7FF);
  static const _cardBorder = Color(0xFFE7ECF5);
  static const _textDark = Color(0xFF1F2937);
  static const _textSoft = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadTodayStatus();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => currentTime = DateTime.now());
      return true;
    });
  }

  Future<void> _loadTodayStatus() async {
    try {
      final data = await ApiService.getTodayAttendanceStatus();
      if (mounted) setState(() => todayStatus = data);
    } catch (_) {}
  }

  void _showBlockedDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.event_busy_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text(
              "Attendance Blocked",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAttendance(BuildContext context, String type) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);
    try {
      final holidayStatus = await ApiService.getTodayHoliday();
      if (holidayStatus["is_holiday"] == true) {
        _showBlockedDialog(
          "Attendance cannot be marked on holidays or Sundays. Today is ${holidayStatus["reason"]}.",
        );
        return;
      }
      final position = await LocationService.getCurrentLocation();
      final capturedImage = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
      if (capturedImage == null) {
        setState(() => isProcessing = false);
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttendanceVerifyScreen(
            email: widget.email,
            faceImage: File(capturedImage.path),
            latitude: position.latitude,
            longitude: position.longitude,
            attendanceType: type,
          ),
        ),
      ).then((_) => _loadTodayStatus());
    } catch (e) {
      _showBlockedDialog(e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hour = currentTime.hour;
    final greeting = hour < 12
        ? "Good Morning"
        : hour < 17
        ? "Good Afternoon"
        : "Good Evening";

    final weekdays = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday"
    ];
    final months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];

    final dayName = weekdays[currentTime.weekday - 1];
    final monthName = months[currentTime.month - 1];

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: const Text(
          "Attendance",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.2,
          ),
        ),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_blueDark, _blue, _blueSoft],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(34),
                  bottomRight: Radius.circular(34),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -30,
                    right: -20,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -35,
                    left: -18,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "${_pad(currentTime.hour)}:${_pad(currentTime.minute)}:${_pad(currentTime.second)}",
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.5,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            "$dayName, ${currentTime.day} $monthName ${currentTime.year}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (todayStatus != null)
              Transform.translate(
                offset: const Offset(0, -16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _statusCard(todayStatus!),
                ),
              )
            else
              const SizedBox(height: 16),

            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                todayStatus != null ? 2 : 18,
                18,
                30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "MARK ATTENDANCE",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.black45,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _actionCard(
                          icon: Icons.login_rounded,
                          label: "Clock In",
                          description: "Mark arrival",
                          color: _blue,
                          darkColor: _blueDark,
                          onTap: () => _handleAttendance(context, "clock-in"),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _actionCard(
                          icon: Icons.logout_rounded,
                          label: "Clock Out",
                          description: "Mark departure",
                          color: _green,
                          darkColor: _greenDark,
                          onTap: () => _handleAttendance(context, "clock-out"),
                        ),
                      ),
                    ],
                  ),
                  if (isProcessing) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.blue.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: _blue,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Processing attendance...",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const Text(
                    "QUICK ACCESS",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.black45,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _navTile(
                    icon: Icons.history_rounded,
                    title: "Attendance History",
                    subtitle: "View your daily log",
                    color: _blue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AttendanceHistoryScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _navTile(
                    icon: Icons.bar_chart_rounded,
                    title: "Attendance Reports",
                    subtitle: "Monthly summary & stats",
                    color: _green,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AttendanceReportScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(Map<String, dynamic> status) {
    final s = status["status"] ?? "";
    final clockIn = status["clock_in_time"];
    final clockOut = status["clock_out_time"];

    Color statusColor;
    String label;
    String message;

    switch (s) {
      case "PRESENT":
        statusColor = const Color(0xFF16A34A);
        label = "Present";
        message = "Attendance marked successfully for today";
        break;
      case "ABSENT":
        statusColor = const Color(0xFFDC2626);
        label = "Absent";
        message = "No valid attendance marked for today";
        break;
      case "NOT_MARKED":
        statusColor = const Color(0xFFF59E0B);
        label = "Not Marked";
        message = "You have not completed attendance yet";
        break;
      case "HOLIDAY":
        statusColor = const Color(0xFF0891B2);
        label = "Holiday";
        message = "Attendance is not required today";
        break;
      default:
        statusColor = Colors.grey.shade600;
        label = s.isNotEmpty ? s : "Unknown";
        message = "Attendance status is currently unavailable";
    }

    final inTime = clockIn != null ? _fmt(clockIn) : "--:--";
    final outTime = clockOut != null ? _fmt(clockOut) : "--:--";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withOpacity(0.20),
                      statusColor.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _statusIcon(s),
                  color: statusColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Status",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.grey.shade200,
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _timeBox(
                  label: "In Time",
                  time: inTime,
                  icon: Icons.login_rounded,
                  iconColor: const Color(0xFF16A34A),
                  bgColor: const Color(0xFFF0FDF4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _timeBox(
                  label: "Out Time",
                  time: outTime,
                  icon: Icons.logout_rounded,
                  iconColor: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEF2F2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeBox({
    required String label,
    required String time,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: iconColor.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case "PRESENT":
        return Icons.verified_rounded;
      case "ABSENT":
        return Icons.cancel_rounded;
      case "NOT_MARKED":
        return Icons.pending_actions_rounded;
      case "HOLIDAY":
        return Icons.event_available_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Widget _statusPill(Map<String, dynamic> status) {
    final s = status["status"] ?? "";
    final clockIn = status["clock_in_time"];
    final clockOut = status["clock_out_time"];

    Color statusColor;
    IconData statusIcon;
    String label;

    switch (s) {
      case "PRESENT":
        statusColor = Colors.green.shade600;
        statusIcon = Icons.check_circle_rounded;
        label = "Present";
        break;
      case "ABSENT":
        statusColor = Colors.red.shade600;
        statusIcon = Icons.cancel_rounded;
        label = "Absent";
        break;
      case "NOT_MARKED":
        statusColor = Colors.orange.shade600;
        statusIcon = Icons.access_time_rounded;
        label = "Not Marked Yet";
        break;
      case "HOLIDAY":
        statusColor = Colors.teal.shade600;
        statusIcon = Icons.event_rounded;
        label = "Holiday";
        break;
      default:
        statusColor = Colors.white54;
        statusIcon = Icons.help_outline_rounded;
        label = s.isNotEmpty ? s : "Unknown";
    }

    final inTime = clockIn != null ? _fmt(clockIn) : "--:--";
    final outTime = clockOut != null ? _fmt(clockOut) : "--:--";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Today's Status",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {},
                child: const Row(
                  children: [
                    Text(
                      "View Details",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              _timeChip(
                Icons.login_rounded,
                "In",
                inTime,
                Colors.greenAccent.shade200,
              ),
              const SizedBox(width: 24),
              _timeChip(
                Icons.logout_rounded,
                "Out",
                outTime,
                Colors.redAccent.shade100,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeChip(IconData icon, String label, String time, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 5),
        Text(
          "$label: ",
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        Text(
          time,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required Color darkColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isProcessing ? 0.85 : 1,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [darkColor, color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -8,
                right: -6,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  String _fmt(String t) {
    final parts = t.split(":");
    if (parts.length < 2) return t;
    int h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1].padLeft(2, '0');
    final suffix = h >= 12 ? "PM" : "AM";
    h = h % 12;
    if (h == 0) h = 12;
    return "$h:$m $suffix";
  }
}