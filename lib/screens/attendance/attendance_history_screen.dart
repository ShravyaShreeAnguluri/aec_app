import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<dynamic> history = [];
  bool loading = true;

  DateTime? _startDate;
  DateTime? _endDate;

  // Summary counts
  int presentCount = 0;
  int absentCount = 0;
  int leaveCount = 0;

  @override
  void initState() {
    super.initState();
    // Default: current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    loadHistory();
  }

  String _fmt(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<void> loadHistory() async {
    setState(() => loading = true);
    try {
      final data = await ApiService.getAttendanceHistory(
        startDate: _startDate != null ? _fmt(_startDate!) : null,
        endDate: _endDate != null ? _fmt(_endDate!) : null,
      );
      setState(() {
        history = data;
        loading = false;
        _computeSummary();
      });
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
              Text(e.toString().replaceAll("Exception: ", ""))),
        );
      }
    }
  }

  void _computeSummary() {
    presentCount = 0;
    absentCount = 0;
    leaveCount = 0;
    for (final item in history) {
      final status = item["status"] ?? "";
      final remarks = (item["remarks"] ?? "").toString().toLowerCase();
      if (remarks.contains("leave")) {
        leaveCount++;
      } else if (status == "PRESENT") {
        presentCount++;
      } else if (status == "ABSENT") {
        absentCount++;
      }
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();

    // ── FIX: clamp initialDate so it's never after lastDate ──
    DateTime initial;
    DateTime first;
    DateTime last;

    if (isStart) {
      last = _endDate != null && _endDate!.isBefore(now)
          ? _endDate!
          : now;
      initial = _startDate ?? last;
      // clamp initial between firstDate and last
      if (initial.isAfter(last)) initial = last;
      first = DateTime(2025);
    } else {
      // "To" picker
      first = _startDate ?? DateTime(2025);
      last = now;
      initial = _endDate ?? now;
      // clamp: initial must be between first and last
      if (initial.isBefore(first)) initial = first;
      if (initial.isAfter(last)) initial = last;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1E4D8F),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // If new start is after current end, reset end
          if (_endDate != null && picked.isAfter(_endDate!)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
        }
      });
      loadHistory();
    }
  }

  String _displayDate(DateTime? d) {
    if (d == null) return "Select";
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
  }

  Color _statusColor(String status, String remarks) {
    final r = remarks.toLowerCase();
    if (r.contains("leave")) return const Color(0xFFF59E0B);
    if (status == "PRESENT") return const Color(0xFF16A34A);
    if (status == "ABSENT") return const Color(0xFFDC2626);
    return Colors.grey;
  }

  IconData _statusIcon(String status, String remarks) {
    final r = remarks.toLowerCase();
    if (r.contains("leave")) return Icons.event_note_rounded;
    if (status == "PRESENT") return Icons.check_circle_rounded;
    if (status == "ABSENT") return Icons.cancel_rounded;
    return Icons.help_outline_rounded;
  }

  String _statusLabel(String status, String remarks) {
    final r = remarks.toLowerCase();
    if (r.contains("leave")) return "On Leave";
    return status;
  }

  String _formatTime(dynamic t) {
    if (t == null || t.toString().isEmpty || t.toString() == "null")
      return "--";
    final parts = t.toString().split(":");
    if (parts.length < 2) return t.toString();
    int h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1].padLeft(2, '0');
    final suffix = h >= 12 ? "PM" : "AM";
    h = h % 12;
    if (h == 0) h = 12;
    return "$h:$m $suffix";
  }

  String _formatHours(dynamic wh) {
    if (wh == null) return "0h 0m";
    final total = double.tryParse(wh.toString()) ?? 0.0;
    final h = total.floor();
    final m = ((total - h) * 60).round();
    return "${h}h ${m.toString().padLeft(2, '0')}m";
  }

  String _dayLabel(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      return days[d.weekday - 1];
    } catch (_) {
      return "";
    }
  }

  String _monthLabel(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = [
        "Jan","Feb","Mar","Apr","May","Jun",
        "Jul","Aug","Sep","Oct","Nov","Dec"
      ];
      return months[d.month - 1];
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text(
          "Attendance History",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E4D8F),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Summary Banner ──────────────────────────────────
          Container(
            color: const Color(0xFF1E4D8F),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              children: [
                // Date Filter Row
                Row(
                  children: [
                    Expanded(
                      child: _dateChip(
                        label: "From",
                        value: _displayDate(_startDate),
                        onTap: () => _pickDate(true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dateChip(
                        label: "To",
                        value: _displayDate(_endDate),
                        onTap: () => _pickDate(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Summary pills
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryPill(
                        "$presentCount", "Present", const Color(0xFF4ADE80)),
                    _summaryPill(
                        "$absentCount", "Absent", const Color(0xFFF87171)),
                    _summaryPill(
                        "$leaveCount", "On Leave", const Color(0xFFFBBF24)),
                    _summaryPill(
                        "${history.length}", "Total", Colors.white70),
                  ],
                ),
              ],
            ),
          ),

          // ── List ───────────────────────────────────────────
          Expanded(
            child: loading
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1E4D8F)))
                : history.isEmpty
                ? _emptyState()
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (_, i) =>
                  _historyCard(history[i] as Map<String, dynamic>),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white30),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: Colors.white70, size: 15),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10)),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryPill(String count, String label, Color color) {
    return Column(
      children: [
        Text(count,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
        Text(label,
            style: TextStyle(color: color.withOpacity(0.85), fontSize: 11)),
      ],
    );
  }

  Widget _historyCard(Map<String, dynamic> item) {
    final status = item["status"] ?? "";
    final remarks = item["remarks"] ?? "--";
    final dateStr = item["date"] ?? "";
    final color = _statusColor(status, remarks);
    final icon = _statusIcon(status, remarks);
    final label = _statusLabel(status, remarks);
    final isLate = remarks.toString().toLowerCase().contains("late");
    final isHalfDay = remarks.toString().toLowerCase().contains("half day");

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left color bar + date
            Container(
              width: 64,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dateStr.length >= 10 ? dateStr.substring(8, 10) : "--",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                  Text(
                    dateStr.length >= 10 ? _monthLabel(dateStr) : "",
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr.length >= 10 ? _dayLabel(dateStr) : "",
                    style:
                    TextStyle(fontSize: 10, color: color.withOpacity(0.7)),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(icon, color: color, size: 17),
                            const SizedBox(width: 5),
                            Text(label,
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ],
                        ),
                        if (isLate)
                          _tag("Late", Colors.orange)
                        else if (isHalfDay)
                          _tag("Half Day", Colors.purple),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Time row
                    Row(
                      children: [
                        _timeBlock(
                            Icons.login_rounded,
                            "In",
                            _formatTime(item["clock_in_time"])),
                        const SizedBox(width: 16),
                        _timeBlock(
                            Icons.logout_rounded,
                            "Out",
                            _formatTime(item["clock_out_time"])),
                        const Spacer(),
                        if ((item["working_hours"] ?? 0) > 0)
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  size: 13, color: Colors.black38),
                              const SizedBox(width: 3),
                              Text(
                                _formatHours(item["working_hours"]),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (remarks != "--" && remarks.toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        remarks,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeBlock(IconData icon, String label, String time) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.black38),
        const SizedBox(width: 3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                const TextStyle(fontSize: 9, color: Colors.black38)),
            Text(time,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
          ],
        ),
      ],
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No attendance records found",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black38)),
          const SizedBox(height: 8),
          const Text("Try adjusting the date range",
              style: TextStyle(fontSize: 13, color: Colors.black26)),
        ],
      ),
    );
  }
}