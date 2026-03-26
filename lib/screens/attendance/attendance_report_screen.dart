import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../services/api_service.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() =>
      _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? summary;
  List<dynamic> detailRecords = [];
  bool loading = true;
  bool loadingDetails = false;

  // Tab controller for Summary / Register tabs
  late TabController _tabController;

  // Month/Year selector (used for Summary tab)
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  // Date-range filter (used for Register/Details tab)
  DateTime? _regStart;
  DateTime? _regEnd;
  bool includeHolidays = false;

  static const List<String> _months = [
    "January","February","March","April","May","June",
    "July","August","September","October","November","December"
  ];

  static const List<String> _monthsShort = [
    "Jan","Feb","Mar","Apr","May","Jun",
    "Jul","Aug","Sep","Oct","Nov","Dec"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && detailRecords.isEmpty) {
        _initRegisterDates();
        _loadDetailRecords();
      }
    });
    // Default register range: current month
    final now = DateTime.now();
    _regStart = DateTime(now.year, now.month, 1);
    _regEnd = DateTime(now.year, now.month + 1, 0);
    loadSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initRegisterDates() {
    if (_regStart == null) {
      final now = DateTime.now();
      _regStart = DateTime(now.year, now.month, 1);
      _regEnd = DateTime(now.year, now.month + 1, 0);
    }
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  String _fmtDate(DateTime d) =>
      "${d.year}-${_pad(d.month)}-${_pad(d.day)}";

  Future<void> loadSummary() async {
    setState(() => loading = true);
    try {
      final start = "$selectedYear-${_pad(selectedMonth)}-01";
      final lastDay = DateTime(selectedYear, selectedMonth + 1, 0).day;
      final end = "$selectedYear-${_pad(selectedMonth)}-${_pad(lastDay)}";

      final data = await ApiService.getAttendanceSummary(
        startDate: start,
        endDate: end,
      );
      setState(() {
        summary = data;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
        );
      }
    }
  }

  Future<void> _loadDetailRecords() async {
    if (_regStart == null || _regEnd == null) return;
    setState(() => loadingDetails = true);
    try {
      final data = await ApiService.getAttendanceHistory(
        startDate: _fmtDate(_regStart!),
        endDate: _fmtDate(_regEnd!),
      );
      setState(() {
        detailRecords = data;
        loadingDetails = false;
      });
    } catch (e) {
      setState(() => loadingDetails = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
        );
      }
    }
  }

  Future<void> _pickRegDate(bool isStart) async {
    final now = DateTime.now();
    DateTime first, last, initial;

    if (isStart) {
      first = DateTime(2025);
      last = _regEnd != null && _regEnd!.isBefore(now) ? _regEnd! : now;
      initial = _regStart ?? last;
      if (initial.isAfter(last)) initial = last;
    } else {
      first = _regStart ?? DateTime(2025);
      last = now;
      initial = _regEnd ?? now;
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
          colorScheme: const ColorScheme.light(primary: Color(0xFF1E4D8F)),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _regStart = picked;
          if (_regEnd != null && picked.isAfter(_regEnd!)) _regEnd = picked;
        } else {
          _regEnd = picked;
        }
      });
    }
  }

  // ── Donut values ────────────────────────────────────────────────────────────
  double get _presentVal =>
      double.tryParse(summary?["present_days"]?.toString() ?? "0") ?? 0;
  double get _absentVal =>
      double.tryParse(summary?["absent_days"]?.toString() ?? "0") ?? 0;
  double get _leaveVal =>
      double.tryParse(summary?["leave_days"]?.toString() ?? "0") ?? 0;
  double get _totalVal => _presentVal + _absentVal + _leaveVal;
  double get _presentPct =>
      _totalVal == 0 ? 0 : (_presentVal / _totalVal * 100);

  // ── Register summary stats ──────────────────────────────────────────────────
  int get _regPresent => detailRecords
      .where((r) =>
  r["status"] == "PRESENT" &&
      !(r["remarks"] ?? "").toString().toLowerCase().contains("leave"))
      .length;
  int get _regAbsent => detailRecords
      .where((r) => r["status"] == "ABSENT")
      .length;
  int get _regLeave => detailRecords
      .where((r) =>
      (r["remarks"] ?? "").toString().toLowerCase().contains("leave"))
      .length;
  int get _regOdl => detailRecords
      .where((r) =>
      (r["remarks"] ?? "").toString().toLowerCase().contains("odl"))
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text(
          "Attendance Report",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E4D8F),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: "Summary"),
            Tab(text: "Attendance Register"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _summaryTab(),
          _registerTab(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1 — SUMMARY
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _summaryTab() {
    return Column(
      children: [
        // Month/Year selector header
        Container(
          color: const Color(0xFF1E4D8F),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Row(
            children: [
              Expanded(
                child: _selectorBox(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedMonth,
                      dropdownColor: const Color(0xFF1E4D8F),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      icon: const Icon(Icons.expand_more_rounded,
                          color: Colors.white),
                      items: List.generate(
                        12,
                            (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(_months[i]),
                        ),
                      ),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => selectedMonth = v);
                          loadSummary();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _selectorBox(
                width: 100,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedYear,
                    dropdownColor: const Color(0xFF1E4D8F),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    icon: const Icon(Icons.expand_more_rounded,
                        color: Colors.white),
                    items: [2025, 2026, 2027]
                        .map((y) => DropdownMenuItem(
                      value: y,
                      child: Text("$y"),
                    ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => selectedYear = v);
                        loadSummary();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: loading
              ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E4D8F)))
              : summary == null
              ? const Center(child: Text("No report available"))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _facultyInfoCard(),
                const SizedBox(height: 16),
                _donutCard(),
                const SizedBox(height: 16),
                _statsGrid(),
                const SizedBox(height: 16),
                _detailCard(),
                const SizedBox(height: 16),
                // Button to switch to Register tab
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E4D8F),
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () =>
                        _tabController.animateTo(1),
                    icon: const Icon(Icons.table_chart_rounded),
                    label: const Text(
                      "View Attendance Register",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2 — ATTENDANCE REGISTER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _registerTab() {
    return Column(
      children: [
        // ── Filter header ─────────────────────────────────────
        Container(
          color: const Color(0xFF1E4D8F),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Date Range",
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _regDateChip(
                      label: "From",
                      value: _regStart != null
                          ? "${_pad(_regStart!.day)}/${_pad(_regStart!.month)}/${_regStart!.year}"
                          : "Select",
                      onTap: () => _pickRegDate(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _regDateChip(
                      label: "To",
                      value: _regEnd != null
                          ? "${_pad(_regEnd!.day)}/${_pad(_regEnd!.month)}/${_regEnd!.year}"
                          : "Select",
                      onTap: () => _pickRegDate(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Include Holidays checkbox
                  GestureDetector(
                    onTap: () =>
                        setState(() => includeHolidays = !includeHolidays),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: includeHolidays,
                            onChanged: (v) =>
                                setState(() => includeHolidays = v ?? false),
                            checkColor: const Color(0xFF1E4D8F),
                            fillColor: WidgetStateProperty.all(Colors.white),
                            side: const BorderSide(
                                color: Colors.white54, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text("Include Holidays",
                            style: TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Show Records button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E4D8F),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _loadDetailRecords,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text("Show Records",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Quick stats strip ────────────────────────────────
        if (detailRecords.isNotEmpty)
          Container(
            color: Colors.white,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _qStat("$_regPresent", "Present", const Color(0xFF16A34A)),
                _divider(),
                _qStat("$_regAbsent", "Absent", const Color(0xFFDC2626)),
                _divider(),
                _qStat("$_regLeave", "Leave", const Color(0xFFF59E0B)),
                _divider(),
                _qStat("${detailRecords.length}", "Total", const Color(0xFF1E4D8F)),
              ],
            ),
          ),

        // ── Table / content ──────────────────────────────────
        Expanded(
          child: loadingDetails
              ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E4D8F)))
              : detailRecords.isEmpty
              ? _registerEmpty()
              : _registerTable(),
        ),
      ],
    );
  }

  Widget _regDateChip({
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
                color: Colors.white70, size: 14),
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

  Widget _qStat(String val, String label, Color color) {
    return Column(
      children: [
        Text(val,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }

  Widget _divider() => Container(
    height: 30,
    width: 1,
    color: Colors.black12,
  );

  Widget _registerEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_chart_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No records for selected period",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black38)),
          const SizedBox(height: 8),
          const Text("Select a date range and tap Show Records",
              style: TextStyle(fontSize: 12, color: Colors.black26)),
        ],
      ),
    );
  }

  Widget _registerTable() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Clean register info header (no college details)
          _registerInfoHeader(),
          // Scrollable horizontal table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildTable(),
          ),
          // Footer summary row
          _footerSummary(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _registerInfoHeader() {
    final facultyName = summary?["faculty_name"] ?? "--";
    final facultyId = summary?["faculty_id"] ?? "--";
    final dept = summary?["department"] ?? "--";
    final fromStr = _regStart != null
        ? "${_pad(_regStart!.day)}/${_pad(_regStart!.month)}/${_regStart!.year}"
        : "--";
    final toStr = _regEnd != null
        ? "${_pad(_regEnd!.day)}/${_pad(_regEnd!.month)}/${_regEnd!.year}"
        : "--";

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E4D8F).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.badge_rounded,
                    color: Color(0xFF1E4D8F), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facultyName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E4D8F)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "ID: $facultyId  ·  $dept",
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Date range pill
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD0DAEF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range_rounded,
                    size: 14, color: Color(0xFF1E4D8F)),
                const SizedBox(width: 6),
                Text(
                  "Attendance Register  ·  $fromStr  →  $toStr",
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E4D8F)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    const headerStyle = TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: Colors.white);
    const cellStyle = TextStyle(fontSize: 12, color: Colors.black87);

    final headerLabels = [
      "Sl.No",
      "Date",
      "Act. In\nTime",
      "In Time",
      "Act. Out\nTime",
      "Out Time",
      "Late By\n(hh:mm)",
      "Early By\n(hh:mm)",
      "Absent",
      "Remarks",
      "Working\nHours",
    ];

    List<DataRow> rows = [];
    for (int i = 0; i < detailRecords.length; i++) {
      final r = detailRecords[i] as Map<String, dynamic>;
      final status = r["status"] ?? "";
      final remarks = (r["remarks"] ?? "").toString();
      final dateStr = r["date"] ?? "";

      final isLeave = remarks.toLowerCase().contains("leave");
      final isAbsent = status == "ABSENT";
      final isLate = remarks.toLowerCase().contains("late");
      final isHalf = remarks.toLowerCase().contains("half");
      final isOdl = remarks.toLowerCase().contains("odl");
      final isSh = remarks.toLowerCase().contains("sh");

      Color rowColor = i % 2 == 0 ? Colors.white : const Color(0xFFF7F9FF);
      if (isLeave) rowColor = const Color(0xFFFFF8E1);
      if (isAbsent && !isLeave) rowColor = const Color(0xFFFFF0F0);

      final wh = r["working_hours"];
      final whStr = (wh != null && wh > 0)
          ? _fmtWorkHours(wh.toDouble())
          : "00:00";

      // Absent cell content
      String absentStr = "";
      if (isAbsent && !isLeave) absentStr = "FD";
      else if (isHalf) absentStr = "HD";

      // Remarks cell — short codes
      String remarkStr = "";
      if (isLeave) remarkStr = "LOP";
      else if (isOdl) remarkStr = "ODL";
      else if (isSh) remarkStr = "SH";
      else if (isLate) remarkStr = "Late";
      else if (remarks.isNotEmpty) remarkStr = _shortRemark(remarks);

      // Late / early placeholders (use API fields if available, else blank)
      final lateBy = r["late_by"] ?? "";
      final earlyBy = r["early_by"] ?? "";

      rows.add(
        DataRow(
          color: WidgetStateProperty.all(rowColor),
          cells: [
            DataCell(Text("${i + 1}",
                style: cellStyle.copyWith(color: Colors.black54))),
            DataCell(SizedBox(
                width: 90,
                child: Text(_displayDate(dateStr),
                    style: cellStyle, maxLines: 1,
                    overflow: TextOverflow.visible))),
            DataCell(Text("09:30 AM", // standard check-in time
                style: cellStyle.copyWith(color: Colors.black45))),
            DataCell(Text(_formatTime(r["clock_in_time"]),
                style: cellStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isAbsent ? Colors.black38 : Colors.black87))),
            DataCell(Text("04:20 PM", // standard check-out time
                style: cellStyle.copyWith(color: Colors.black45))),
            DataCell(Text(_formatTime(r["clock_out_time"]),
                style: cellStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isAbsent ? Colors.black38 : Colors.black87))),
            DataCell(Text(
              lateBy.toString().isNotEmpty ? lateBy.toString() : "",
              style: cellStyle.copyWith(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600),
            )),
            DataCell(Text(
              earlyBy.toString().isNotEmpty ? earlyBy.toString() : "",
              style: cellStyle.copyWith(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600),
            )),
            DataCell(
              absentStr.isNotEmpty
                  ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(absentStr,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626))),
              )
                  : const SizedBox.shrink(),
            ),
            DataCell(
              remarkStr.isNotEmpty
                  ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _remarkColor(remarkStr).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(remarkStr,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _remarkColor(remarkStr))),
              )
                  : const SizedBox.shrink(),
            ),
            DataCell(Text(whStr,
                style: cellStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: whStr == "00:00"
                        ? Colors.black38
                        : const Color(0xFF1E4D8F)))),
          ],
        ),
      );
    }

    return DataTable(
      headingRowColor: WidgetStateProperty.all(const Color(0xFF1E4D8F)),
      headingTextStyle: headerStyle,
      columnSpacing: 16,
      horizontalMargin: 16,
      dataRowMinHeight: 44,
      dataRowMaxHeight: 52,
      headingRowHeight: 52,
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade200, width: 0.8),
        verticalInside: BorderSide(color: Colors.grey.shade300, width: 0.8),
        top: const BorderSide(color: Color(0xFF1E4D8F)),
        bottom: BorderSide(color: Colors.grey.shade300),
        left: const BorderSide(color: Color(0xFF1E4D8F)),
        right: const BorderSide(color: Color(0xFF1E4D8F)),
      ),
      columns: headerLabels
          .map((h) => DataColumn(
        label: Text(h,
            style: headerStyle,
            textAlign: TextAlign.center),
      ))
          .toList(),
      rows: rows,
    );
  }

  Color _remarkColor(String remark) {
    final r = remark.toLowerCase();
    if (r.contains("lop") || r.contains("leave")) return const Color(0xFFF59E0B);
    if (r.contains("odl")) return const Color(0xFF1E4D8F);
    if (r.contains("sh")) return const Color(0xFF7C3AED);
    if (r.contains("late")) return Colors.orange.shade700;
    return Colors.black54;
  }

  Widget _footerSummary() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _footerChip("$_regPresent", "Present", const Color(0xFF16A34A)),
          _footerChip("$_regAbsent", "Absent", const Color(0xFFDC2626)),
          _footerChip("$_regLeave", "Leave", const Color(0xFFF59E0B)),
          if (_regOdl > 0)
            _footerChip("$_regOdl", "ODL", const Color(0xFF1E4D8F)),
        ],
      ),
    );
  }

  Widget _footerChip(String val, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(val,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color)),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _displayDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = [
        "Jan","Feb","Mar","Apr","May","Jun",
        "Jul","Aug","Sep","Oct","Nov","Dec"
      ];
      return "${_pad(d.day)} ${months[d.month - 1]} ${d.year}";
    } catch (_) {
      return dateStr;
    }
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

  String _fmtWorkHours(double wh) {
    final h = wh.floor();
    final m = ((wh - h) * 60).round();
    return "${_pad(h)}:${_pad(m)}";
  }

  String _shortRemark(String r) {
    if (r.toLowerCase().contains("odl")) return "ODL";
    if (r.toLowerCase().contains("half day morning")) return "HDM";
    if (r.toLowerCase().contains("half day afternoon")) return "HDA";
    if (r.toLowerCase().contains("on leave")) return "Leave";
    if (r.length > 8) return r.substring(0, 8);
    return r;
  }

  String _formatHours(dynamic wh) {
    if (wh == null) return "0h 0m";
    final total = double.tryParse(wh.toString()) ?? 0.0;
    final h = total.floor();
    final m = ((total - h) * 60).round();
    return "${h}h ${m.toString().padLeft(2, '0')}m";
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUMMARY TAB WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _selectorBox({required Widget child, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white30),
      ),
      child: child,
    );
  }

  Widget _facultyInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF1E4D8F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(Icons.person_rounded,
                color: Color(0xFF1E4D8F), size: 28),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary?["faculty_name"] ?? "--",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1E4D8F)),
              ),
              const SizedBox(height: 2),
              Text(
                "ID: ${summary?["faculty_id"] ?? "--"}",
                style:
                const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Text(
                "${summary?["department"] ?? "--"}",
                style:
                const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _months[selectedMonth - 1],
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E4D8F)),
              ),
              Text(
                "$selectedYear",
                style:
                const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _donutCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(120, 120),
                  painter: _DonutPainter(
                    present: _presentVal,
                    absent: _absentVal,
                    leave: _leaveVal,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${_presentPct.toStringAsFixed(0)}%",
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E4D8F)),
                    ),
                    const Text("Present",
                        style:
                        TextStyle(fontSize: 11, color: Colors.black45)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legendRow(
                  "Present", _presentVal, _totalVal, const Color(0xFF16A34A)),
              const SizedBox(height: 10),
              _legendRow(
                  "Absent", _absentVal, _totalVal, const Color(0xFFDC2626)),
              const SizedBox(height: 10),
              _legendRow(
                  "On Leave", _leaveVal, _totalVal, const Color(0xFFF59E0B)),
              const SizedBox(height: 10),
              _legendRow(
                  "Total", _totalVal, _totalVal, const Color(0xFF1E4D8F),
                  isTotal: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendRow(String label, double value, double total, Color color,
      {bool isTotal = false}) {
    final pct = total == 0 ? 0.0 : (value / total * 100);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        const SizedBox(width: 8),
        Text(
          isTotal
              ? "${value.toInt()}"
              : "${value.toInt()} (${pct.toStringAsFixed(0)}%)",
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _statsGrid() {
    final items = [
      {
        "label": "Working Hours",
        "value": _formatHours(summary?["total_working_hours"]),
        "icon": Icons.access_time_rounded,
        "color": const Color(0xFF1E4D8F),
      },
      {
        "label": "Late Entries",
        "value": "${summary?["late_entries"] ?? 0}",
        "icon": Icons.watch_later_rounded,
        "color": const Color(0xFFF59E0B),
      },
      {
        "label": "Permissions",
        "value": "${summary?["permissions_used"] ?? 0} / 3",
        "icon": Icons.verified_rounded,
        "color": const Color(0xFF7C3AED),
      },
      {
        "label": "Auto Absent",
        "value": "${summary?["auto_absent_count"] ?? 0}",
        "icon": Icons.computer_rounded,
        "color": const Color(0xFFDC2626),
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.0,
      children: items.map((item) {
        final color = item["color"] as Color;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(item["icon"] as IconData, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item["value"] as String,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: color)),
                  Text(item["label"] as String,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _detailCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Detailed Breakdown",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1E4D8F)),
          ),
          const SizedBox(height: 12),
          _detailRow(
              "Present Days", "${summary?["present_days"] ?? 0}", Colors.green),
          _detailRow(
              "Absent Days", "${summary?["absent_days"] ?? 0}", Colors.red),
          _detailRow(
              "Leave Days", "${summary?["leave_days"] ?? 0}", Colors.orange),
          _detailRow("Late Entries",
              "${summary?["late_entries"] ?? 0}", Colors.amber.shade700),
          _detailRow("Permissions Used",
              "${summary?["permissions_used"] ?? 0}", Colors.purple),
          _detailRow("Auto-Marked Absent",
              "${summary?["auto_absent_count"] ?? 0}", Colors.red.shade400),
          _detailRow("Total Working Hours",
              _formatHours(summary?["total_working_hours"]),
              const Color(0xFF1E4D8F)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                  width: 4,
                  height: 16,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2))),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black87)),
            ],
          ),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color)),
        ],
      ),
    );
  }
}

// ── Donut Chart Painter ──────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final double present;
  final double absent;
  final double leave;

  _DonutPainter(
      {required this.present, required this.absent, required this.leave});

  @override
  void paint(Canvas canvas, Size size) {
    final total = present + absent + leave;
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 18.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final presentSweep = (present / total) * 2 * math.pi;
    final absentSweep = (absent / total) * 2 * math.pi;
    final leaveSweep = (leave / total) * 2 * math.pi;

    final rect = Rect.fromCircle(center: center, radius: radius);

    paint.color = const Color(0xFFE5E7EB);
    canvas.drawCircle(center, radius, paint);

    if (presentSweep > 0) {
      paint.color = const Color(0xFF16A34A);
      canvas.drawArc(rect, startAngle, presentSweep, false, paint);
    }
    if (absentSweep > 0) {
      paint.color = const Color(0xFFDC2626);
      canvas.drawArc(
          rect, startAngle + presentSweep, absentSweep, false, paint);
    }
    if (leaveSweep > 0) {
      paint.color = const Color(0xFFF59E0B);
      canvas.drawArc(
          rect, startAngle + presentSweep + absentSweep, leaveSweep, false,
          paint);
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.present != present ||
          oldDelegate.absent != absent ||
          oldDelegate.leave != leave;
}