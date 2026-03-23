import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/location_service.dart';
import 'camera_screen.dart';
import 'attendance_verify_screen.dart';
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

  @override
  void initState() {
    super.initState();

    // update time every second
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      setState(() {
        currentTime = DateTime.now();
      });

      return true;
    });
  }

  void _showBlockedDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.event_busy, color: Colors.red),
            SizedBox(width: 8),
            Text("Attendance Blocked"),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E4D8F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAttendance(
      BuildContext context,
      String type,
      ) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {

      final holidayStatus = await ApiService.getTodayHoliday();
      if (holidayStatus["is_holiday"] == true) {
        _showBlockedDialog(
            "Attendance cannot be marked on holidays or Sundays. Today is ${holidayStatus["reason"]}."
        );
        return;
      }

      final position = await LocationService.getCurrentLocation();

      final capturedImage = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );

      if (capturedImage == null) {
        setState(() {
          isProcessing = false;
        });
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
      );
    } catch (e) {
      _showBlockedDialog(
        e.toString().replaceAll("Exception: ", ""),
      );
    }finally {
      setState(() {
        isProcessing = false;
      });
    }
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance"),
        backgroundColor: const Color(0xFF1E4D8F),
      ),

      // 🌈 THEME BACKGROUND
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE3F2FD),
              Color(0xFFBBDEFB),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                Text(
                  "${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}:${currentTime.second.toString().padLeft(2, '0')}",
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E4D8F),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "${currentTime.day}-${currentTime.month}-${currentTime.year}",
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 40),

                /// CLOCK IN BUTTON
                _attendanceButton(
                  icon: Icons.login,
                  text: "Clock In",
                  onTap: () => _handleAttendance(context, "clock-in"),
                ),

                const SizedBox(height: 25),

                /// CLOCK OUT BUTTON
                _attendanceButton(
                  icon: Icons.logout,
                  text: "Clock Out",
                  onTap: () => _handleAttendance(context, "clock-out"),
                ),

                const SizedBox(height: 30),

                if (isProcessing)
                  const Text(
                    "Processing attendance...",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🔹 Styled Button Widget
  Widget _attendanceButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: isProcessing ? null : onTap,
        child: Container(
          width: double.infinity,
          height: 65,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1E4D8F),
                Color(0xFF4A79B8),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
