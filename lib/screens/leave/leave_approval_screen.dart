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

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen>{

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
    }catch(e) {
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
          title: const Text("Reject Leave"),

          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              hintText: "Enter reason",
            ),
          ),

          actions: [

            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),

            ElevatedButton(
              child: const Text("Reject"),
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

  @override
  Widget build(BuildContext context) {

    final filtered = leaves
        .where((l) =>
          (l["status"] ?? "").toString().toUpperCase() == selectedTab)
        .toList();

    final hodLeaves =
    filtered.where((l) => l["role"] == "HOD").toList();

    final escalatedLeaves =
    filtered.where((l) => l["role"] == "FACULTY ESCALATED").toList();

    /// FOR HOD DASHBOARD
    final facultyLeaves =
    filtered.where((l) => l["role"] == "FACULTY").toList();

    return Scaffold(

      appBar: AppBar(
        title: Text(
          widget.role == "hod"
              ? "Faculty Leave Requests"
              : "HOD Leave Requests",
        ),
        backgroundColor: const Color(0xFF2E5FA5),
      ),

      body: Column(
          children: [

      /// SUMMARY
      Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [

          statItem(
            "Pending",
            leaves.where((l) => l["status"] == "PENDING").length.toString(),
            Colors.orange,
          ),

          statItem(
            "Approved",
            leaves.where((l) => l["status"] == "APPROVED").length.toString(),
            Colors.green,
          ),

          statItem(
            "Rejected",
            leaves.where((l) => l["status"] == "REJECTED").length.toString(),
            Colors.red,
          ),

        ],
      ),
    ),
          /// Tabs
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(6),

            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(25),
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

          /// Leave List
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              children: [

                /// FACULTY LEAVES
                if (widget.role == "hod" && facultyLeaves.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      "Faculty Leave Requests",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  ...facultyLeaves.map((leave) => leaveCard(leave)).toList(),
                ],

                /// HOD LEAVES
                if (hodLeaves.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      "HOD Leave Requests",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  ...hodLeaves.map((leave) => leaveCard(leave)).toList(),
                ],

                /// ESCALATED FACULTY LEAVES
                if (escalatedLeaves.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      "Escalated Faculty Leaves",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  ...escalatedLeaves.map((leave) => leaveCard(leave)).toList(),
                ],

                if (facultyLeaves.isEmpty && hodLeaves.isEmpty && escalatedLeaves.isEmpty)
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

  Widget tabButton(String title) {

    bool active = selectedTab == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = title;
        });
      },

      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ),

        decoration: BoxDecoration(
          color: active ? const Color(0xFFF28B39) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),

        child: Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget leaveCard(dynamic leave) {

    bool emergency = leave["leave_type"] == "Emergency Leave";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
          )
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// Top Row
          Row(
            children: [

              /// Professor Icon
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue.shade100,
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

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(
                          leave["faculty_name"],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 2),

                        Text(
                          "${leave["department"] ?? ""} ${leave["role"] ?? ""}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),

                      ],
                    ),

                    if (leave["role"] == "FACULTY ESCALATED")
                      const Text(
                        "Escalated to Dean",
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    Text(
                      "${leave["start_date"]} → ${leave["end_date"]}",
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),

                  ],
                ),
              ),

              /// Emergency indicator
              if (emergency)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "EMERGENCY",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )

            ],
          ),

          const SizedBox(height: 10),

          /// Leave Type
          Text(
            "Leave Type: ${leave["leave_type"]}",
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 4),

          /// Total Days
          if (leave["total_days"] != null)
            Text("Duration: ${leave["total_days"]} Day(s)"),

          const SizedBox(height: 6),

          /// Reason
          Text(
            "Reason: ${leave["reason"]}",
            style: const TextStyle(color: Colors.black87),
          ),

          const SizedBox(height: 10),

          /// Buttons
          if (leave["status"] == "PENDING")
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [

                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () => approveLeave(leave["id"]),
                  label: const Text("Approve"),
                ),

                const SizedBox(width: 10),

                ElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () => rejectLeave(leave["id"]),
                  label: const Text("Reject"),
                ),

              ],
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