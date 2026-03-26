import 'dart:ui';
import 'package:flutter/material.dart';
import '../../screens/leave/leave_history_screen.dart';
import '../../services/api_service.dart';

class DeanLeaveScreen extends StatefulWidget {
  const DeanLeaveScreen({super.key});

  @override
  State<DeanLeaveScreen> createState() => _DeanLeaveScreenState();
}

class _DeanLeaveScreenState extends State<DeanLeaveScreen> {
  List _allDeanLeaves = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    try {
      final data = await ApiService.getHodLeaves();
      if (!mounted) return;
      setState(() {
        _allDeanLeaves = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List get _hodLeaves =>
      _allDeanLeaves.where((l) => (l['role'] ?? '') == 'HOD').toList();

  List get _escalatedLeaves => _allDeanLeaves
      .where((l) => (l['role'] ?? '') == 'FACULTY ESCALATED')
      .toList();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FB),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF1E4D8F),
          onRefresh: _loadLeaves,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Leaves',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage your leaves, HOD requests & escalated faculty requests',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                _LeaveActionCard(
                  title: 'My Leaves',
                  subtitle: 'View your leave history,\nstatus & applied leaves',
                  icon: Icons.event_note_rounded,
                  gradient: const [Color(0xFF0A7953), Color(0xFF0D9A69)],
                  glowColor: const Color(0xFF0A7953),
                  badgeLabel: 'History',
                  badgeColor: const Color(0xFFE6F4EF),
                  badgeTextColor: const Color(0xFF0A7953),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LeaveHistoryScreen(),
                      ),
                    );
                    _loadLeaves();
                  },
                ),
                const SizedBox(height: 16),

                _LeaveActionCard(
                  title: 'HOD Leaves',
                  subtitle: 'Review & approve HOD\nleave applications',
                  icon: Icons.account_balance_rounded,
                  gradient: const [Color(0xFF9A3412), Color(0xFFEA580C)],
                  glowColor: const Color(0xFFEA580C),
                  badgeLabel: '${_hodLeaves.length}',
                  badgeColor: const Color(0xFFFFF7ED),
                  badgeTextColor: const Color(0xFFE65100),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeanApprovalListScreen(
                          title: 'HOD Leave Requests',
                          filterRole: 'HOD',
                        ),
                      ),
                    );
                    _loadLeaves();
                  },
                ),
                const SizedBox(height: 16),

                _LeaveActionCard(
                  title: 'Faculty Escalated Leaves',
                  subtitle: 'Review escalated faculty\nleave applications',
                  icon: Icons.trending_up_rounded,
                  gradient: const [Color(0xFF1E4D8F), Color(0xFF3A72C8)],
                  glowColor: const Color(0xFF1E4D8F),
                  badgeLabel: '${_escalatedLeaves.length}',
                  badgeColor: const Color(0xFFEAF2FF),
                  badgeTextColor: const Color(0xFF1E4D8F),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeanApprovalListScreen(
                          title: 'Faculty Escalated Leaves',
                          filterRole: 'FACULTY ESCALATED',
                        ),
                      ),
                    );
                    _loadLeaves();
                  },
                ),
                const SizedBox(height: 24),

                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Header(
                          title: 'Separate Request Counts',
                          icon: Icons.insights_rounded,
                          color: Color(0xFF1E4D8F),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniCountTile(
                                title: 'HOD Leaves',
                                subtitle: 'Total requests',
                                value: _hodLeaves.length.toString(),
                                color: const Color(0xFFEA580C),
                                icon: Icons.account_balance_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniCountTile(
                                title: 'Escalated',
                                subtitle: 'Faculty requests',
                                value: _escalatedLeaves.length.toString(),
                                color: const Color(0xFF1E4D8F),
                                icon: Icons.trending_up_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DeanApprovalListScreen extends StatefulWidget {
  final String title;
  final String filterRole;

  const DeanApprovalListScreen({
    super.key,
    required this.title,
    required this.filterRole,
  });

  @override
  State<DeanApprovalListScreen> createState() => _DeanApprovalListScreenState();
}

class _DeanApprovalListScreenState extends State<DeanApprovalListScreen> {
  List leaves = [];
  String selectedTab = 'PENDING';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadLeaves();
  }

  Future<void> loadLeaves() async {
    try {
      final data = await ApiService.getHodLeaves();
      if (!mounted) return;
      setState(() {
        leaves = data
            .where((l) => (l['role'] ?? '').toString() == widget.filterRole)
            .toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> approveLeave(int id) async {
    await ApiService.approveLeave(id);
    await loadLeaves();
  }

  Future<void> rejectLeave(int id) async {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Reject Leave',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(
              hintText: 'Enter reason',
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
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                await ApiService.rejectLeave(id, reasonController.text);
                if (!mounted) return;
                Navigator.pop(context);
                await loadLeaves();
              },
              child: const Text(
                'Reject',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Color statusColor(String status) {
    if (status == 'APPROVED') return Colors.green;
    if (status == 'REJECTED') return Colors.red;
    return Colors.orange;
  }

  IconData statusIcon(String status) {
    if (status == 'APPROVED') return Icons.check_circle_rounded;
    if (status == 'REJECTED') return Icons.cancel_rounded;
    return Icons.pending_actions_rounded;
  }

  Widget compactStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget filterButton(String label) {
    final selected = selectedTab == label;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E4D8F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF1E4D8F)
                : const Color(0xFFD8E3F2),
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: const Color(0xFF1E4D8F).withOpacity(0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF475569),
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF1E4D8F), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF374151),
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget leaveCard(Map leave) {
    final status = (leave['status'] ?? 'PENDING').toString().toUpperCase();
    final emergency =
        (leave['leave_type'] ?? '').toString().toLowerCase() == 'emergency';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                        const Color(0xFF1E4D8F).withOpacity(0.10),
                        child: Icon(
                          widget.filterRole == 'HOD'
                              ? Icons.account_balance_rounded
                              : Icons.school_rounded,
                          color: const Color(0xFF1E4D8F),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (leave['faculty_name'] ?? '').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${leave['department'] ?? ''}  ${leave['role'] ?? ''}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.filterRole == 'FACULTY ESCALATED')
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Escalated to Dean',
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
                                'EMERGENCY',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  infoRow(
                    Icons.calendar_month_rounded,
                    '${leave['start_date']} → ${leave['end_date']}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Leave Type: ${leave['leave_type']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  if (leave['total_days'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Duration: ${leave['total_days']} Day(s)',
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
                      'Reason: ${leave['reason']}',
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (status == 'PENDING')
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => approveLeave(leave['id']),
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
                            label: const Text(
                              'Approve',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => rejectLeave(leave['id']),
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
                            label: const Text(
                              'Reject',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (status == 'REJECTED' && leave['rejected_reason'] != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Reason: ${leave['rejected_reason']}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (status == 'APPROVED')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'This leave request is already approved.',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = leaves
        .where((l) =>
    (l['status'] ?? '').toString().toUpperCase() == selectedTab)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FB),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E5FA5),
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          const SizedBox(height: 10),
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
                        color: const Color(0xFF2E5FA5).withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.assignment_turned_in_rounded,
                            color: Color(0xFF2E5FA5),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Leave Overview',
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
                              title: 'Pending',
                              value: leaves
                                  .where((l) => l['status'] == 'PENDING')
                                  .length
                                  .toString(),
                              color: Colors.orange,
                              icon: Icons.pending_actions_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: compactStatCard(
                              title: 'Approved',
                              value: leaves
                                  .where((l) => l['status'] == 'APPROVED')
                                  .length
                                  .toString(),
                              color: Colors.green,
                              icon: Icons.check_circle_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: compactStatCard(
                              title: 'Rejected',
                              value: leaves
                                  .where((l) => l['status'] == 'REJECTED')
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
          Padding(
            padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  filterButton('PENDING'),
                  const SizedBox(width: 8),
                  filterButton('APPROVED'),
                  const SizedBox(width: 8),
                  filterButton('REJECTED'),
                ],
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
              child: Text(
                'No ${widget.title}',
                style: const TextStyle(fontSize: 16),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return leaveCard(filtered[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final Color glowColor;
  final String badgeLabel;
  final Color badgeColor;
  final Color badgeTextColor;
  final VoidCallback onTap;

  const _LeaveActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.badgeLabel,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.16),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeTextColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap to open →',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 12,
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

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
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
          child: child,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _Header({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }
}

class _DonutStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _DonutStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 58,
          width: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 5),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _MiniCountTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final Color color;
  final IconData icon;

  const _MiniCountTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
