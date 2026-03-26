import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  String leaveType = "Casual Leave";
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String permissionDuration = "Full Day";
  final reasonController = TextEditingController();
  double totalDays = 0;

  List leaveTypes = [
    "Casual Leave",
    "Sick Leave",
    "Academic Leave",
    "Permission",
    "Emergency Leave"
  ];

  List permissionOptions = [
    "Full Day",
    "Half Day Morning",
    "Half Day Afternoon",
    "Custom Hours"
  ];

  void calculateDays() {
    if (startDate != null && endDate != null) {
      int diff = endDate!.difference(startDate!).inDays + 1;
      double days = diff.toDouble();
      if (leaveType == "Permission") {
        if (permissionDuration.contains("Half")) {
          days = 0.5;
        }
      }
      setState(() {
        totalDays = days;
      });
    }
  }

  void _showStatusDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    bool closeScreenAfterOk = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.45,
            color: Color(0xFF4B5563),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFF1E4D8F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                if (closeScreenAfterOk) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text("OK",
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        startDate = picked;
        if (leaveType == "Permission") {
          endDate = picked;
        } else {
          if (endDate != null && endDate!.isBefore(picked)) {
            endDate = picked;
          }
        }
      });
      calculateDays();
    }
  }

  Future pickEndDate() async {
    if (startDate == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? startDate ?? DateTime.now(),
      firstDate: startDate!,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        endDate = picked;
      });
      calculateDays();
    }
  }

  Future pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        startTime = picked;
      });
    }
  }

  Future pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        endTime = picked;
      });
    }
  }

  Future<void> submitLeave() async {
    if (startDate == null) {
      _showStatusDialog(
        title: "Missing Start Date",
        message: "Please select the start date.",
        icon: Icons.info_outline,
        iconColor: Colors.orange,
      );
      return;
    }
    if (leaveType != "Permission" && endDate == null) {
      _showStatusDialog(
        title: "Missing End Date",
        message: "Please select the end date.",
        icon: Icons.info_outline,
        iconColor: Colors.orange,
      );
      return;
    }
    if (leaveType != "Permission" && endDate!.isBefore(startDate!)) {
      _showStatusDialog(
        title: "Invalid Date Range",
        message: "End date cannot be before start date.",
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
      return;
    }
    if (reasonController.text.trim().isEmpty) {
      _showStatusDialog(
        title: "Reason Required",
        message: "Please enter the reason for leave.",
        icon: Icons.edit_note,
        iconColor: Colors.orange,
      );
      return;
    }
    try {
      final result = await ApiService.applyLeave(
        startDate: startDate!,
        endDate: leaveType == "Permission" ? startDate! : endDate!,
        leaveType: leaveType,
        reason: reasonController.text,
        permissionDuration: permissionDuration,
      );
      if (!mounted) return;
      String successMessage = result["message"] ?? "Leave applied successfully";
      if (result["total_days"] != null) {
        successMessage += "\n\nCounted leave days: ${result["total_days"]}";
      }
      if (result["excluded_days"] != null && result["excluded_days"] is List) {
        final excluded = result["excluded_days"] as List;
        if (excluded.isNotEmpty) {
          successMessage += "\nExcluded dates were not counted.";
        }
      }
      _showStatusDialog(
        title: "Leave Applied",
        message: successMessage,
        icon: Icons.check_circle,
        iconColor: Colors.green,
        closeScreenAfterOk: true,
      );
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceAll("Exception: ", "");
      _showStatusDialog(
        title: "Leave Blocked",
        message: errorMessage,
        icon: Icons.block,
        iconColor: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FB),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFF1E4D8F),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: const Color(0xFF1E4D8F),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Leave Request",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeaderBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Leave Type
                  _sectionLabel("Leave Type"),
                  const SizedBox(height: 6),
                  _buildDropdownCard(
                    value: leaveType,
                    items: leaveTypes,
                    onChanged: (value) {
                      setState(() {
                        leaveType = value!;
                        if (leaveType == "Emergency Leave") {
                          startDate = DateTime.now();
                          endDate = DateTime.now();
                          calculateDays();
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 14),

                  // Dates — side by side for normal leave
                  if (leaveType != "Permission") ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel("Start Date"),
                              const SizedBox(height: 6),
                              _dateTile(
                                title: startDate == null
                                    ? "Select"
                                    : "${startDate!.day}/${startDate!.month}/${startDate!.year}",
                                icon: Icons.calendar_month_rounded,
                                onTap: pickStartDate,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel("End Date"),
                              const SizedBox(height: 6),
                              _dateTile(
                                title: endDate == null
                                    ? "Select"
                                    : "${endDate!.day}/${endDate!.month}/${endDate!.year}",
                                icon: Icons.event_available_rounded,
                                onTap: startDate == null ? null : pickEndDate,
                                enabled: startDate != null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _selectedDaysCard(),
                  ],

                  // Permission Date
                  if (leaveType == "Permission") ...[
                    _sectionLabel("Permission Date"),
                    const SizedBox(height: 6),
                    _dateTile(
                      title: startDate == null
                          ? "Select Date"
                          : "${startDate!.day}/${startDate!.month}/${startDate!.year}",
                      icon: Icons.calendar_month_rounded,
                      onTap: pickStartDate,
                    ),
                    const SizedBox(height: 14),
                    _sectionLabel("Permission Duration"),
                    const SizedBox(height: 6),
                    _buildDropdownCard(
                      value: permissionDuration,
                      items: permissionOptions,
                      onChanged: (value) {
                        setState(() {
                          permissionDuration = value!;
                        });
                        calculateDays();
                      },
                    ),
                  ],

                  // Custom Hours
                  if (leaveType == "Permission" &&
                      permissionDuration == "Custom Hours") ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel("Start Time"),
                              const SizedBox(height: 6),
                              _dateTile(
                                title: startTime == null
                                    ? "Select"
                                    : startTime!.format(context),
                                icon: Icons.schedule_rounded,
                                onTap: pickStartTime,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel("End Time"),
                              const SizedBox(height: 6),
                              _dateTile(
                                title: endTime == null
                                    ? "Select"
                                    : endTime!.format(context),
                                icon: Icons.access_time_filled_rounded,
                                onTap: pickEndTime,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Reason
                  const SizedBox(height: 14),
                  _sectionLabel("Reason"),
                  const SizedBox(height: 6),
                  _glassCard(
                    padding: const EdgeInsets.all(10),
                    child: TextField(
                      controller: reasonController,
                      maxLines: 4,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2937),
                      ),
                      decoration: _inputDecoration().copyWith(
                        hintText: "Briefly describe your reason…",
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: submitLeave,
                      style: ElevatedButton.styleFrom(
                        elevation: 6,
                        shadowColor: const Color(0xFF1E4D8F).withOpacity(0.30),
                        backgroundColor: const Color(0xFF1E4D8F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Submit Request",
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E4D8F), Color(0xFF3A72C8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.15),
              border: Border.all(color: Colors.white.withOpacity(0.20)),
            ),
            child: const Icon(
              Icons.assignment_turned_in_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "New Leave Request",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "Fill in the details for a smooth approval.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedDaysCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF1E4D8F).withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1E4D8F).withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E4D8F).withOpacity(0.12),
            ),
            child: const Icon(
              Icons.timelapse_rounded,
              color: Color(0xFF1E4D8F),
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$totalDays Day(s)  ",
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E4D8F),
                    ),
                  ),
                  const TextSpan(
                    text: "— Holidays & Sundays excluded",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF374151),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildDropdownCard({
    required String value,
    required List items,
    required ValueChanged<String?> onChanged,
  }) {
    return _glassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF1E4D8F),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF1F2937),
          ),
          items: items.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _dateTile({
    required String title,
    required IconData icon,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: _glassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled
                    ? const Color(0xFF1E4D8F)
                    : const Color(0xFF9CA3AF),
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? const Color(0xFF1F2937)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: enabled
                    ? const Color(0xFF1E4D8F)
                    : const Color(0xFFD1D5DB),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withOpacity(0.95),
            border: Border.all(
              color: const Color(0xFFDDE5F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.transparent,
      isDense: true,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontWeight: FontWeight.w400,
        fontSize: 13.5,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(
          color: Color(0xFF1E4D8F),
          width: 1.4,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
    );
  }
}