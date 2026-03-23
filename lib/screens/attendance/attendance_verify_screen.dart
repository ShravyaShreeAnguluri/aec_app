import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/attendance_service.dart';
import 'attendance_result_screen.dart';

class AttendanceVerifyScreen extends StatefulWidget {
  final File faceImage;
  final String email;
  final double latitude;
  final double longitude;
  final String attendanceType; // clock-in or clock-out

  const AttendanceVerifyScreen({
    super.key,
    required this.faceImage,
    required this.email,
    required this.latitude,
    required this.longitude,
    required this.attendanceType,
  });

  @override
  State<AttendanceVerifyScreen> createState() =>
      _AttendanceVerifyScreenState();
}

class _AttendanceVerifyScreenState extends State<AttendanceVerifyScreen> {
  @override
  void initState() {
    super.initState();
    markAttendance();
  }

  Future<void> markAttendance() async {
    try {
      final response = await AttendanceService.markAttendance(
        email: widget.email,
        latitude: widget.latitude,
        longitude: widget.longitude,
        faceImage: widget.faceImage,
        type: widget.attendanceType,
      );

      if (!mounted) return;

      final remarks = response["remarks"]?.toString();
      final clockInTime = response["clock_in_time"]?.toString();
      final clockOutTime = response["clock_out_time"]?.toString();
      final workingHours = response["working_hours"]?.toString();
      final dayFraction = response["day_fraction"]?.toString();

      String title = widget.attendanceType == "clock-in"
          ? "Clock In Successful"
          : "Clock Out Successful";

      String message = "";

      if (remarks != null && remarks.isNotEmpty) {
        message += "Remarks: $remarks\n";
      }

      if (clockInTime != null && clockInTime.isNotEmpty) {
        message += "In Time: $clockInTime\n";
      }

      if (clockOutTime != null && clockOutTime.isNotEmpty) {
        message += "Out Time: $clockOutTime\n";
      }

      if (dayFraction != null && dayFraction.isNotEmpty) {
        message += "Day Value: $dayFraction\n";
      }

      if (workingHours != null && workingHours.isNotEmpty) {
        message += "Working Hours: $workingHours\n";
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AttendanceResultScreen(
            success: true,
            title: title,
            message: message.trim(),
          ),
        ),
      );
    } catch (e) {
      String message = e.toString().replaceAll("Exception: ", "").trim();

      if (message.contains("outside the college campus")) {
        message = "You must be inside the campus to mark attendance.";
      } else if (message.contains("Face not matched")) {
        message = "Face verification failed. Please try again.";
      } else if (message.contains("Attendance already marked today")) {
        message = "Attendance already marked for today.";
      } else if (message.contains("You are already marked absent for today")) {
        message = "You are already marked absent for today.";
      } else if (message.contains("Clock-in not found for today")) {
        message = "Please clock in first before clocking out.";
      } else if (message.contains("Already clocked out for today")) {
        message = "You already clocked out for today.";
      } else if (message.contains("Attendance opens at 9:00 AM")) {
        message = "Attendance opens at 9:00 AM.";
      } else if (message.contains("You are on full day leave today")) {
        message = "Attendance is blocked because you are on full day leave today.";
      } else if (message.contains("For half day morning leave")) {
        message = "For morning half-day leave, clock-in is allowed only from 12:00 PM to 12:30 PM.";
      } else if (message.contains("For half day afternoon leave")) {
        message = "For afternoon half-day leave, clock-out is allowed only from 12:00 PM to 12:30 PM.";
      } else if (message.contains("Clock-in allowed only from 9:00 AM to 9:30 AM")) {
        message = "For this attendance type, clock-in is allowed only from 9:00 AM to 9:30 AM.";
      } else if (message.contains("Clock-out time must be after clock-in time")) {
        message = "Clock-out time must be later than clock-in time.";
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AttendanceResultScreen(
            success: false,
            title: "Attendance Failed",
            message: message,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              "Verifying attendance...",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}