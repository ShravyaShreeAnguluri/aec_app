import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/holiday_provider.dart';
import 'add_holiday_screen.dart';
import 'edit_holiday_screen.dart';
import 'holiday_calendar_screen.dart';
import 'import_holidays_pdf_screen.dart';

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
  static const textPrimary = Color(0xFF0F172A);
  static const textSub = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
}

class HolidayListScreen extends StatefulWidget {
  final bool isAdmin;
  const HolidayListScreen({super.key, this.isAdmin = false});

  @override
  State<HolidayListScreen> createState() => _HolidayListScreenState();
}

class _HolidayListScreenState extends State<HolidayListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<HolidayProvider>().fetchHolidays();
    });
  }

  Future<void> _openAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddHolidayScreen()),
    );
    if (mounted) {
      context.read<HolidayProvider>().fetchHolidays();
    }
  }

  Future<void> _openCalendar() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HolidayCalendarScreen()),
    );
    if (mounted) {
      context.read<HolidayProvider>().fetchHolidays();
    }
  }

  Future<void> _openImport() async {
    final imported = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportHolidaysPdfScreen()),
    );
    if (imported == true && mounted) {
      context.read<HolidayProvider>().fetchHolidays();
    }
  }

  Future<void> _openEdit(Map<String, dynamic> holiday) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditHolidayScreen(holiday: holiday)),
    );
    if (mounted) {
      context.read<HolidayProvider>().fetchHolidays();
    }
  }

  Future<void> _deleteHoliday(Map<String, dynamic> holiday) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Holiday'),
        content: Text(
          "Are you sure you want to delete '${holiday['title']}'?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await context.read<HolidayProvider>().deleteHoliday(holiday['id']);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Holiday deleted successfully')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HolidayProvider>();

    return Scaffold(
      backgroundColor: _C.bg,
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
        backgroundColor: _C.navy,
        foregroundColor: Colors.white,
        onPressed: _openAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Holiday'),
      )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_C.navy, _C.navyMid, _C.navyLight],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.navy.withOpacity(0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.16)),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Holidays',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.isAdmin
                                    ? 'Manage, edit and organize holidays with admin actions'
                                    : 'View holiday entries and calendar information',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withOpacity(0.18)),
                          ),
                          child: Text(
                            widget.isAdmin ? 'Admin Mode' : 'View Mode',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _topActionButton(
                            icon: Icons.calendar_month_rounded,
                            label: 'Calendar',
                            onTap: _openCalendar,
                          ),
                        ),
                        if (widget.isAdmin) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _topActionButton(
                              icon: Icons.upload_file_rounded,
                              label: 'Import PDF',
                              onTap: _openImport,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: _C.navy,
                onRefresh: () => context.read<HolidayProvider>().fetchHolidays(),
                child: Builder(
                  builder: (_) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (provider.errorMessage != null) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: _C.dangerBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _C.danger.withOpacity(0.18)),
                            ),
                            child: Text(
                              provider.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _C.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (provider.holidays.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _C.successBg,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: _C.success.withOpacity(0.18)),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.beach_access_rounded, color: _C.success, size: 34),
                                SizedBox(height: 12),
                                Text(
                                  'No holidays available',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.success),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Once holidays are added, they will appear here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: _C.textSub),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
                      itemCount: provider.holidays.length,
                      itemBuilder: (context, index) {
                        final holiday = provider.holidays[index];
                        final startDate = holiday['start_date'] ?? '';
                        final endDate = holiday['end_date'] ?? '';
                        final description = (holiday['description'] ?? '').toString();
                        final isActive = holiday['is_active'] ?? true;
                        final holidayType = (holiday['holiday_type'] ?? 'CUSTOM').toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _C.card,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: _C.border),
                            boxShadow: [
                              BoxShadow(
                                color: _C.navy.withOpacity(0.05),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _C.navy.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.event_available_rounded, color: _C.navy),
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
                                            holiday['title'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: _C.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (widget.isAdmin)
                                          PopupMenuButton<String>(
                                            onSelected: (value) async {
                                              if (value == 'edit') {
                                                await _openEdit(holiday);
                                              } else if (value == 'delete') {
                                                await _deleteHoliday(holiday);
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _pill(
                                          icon: Icons.calendar_today_rounded,
                                          text: startDate == endDate ? startDate : '$startDate to $endDate',
                                          bg: _C.navy.withOpacity(0.08),
                                          fg: _C.navy,
                                        ),
                                        _pill(
                                          icon: isActive ? Icons.check_circle_rounded : Icons.block_rounded,
                                          text: isActive ? 'Active' : 'Inactive',
                                          bg: isActive ? _C.successBg : Colors.grey.shade200,
                                          fg: isActive ? _C.success : _C.textSub,
                                        ),
                                        _pill(
                                          icon: Icons.category_rounded,
                                          text: holidayType,
                                          bg: _C.teal.withOpacity(0.08),
                                          fg: _C.teal,
                                        ),
                                      ],
                                    ),
                                    if (description.trim().isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        description,
                                        style: const TextStyle(fontSize: 12.5, color: _C.textSub, height: 1.5),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String text,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}
