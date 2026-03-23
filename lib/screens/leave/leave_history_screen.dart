import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'apply_leave_screen.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {

  List leaves = [];
  bool loading = true;

  String selectedFilter = "ALL";

  @override
  void initState() {
    super.initState();
    loadLeaves();
  }

  Future<void> loadLeaves() async {

    try {

    final data = await ApiService.getMyLeaves();

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

  Color statusColor(String status){

    if(status == "APPROVED") return Colors.green;
    if(status == "REJECTED") return Colors.red;

    return Colors.orange;


  }

  @override
  Widget build(BuildContext context) {

    final filteredLeaves = selectedFilter == "ALL"
    ? leaves
        : leaves.where((l) => l["status"] == selectedFilter).toList();

    return Scaffold(

    backgroundColor: const Color(0xFFEAF2FB),

    appBar: AppBar(
    title: const Text("Leave History"),
    backgroundColor: const Color(0xFF1E4D8F),
    ),

    floatingActionButton: FloatingActionButton(
    backgroundColor: const Color(0xFF1E4D8F),
    child: const Icon(Icons.add),

    onPressed: () async {

    await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const ApplyLeaveScreen(),
    );

    loadLeaves();

    },
    ),

    body: loading
    ? const Center(child: CircularProgressIndicator())
        : Column(
    children: [

    /// LEAVE SUMMARY
    Container(
    margin: const EdgeInsets.all(12),
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

    child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [

    summaryItem(
    "Approved",
    leaves.where((l) => l["status"] == "APPROVED").length.toString(),
    Colors.green,
    ),

    summaryItem(
    "Pending",
    leaves.where((l) => l["status"] == "PENDING").length.toString(),
    Colors.orange,
    ),

    summaryItem(
    "Rejected",
    leaves.where((l) => l["status"] == "REJECTED").length.toString(),
    Colors.red,
    ),

    ],
    ),
    ),

    /// FILTER BUTTONS
    Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
    children: [

    const SizedBox(width: 10),

    filterButton("ALL"),
    const SizedBox(width: 8),

    filterButton("PENDING"),
    const SizedBox(width: 8),

    filterButton("APPROVED"),
    const SizedBox(width: 8),

    filterButton("REJECTED"),
    const SizedBox(width: 8),

    filterButton("CANCELLED"),
    const SizedBox(width: 10),

    ],
    ),
    ),
    ),

    /// LEAVE LIST
    Expanded(
    child: filteredLeaves.isEmpty
    ? const Center(
    child: Text(
    "No Leave Requests",
    style: TextStyle(fontSize: 16),
    ),
    )
        : ListView.builder(

    padding: const EdgeInsets.all(12),

    itemCount: filteredLeaves.length,

    itemBuilder: (context,index){

    final leave = filteredLeaves[index];
    final status = leave["status"];

    return Container(

    margin: const EdgeInsets.only(bottom: 12),

    decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
    BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 6,
    )
    ],
    ),

    child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

    /// STATUS COLOR STRIP
    Container(
    width: 5,
    height: 120,
    decoration: BoxDecoration(
    color: statusColor(status),
    borderRadius: const BorderRadius.only(
    topLeft: Radius.circular(16),
    bottomLeft: Radius.circular(16),
    ),
    ),
    ),

    Expanded(
    child: Container(

    padding: const EdgeInsets.all(16),

    decoration: const BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.only(
    topRight: Radius.circular(16),
    bottomRight: Radius.circular(16),
    ),
    ),

    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

    /// Leave Type + Status
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [

    Text(
    leave["leave_type"],
    style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
    ),
    ),

    Container(
    padding: const EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 4,
    ),

    decoration: BoxDecoration(
    color: statusColor(status).withOpacity(0.1),
    borderRadius: BorderRadius.circular(20),
    ),

    child: Text(
    status,
    style: TextStyle(
    color: statusColor(status),
    fontWeight: FontWeight.bold,
    ),
    ),
    )

    ],
    ),

    const SizedBox(height: 10),

    /// Dates
    Row(
    children: [
    const Icon(Icons.calendar_today,size:16),
    const SizedBox(width:6),
    Text(
    "${leave["start_date"].toString().substring(0,10)} → ${leave["end_date"].toString().substring(0,10)}",
    ),
    ],
    ),

    const SizedBox(height: 6),

    /// Total Days
    if(leave["total_days"] != null)
    Row(
    children: [
    const Icon(Icons.timelapse,size:16),
    const SizedBox(width:6),
    Text("${leave["total_days"]} Day(s)"),
    ],
    ),

    const SizedBox(height: 6),

    /// Reason
    if(leave["reason"] != null)
    Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    const Icon(Icons.notes,size:16),
    const SizedBox(width:6),
    Expanded(
    child: Text(
    leave["reason"],
    style: const TextStyle(
    color: Colors.black87,
    ),
    ),
    ),
    ],
    ),

    /// Cancel Leave
    if (status == "PENDING")
    TextButton(
    onPressed: () async {
    await ApiService.cancelLeave(leave["id"]);
    loadLeaves();
    },
    child: const Text(
    "Cancel Leave",
    style: TextStyle(color: Colors.red),
    ),
    ),

    const SizedBox(height: 8),

    /// Approved By
    if(leave["approved_by_role"] != null)

    Row(
    children: [

    const Icon(Icons.verified,
    size:16,
    color: Colors.green
    ),

    const SizedBox(width:6),

    Text(
    "Approved by ${leave["approved_by_role"].toString().toUpperCase()}",
    style: const TextStyle(
    fontSize: 13,
    color: Colors.green,
    ),
    ),

    ],
    ),

    /// Rejected Reason
    if(status == "REJECTED" && leave["rejected_reason"] != null)

    Padding(
    padding: const EdgeInsets.only(top:6),

    child: Text(
    "Reason: ${leave["rejected_reason"]}",
    style: const TextStyle(
    color: Colors.red,
    fontSize: 13,
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

    },

    ),
    )

    ],
    ),

    );

  }

  /// FILTER BUTTON
  Widget filterButton(String title) {

    bool active = selectedFilter == title;

    return GestureDetector(
    onTap: () {
    setState(() {
    selectedFilter = title;
    });
    },

    child: Container(
    padding: const EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 6,
    ),

    decoration: BoxDecoration(
    color: active ? const Color(0xFF1E4D8F) : Colors.grey.shade300,
    borderRadius: BorderRadius.circular(20),
    ),

    child: Text(
    title,
    style: TextStyle(
    color: active ? Colors.white : Colors.black,
    ),
    ),
    ),
    );

  }

  /// SUMMARY ITEM
  Widget summaryItem(String title, String value, Color color) {
    return Column(
    children: [

    Text(
    value,
    style: TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: color,
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

}
