import 'dart:ui';
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

  Color statusColor(String status) {
    if (status == "APPROVED") return Colors.green;
    if (status == "REJECTED") return Colors.red;
    if (status == "CANCELLED") return Colors.deepOrange;
    return Colors.orange;
  }

  IconData statusIcon(String status) {
    if (status == "APPROVED") return Icons.verified_rounded;
    if (status == "REJECTED") return Icons.cancel_rounded;
    if (status == "CANCELLED") return Icons.block_rounded;
    return Icons.hourglass_top_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final filteredLeaves = selectedFilter == "ALL"
        ? leaves
        : leaves.where((l) => l["status"] == selectedFilter).toList();

    final approvedCount =
    leaves.where((l) => l["status"] == "APPROVED").length.toString();
    final pendingCount =
    leaves.where((l) => l["status"] == "PENDING").length.toString();
    final rejectedCount =
    leaves.where((l) => l["status"] == "REJECTED").length.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FB),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Leave History",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E4D8F),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF1E4D8F),
          elevation: 10,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            "Apply Leave",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          onPressed: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (context) => ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
                child: const ApplyLeaveScreen(),
              ),
            );

            loadLeaves();
          },
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          const SizedBox(height: 10),

          /// COMPACT PREMIUM OVERVIEW
          Container(
            margin:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
                        color: const Color(0xFF1E4D8F).withOpacity(0.10),
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
                            Icons.assignment_rounded,
                            color: Color(0xFF1E4D8F),
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
                            child: compactSummaryCard(
                              title: "Approved",
                              value: approvedCount,
                              color: Colors.green,
                              icon: Icons.check_circle_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: compactSummaryCard(
                              title: "Pending",
                              value: pendingCount,
                              color: Colors.orange,
                              icon: Icons.pending_actions_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: compactSummaryCard(
                              title: "Rejected",
                              value: rejectedCount,
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

          /// FILTER BUTTONS
          Padding(
            padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  filterButton("ALL"),
                  const SizedBox(width: 8),
                  filterButton("PENDING"),
                  const SizedBox(width: 8),
                  filterButton("APPROVED"),
                  const SizedBox(width: 8),
                  filterButton("REJECTED"),
                  const SizedBox(width: 8),
                  filterButton("CANCELLED"),
                  const SizedBox(width: 8),
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
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
              itemCount: filteredLeaves.length,
              itemBuilder: (context, index) {
                final leave = filteredLeaves[index];
                final status = leave["status"];

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                          sigmaX: 12, sigmaY: 12),
                      child: Container(
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
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 150,
                              decoration: BoxDecoration(
                                color: statusColor(status),
                                borderRadius:
                                const BorderRadius.only(
                                  topLeft: Radius.circular(22),
                                  bottomLeft: Radius.circular(22),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            leave["leave_type"],
                                            style: const TextStyle(
                                              fontWeight:
                                              FontWeight.w700,
                                              fontSize: 18,
                                              color:
                                              Color(0xFF1F2937),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor(
                                                status)
                                                .withOpacity(0.12),
                                            borderRadius:
                                            BorderRadius
                                                .circular(20),
                                            border: Border.all(
                                              color: statusColor(
                                                  status)
                                                  .withOpacity(0.20),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize:
                                            MainAxisSize.min,
                                            children: [
                                              Icon(
                                                statusIcon(status),
                                                size: 14,
                                                color: statusColor(
                                                    status),
                                              ),
                                              const SizedBox(
                                                  width: 5),
                                              Text(
                                                status,
                                                style: TextStyle(
                                                  color: statusColor(
                                                      status),
                                                  fontWeight:
                                                  FontWeight
                                                      .w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    infoRow(
                                      Icons.calendar_month_rounded,
                                      "${leave["start_date"].toString().substring(0, 10)}  →  ${leave["end_date"].toString().substring(0, 10)}",
                                    ),
                                    if (leave["total_days"] != null)
                                      Padding(
                                        padding:
                                        const EdgeInsets.only(
                                            top: 8),
                                        child: infoRow(
                                          Icons.timelapse_rounded,
                                          "${leave["total_days"]} Day(s)",
                                        ),
                                      ),
                                    if (leave["reason"] != null)
                                      Padding(
                                        padding:
                                        const EdgeInsets.only(
                                            top: 8),
                                        child: infoRow(
                                          Icons.notes_rounded,
                                          leave["reason"],
                                        ),
                                      ),
                                    if (status == "PENDING")
                                      Padding(
                                        padding:
                                        const EdgeInsets.only(
                                            top: 12),
                                        child: Align(
                                          alignment:
                                          Alignment.centerLeft,
                                          child: TextButton.icon(
                                            style: TextButton
                                                .styleFrom(
                                              foregroundColor:
                                              Colors.red,
                                              padding:
                                              const EdgeInsets
                                                  .symmetric(
                                                horizontal: 4,
                                                vertical: 4,
                                              ),
                                            ),
                                            onPressed: () async {
                                              await ApiService
                                                  .cancelLeave(
                                                  leave["id"]);
                                              loadLeaves();
                                            },
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              "Cancel Leave",
                                              style: TextStyle(
                                                fontWeight:
                                                FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (leave["approved_by_role"] !=
                                        null)
                                      Padding(
                                        padding:
                                        const EdgeInsets.only(
                                            top: 10),
                                        child: Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green
                                                .withOpacity(0.08),
                                            borderRadius:
                                            BorderRadius
                                                .circular(14),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.verified,
                                                size: 16,
                                                color: Colors.green,
                                              ),
                                              const SizedBox(
                                                  width: 6),
                                              Expanded(
                                                child: Text(
                                                  "Approved by ${leave["approved_by_role"].toString().toUpperCase()}",
                                                  style:
                                                  const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors
                                                        .green,
                                                    fontWeight:
                                                    FontWeight
                                                        .w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (status == "REJECTED" &&
                                        leave["rejected_reason"] !=
                                            null)
                                      Padding(
                                        padding:
                                        const EdgeInsets.only(
                                            top: 10),
                                        child: Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red
                                                .withOpacity(0.08),
                                            borderRadius:
                                            BorderRadius
                                                .circular(14),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                            children: [
                                              const Icon(
                                                Icons.info_rounded,
                                                size: 16,
                                                color: Colors.red,
                                              ),
                                              const SizedBox(
                                                  width: 6),
                                              Expanded(
                                                child: Text(
                                                  "Reason: ${leave["rejected_reason"]}",
                                                  style:
                                                  const TextStyle(
                                                    color:
                                                    Colors.red,
                                                    fontSize: 13,
                                                    fontWeight:
                                                    FontWeight
                                                        .w500,
                                                  ),
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
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
          color: const Color(0xFF1E4D8F),
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

  Widget filterButton(String title) {
    bool active = selectedFilter == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF1E4D8F)
              : Colors.white.withOpacity(0.78),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active
                ? const Color(0xFF1E4D8F)
                : Colors.grey.withOpacity(0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: active
                  ? const Color(0xFF1E4D8F).withOpacity(0.18)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget compactSummaryCard({
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
}