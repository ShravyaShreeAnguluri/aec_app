import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class _C {
  static const navy = Color(0xFF0A2342);
  static const navyMid = Color(0xFF1B3F72);
  static const navyLight = Color(0xFF2E5FA3);
  static const teal = Color(0xFF0077B6);
  static const bg = Color(0xFFF2F5FB);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4EAF4);
  static const success = Color(0xFF0A7953);
  static const successBg = Color(0xFFE6F4EF);
  static const danger = Color(0xFFB91C1C);
  static const dangerBg = Color(0xFFFEE2E2);
  static const gold = Color(0xFFB45309);
  static const goldBg = Color(0xFFFEF3C7);
  static const purple = Color(0xFF5B21B6);
  static const purpleBg = Color(0xFFEDE9FE);
  static const textPrimary = Color(0xFF0F172A);
  static const textSub = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
}

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic> _overview = {};

  DateTime? _startDate;
  DateTime? _endDate;

  int _activePreset = 0; // 0 this month, 1 last 7 days, 2 last 30 days, 3 custom

  late AnimationController _headerCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerFade;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic),
    );
    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _headerCtrl, curve: Curves.easeIn),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear),
    );

    _headerCtrl.forward();
    _applyPreset(0);
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(int preset) {
    final now = DateTime.now();
    setState(() {
      _activePreset = preset;
      switch (preset) {
        case 0:
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 1:
          _startDate = now.subtract(const Duration(days: 6));
          _endDate = now;
          break;
        case 2:
          _startDate = now.subtract(const Duration(days: 29));
          _endDate = now;
          break;
        case 3:
          break;
      }
    });
    _loadReport();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _C.navy,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _activePreset = 3;
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });

      if (_startDate != null &&
          _endDate != null &&
          _startDate!.isAfter(_endDate!)) {
        final temp = _startDate;
        _startDate = _endDate;
        _endDate = temp;
      }

      await _loadReport();
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _display(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _loadReport() async {
    if (_startDate == null || _endDate == null) return;

    setState(() => _loading = true);

    try {
      final data = await ApiService.getAdminAttendanceOverview(
        startDate: _fmt(_startDate!),
        endDate: _fmt(_endDate!),
      );

      if (!mounted) return;

      setState(() {
        _overview = Map<String, dynamic>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _safe(dynamic value, {String fb = '0'}) {
    if (value == null) return fb;
    return value.toString();
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  double get _attendancePct {
    final total = _asInt(_overview['total_records']);
    final present = _asInt(_overview['present_records']);
    if (total == 0) return 0;
    return (present / total) * 100;
  }

  double get _absentPct {
    final total = _asInt(_overview['total_records']);
    final absent = _asInt(_overview['absent_records']);
    if (total == 0) return 0;
    return (absent / total) * 100;
  }

  double get _leavePct {
    final total = _asInt(_overview['total_records']);
    final leave = _asInt(_overview['leave_records']);
    if (total == 0) return 0;
    return (leave / total) * 100;
  }

  double get _latePct {
    final total = _asInt(_overview['total_records']);
    final late = _asInt(_overview['late_entries']);
    if (total == 0) return 0;
    return (late / total) * 100;
  }

  Color get _attendanceColor {
    if (_attendancePct >= 75) return _C.success;
    if (_attendancePct >= 50) return _C.gold;
    return _C.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _C.navy,
          onRefresh: _loadReport,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SlideTransition(
                        position: _headerSlide,
                        child: FadeTransition(
                          opacity: _headerFade,
                          child: _buildTopHeader(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildPresetRow(),
                      const SizedBox(height: 14),
                      _buildDateRangeCard(),
                      const SizedBox(height: 18),
                      if (_loading) _buildShimmer() else _buildContent(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.navy, _C.navyMid, _C.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _C.navy.withOpacity(0.20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _loadReport,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Reports & Analytics',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Institution-level attendance insights for admin monitoring and decision-making.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13.2,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(
                icon: Icons.analytics_rounded,
                label: '${_attendancePct.toStringAsFixed(1)}% Attendance',
              ),
              _HeroPill(
                icon: Icons.dataset_rounded,
                label: '${_safe(_overview['total_records'])} Records',
              ),
              _HeroPill(
                icon: Icons.access_time_filled_rounded,
                label: '${_safe(_overview['total_working_hours'], fb: '0')} hrs',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _PresetChip(
            label: 'This Month',
            selected: _activePreset == 0,
            onTap: () => _applyPreset(0),
          ),
          const SizedBox(width: 8),
          _PresetChip(
            label: 'Last 7 Days',
            selected: _activePreset == 1,
            onTap: () => _applyPreset(1),
          ),
          const SizedBox(width: 8),
          _PresetChip(
            label: 'Last 30 Days',
            selected: _activePreset == 2,
            onTap: () => _applyPreset(2),
          ),
          const SizedBox(width: 8),
          _PresetChip(
            label: 'Custom',
            selected: _activePreset == 3,
            onTap: () => setState(() => _activePreset = 3),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(
            title: 'Report Period',
            icon: Icons.date_range_rounded,
            color: _C.teal,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DateBox(
                  label: 'Start Date',
                  value: _startDate == null ? '-' : _display(_startDate!),
                  icon: Icons.calendar_month_rounded,
                  onTap: () => _pickDate(isStart: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateBox(
                  label: 'End Date',
                  value: _endDate == null ? '-' : _display(_endDate!),
                  icon: Icons.event_rounded,
                  onTap: () => _pickDate(isStart: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          child: Column(
            children: [
              const _SectionLabel(
                title: 'Attendance Rate',
                icon: Icons.donut_large_rounded,
                color: _C.navy,
              ),
              const SizedBox(height: 18),
              _AttendanceDonut(
                presentPct: _attendancePct,
                absentPct: _absentPct,
                leavePct: _leavePct,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 8,
                children: const [
                  _LegendDot(color: _C.success, label: 'Present'),
                  _LegendDot(color: _C.danger, label: 'Absent'),
                  _LegendDot(color: _C.gold, label: 'Leave'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        const _SectionLabel(
          title: 'Key Metrics',
          icon: Icons.bar_chart_rounded,
          color: _C.navyLight,
        ),
        const SizedBox(height: 10),

        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.28,
          children: [
            _MetricCard(
              icon: Icons.dataset_rounded,
              label: 'Total Records',
              value: _safe(_overview['total_records']),
              color: _C.navyLight,
            ),
            _MetricCard(
              icon: Icons.check_circle_rounded,
              label: 'Present',
              value: _safe(_overview['present_records']),
              color: _C.success,
            ),
            _MetricCard(
              icon: Icons.cancel_rounded,
              label: 'Absent',
              value: _safe(_overview['absent_records']),
              color: _C.danger,
            ),
            _MetricCard(
              icon: Icons.event_busy_rounded,
              label: 'On Leave',
              value: _safe(_overview['leave_records']),
              color: _C.gold,
            ),
            _MetricCard(
              icon: Icons.schedule_rounded,
              label: 'Late Entries',
              value: _safe(_overview['late_entries']),
              color: _C.purple,
            ),
            _MetricCard(
              icon: Icons.auto_mode_rounded,
              label: 'Auto-Absent',
              value: _safe(_overview['auto_marked_absent']),
              color: _C.teal,
            ),
          ],
        ),

        const SizedBox(height: 16),

        _Card(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_C.navy, _C.navyLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.access_time_filled_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Working Hours',
                      style: TextStyle(
                        fontSize: 13,
                        color: _C.textSub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_safe(_overview['total_working_hours'], fb: '0')} hrs',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _C.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_startDate == null ? '-' : _display(_startDate!)}  →  ${_endDate == null ? '-' : _display(_endDate!)}',
                      style: const TextStyle(
                        fontSize: 11.8,
                        color: _C.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel(
                title: 'Period Summary',
                icon: Icons.insights_rounded,
                color: _C.teal,
              ),
              const SizedBox(height: 14),
              _InsightRow(
                label: 'Attendance Rate',
                value: '${_attendancePct.toStringAsFixed(1)}%',
                color: _attendanceColor,
              ),
              const SizedBox(height: 8),
              _InsightRow(
                label: 'Absent Rate',
                value: '${_absentPct.toStringAsFixed(1)}%',
                color: _C.danger,
              ),
              const SizedBox(height: 8),
              _InsightRow(
                label: 'Leave Rate',
                value: '${_leavePct.toStringAsFixed(1)}%',
                color: _C.gold,
              ),
              const SizedBox(height: 8),
              _InsightRow(
                label: 'Late Entry Rate',
                value: '${_latePct.toStringAsFixed(1)}%',
                color: _C.purple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) => Column(
        children: [
          _shimBlock(235),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _shimBlock(100)),
              const SizedBox(width: 12),
              Expanded(child: _shimBlock(100)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _shimBlock(100)),
              const SizedBox(width: 12),
              Expanded(child: _shimBlock(100)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _shimBlock(100)),
              const SizedBox(width: 12),
              Expanded(child: _shimBlock(100)),
            ],
          ),
          const SizedBox(height: 14),
          _shimBlock(92),
          const SizedBox(height: 14),
          _shimBlock(160),
        ],
      ),
    );
  }

  Widget _shimBlock(double h) {
    return Container(
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment(-1.5 + _shimmer.value, 0),
          end: Alignment(1.5 + _shimmer.value, 0),
          colors: const [
            Color(0xFFE7EDF4),
            Color(0xFFF9FBFD),
            Color(0xFFE7EDF4),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionLabel({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: _C.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _C.navy : _C.card;
    final fg = selected ? Colors.white : _C.textSub;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _C.navy : _C.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _DateBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _C.navy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _C.navy, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: _C.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.textPrimary,
                      fontSize: 13.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _C.textSub,
              fontSize: 12.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InsightRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _C.textPrimary,
                fontSize: 13.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: _C.textSub,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AttendanceDonut extends StatefulWidget {
  final double presentPct;
  final double absentPct;
  final double leavePct;

  const _AttendanceDonut({
    required this.presentPct,
    required this.absentPct,
    required this.leavePct,
  });

  @override
  State<_AttendanceDonut> createState() => _AttendanceDonutState();
}

class _AttendanceDonutState extends State<_AttendanceDonut>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final factor = _anim.value;

        return SizedBox(
          width: 172,
          height: 172,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(172, 172),
                painter: _DonutPainter(
                  present: (widget.presentPct / 100) * factor,
                  absent: (widget.absentPct / 100) * factor,
                  leave: (widget.leavePct / 100) * factor,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(widget.presentPct * factor).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: widget.presentPct >= 75
                          ? _C.success
                          : widget.presentPct >= 50
                          ? _C.gold
                          : _C.danger,
                    ),
                  ),
                  const Text(
                    'Present',
                    style: TextStyle(
                      fontSize: 12,
                      color: _C.textSub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double present;
  final double absent;
  final double leave;

  _DonutPainter({
    required this.present,
    required this.absent,
    required this.leave,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;

    final base = Paint()
      ..color = const Color(0xFFE7EDF5)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final presentPaint = Paint()
      ..color = _C.success
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final absentPaint = Paint()
      ..color = _C.danger
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leavePaint = Paint()
      ..color = _C.gold
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, base);

    double start = -math.pi / 2;
    final presentSweep = 2 * math.pi * present;
    final absentSweep = 2 * math.pi * absent;
    final leaveSweep = 2 * math.pi * leave;

    if (presentSweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        presentSweep,
        false,
        presentPaint,
      );
      start += presentSweep;
    }

    if (absentSweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        absentSweep,
        false,
        absentPaint,
      );
      start += absentSweep;
    }

    if (leaveSweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        leaveSweep,
        false,
        leavePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.present != present ||
        oldDelegate.absent != absent ||
        oldDelegate.leave != leave;
  }
}