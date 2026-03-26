import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class LeaveApprovalScreen extends StatefulWidget {
  final String role;

  const LeaveApprovalScreen({
    super.key,
    required this.role,
  });

  @override
  State<LeaveApprovalScreen> createState() => _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen> {
  List leaves = [];
  String selectedTab = "PENDING";
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadLeaves();
  }

  Future<void> loadLeaves() async {
    try {
      List data;

      if (widget.role == "hod") {
        data = await ApiService.getDepartmentLeaves();
      } else {
        data = await ApiService.getHodLeaves();
      }

      setState(() {
        leaves = data;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
    }
  }

  Future approveLeave(int id) async {
    await ApiService.approveLeave(id);
    await loadLeaves();
  }

  Future rejectLeave(int id) async {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "Reject Leave",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(
              hintText: "Enter reason",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(
                  color: Color(0xFF1E4D8F),
                  width: 1.2,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text(
                "Cancel",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Reject",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () async {
                await ApiService.rejectLeave(
                  id,
                  reasonController.text,
                );

                Navigator.pop(context);
                await loadLeaves();
              },
            )
          ],
        );
      },
    );
  }

  Color statusColor(String status) {
    if (status == "APPROVED") return Colors.green;
    if (status == "REJECTED") return Colors.red;
    return Colors.orange;
  }

  IconData statusIcon(String status) {
    if (status == "APPROVED") return Icons.check_circle_rounded;
    if (status == "REJECTED") return Icons.cancel_rounded;
    return Icons.pending_actions_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = leaves
        .where((l) =>
    (l["status"] ?? "").toString().toUpperCase() == selectedTab)
        .toList();

    final hodLeaves = filtered.where((l) => l["role"] == "HOD").toList();

    final escalatedLeaves =
    filtered.where((l) => l["role"] == "FACULTY ESCALATED").toList();

    /// FOR HOD DASHBOARD
    final facultyLeaves =
    filtered.where((l) => l["role"] == "FACULTY").toList();

    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FB),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.role == "hod"
              ? "Faculty Leave Requests"
              : "HOD Leave Requests",
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E5FA5),
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          /// SUMMARY
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.92),
                        const Color(0xFFF7FBFF).withOpacity(0.82),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.55),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E5FA5).withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.assignment_turned_in_rounded,
                            color: Color(0xFF2E5FA5),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Leave Overview",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: compactStatCard(
                              title: "Pending",
                              value: leaves
                                  .where((l) => l["status"] == "PENDING")
                                  .length
                                  .toString(),
                              color: Colors.orange,
                              icon: Icons.pending_actions_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: compactStatCard(
                              title: "Approved",
                              value: leaves
                                  .where((l) => l["status"] == "APPROVED")
                                  .length
                                  .toString(),
                              color: Colors.green,
                              icon: Icons.check_circle_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: compactStatCard(
                              title: "Rejected",
                              value: leaves
                                  .where((l) => l["status"] == "REJECTED")
                                  .length
                                  .toString(),
                              color: Colors.red,
                              icon: Icons.cancel_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          /// TABS
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                tabButton("PENDING"),
                tabButton("APPROVED"),
                tabButton("REJECTED"),
              ],
            ),
          ),

          /// LEAVE LIST
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 26),
              children: [
                /// FACULTY LEAVES
                if (widget.role == "hod" && facultyLeaves.isNotEmpty) ...[
                  sectionTitle("Faculty Leave Requests"),
                  ...facultyLeaves.map((leave) => leaveCard(leave)).toList(),
                ],

                /// HOD LEAVES
                if (hodLeaves.isNotEmpty) ...[
                  sectionTitle("HOD Leave Requests"),
                  ...hodLeaves.map((leave) => leaveCard(leave)).toList(),
                ],

                /// ESCALATED FACULTY LEAVES
                if (escalatedLeaves.isNotEmpty) ...[
                  sectionTitle("Escalated Faculty Leaves"),
                  ...escalatedLeaves.map((leave) => leaveCard(leave)).toList(),
                ],

                if (facultyLeaves.isEmpty &&
                    hodLeaves.isEmpty &&
                    escalatedLeaves.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("No requests"),
                    ),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1F2937),
        ),
      ),
    );
  }

  Widget tabButton(String title) {
    bool active = selectedTab == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF28B39) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: active
              ? [
            BoxShadow(
              color: const Color(0xFFF28B39).withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
              : [],
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget leaveCard(dynamic leave) {
    bool emergency = leave["leave_type"] == "Emergency Leave";
    final status = (leave["status"] ?? "").toString().toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.88),
                  Colors.white.withOpacity(0.76),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.50),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// TOP ROW
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF1E4D8F).withOpacity(0.10),
                      child: const Icon(
                        Icons.school,
                        color: Color(0xFF1E4D8F),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            leave["faculty_name"],
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${leave["department"] ?? ""} ${leave["role"] ?? ""}",
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (leave["role"] == "FACULTY ESCALATED")
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                "Escalated to Dean",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor(status).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: statusColor(status).withOpacity(0.18),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusIcon(status),
                                size: 14,
                                color: statusColor(status),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                status,
                                style: TextStyle(
                                  color: statusColor(status),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (emergency) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              "EMERGENCY",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                infoRow(
                  Icons.calendar_month_rounded,
                  "${leave["start_date"]} → ${leave["end_date"]}",
                ),

                const SizedBox(height: 8),

                Text(
                  "Leave Type: ${leave["leave_type"]}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),

                if (leave["total_days"] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Duration: ${leave["total_days"]} Day(s)",
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E4D8F).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    "Reason: ${leave["reason"]}",
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                if (leave["status"] == "PENDING")
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => approveLeave(leave["id"]),
                          label: const Text(
                            "Approve",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.close),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => rejectLeave(leave["id"]),
                          label: const Text(
                            "Reject",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF2E5FA5),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget compactStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withOpacity(0.08),
        border: Border.all(
          color: color.withOpacity(0.16),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget statItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}