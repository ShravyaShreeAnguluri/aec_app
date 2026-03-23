import 'package:flutter/material.dart';
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

      /// Half day permission
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
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
            onPressed: () {
              Navigator.pop(context);
              if (closeScreenAfterOk) {
                Navigator.pop(context, true);
              }
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future pickStartDate() async {

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {

      setState(() {
        startDate = picked;
      });

      calculateDays();

    }

  }

  Future pickEndDate() async {

    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2024),
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

      appBar: AppBar(
        title: const Text("Apply Leave"),
      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            /// Leave Type
            const Text("Leave Type"),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(

              value: leaveType,

              items: leaveTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),

              onChanged: (value) {
                setState(() {
                  leaveType = value!;

                  /// Auto fill for emergency leave
                  if (leaveType == "Emergency Leave") {
                    startDate = DateTime.now();
                    endDate = DateTime.now();
                    calculateDays();
                  }
                });
              },

            ),

            const SizedBox(height: 20),

            /// Start Date

            const Text("Start Date"),

            const SizedBox(height: 8),

            InkWell(
              onTap: pickStartDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  startDate == null
                      ? "Select Start Date"
                      : "${startDate!.day}-${startDate!.month}-${startDate!.year}",
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// End Date (Only for non-permission)

            if (leaveType != "Permission")

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text("End Date"),

                  const SizedBox(height: 8),

                  InkWell(
                    onTap: startDate == null ? null : pickEndDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        endDate == null
                            ? "Select End Date"
                            : "${endDate!.day}-${endDate!.month}-${endDate!.year}",
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                ],
              ),

            /// Total Days

            if (leaveType != "Permission")

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text("Selected Days"),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "$totalDays Day(s)\n(Holidays/Sundays will be excluded from final leave count)",
                    ),
                  ),
                  const SizedBox(height: 20),

                ],
              ),

            /// Permission Duration

            if (leaveType == "Permission")
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// Permission Date
                  const Text("Permission Date"),

                  const SizedBox(height: 8),

                  InkWell(
                    onTap: pickStartDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        startDate == null
                            ? "Select Date"
                            : "${startDate!.day}-${startDate!.month}-${startDate!.year}",
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// Permission Duration
                  const Text("Permission Duration"),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    initialValue: permissionDuration,
                    items: permissionOptions.map((p) {
                      return DropdownMenuItem<String>(
                        value: p,
                        child: Text(p),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        permissionDuration = value!;
                      });
                      calculateDays();
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            /// Custom Hours

            if (leaveType == "Permission" &&
                permissionDuration == "Custom Hours")

              Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  const Text("Start Time"),

                  const SizedBox(height: 8),

                  InkWell(
                    onTap: pickStartTime,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        startTime == null
                            ? "Select Start Time"
                            : startTime!.format(context),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text("End Time"),

                  const SizedBox(height: 8),

                  InkWell(
                    onTap: pickEndTime,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        endTime == null
                            ? "Select End Time"
                            : endTime!.format(context),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                ],

              ),

            /// Reason

            const Text("Reason"),

            const SizedBox(height: 8),

            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter reason",
              ),
            ),

            const SizedBox(height: 30),

            /// Submit Button

            SizedBox(
              width: double.infinity,
              height: 50,

              child: ElevatedButton(

                onPressed: submitLeave,

                child: const Text(
                  "Submit Leave Request",
                  style: TextStyle(fontSize: 16),
                ),

              ),

            ),

          ],

        ),

      ),

    );

  }

}