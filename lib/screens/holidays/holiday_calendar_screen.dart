import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../providers/holiday_provider.dart';

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

class HolidayCalendarScreen extends StatefulWidget {
  const HolidayCalendarScreen({super.key});

  @override
  State<HolidayCalendarScreen> createState() => _HolidayCalendarScreenState();
}

class _HolidayCalendarScreenState extends State<HolidayCalendarScreen> {
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HolidayProvider>().fetchHolidayCalendar(
        focusedDay.year,
        focusedDay.month,
      );
    });
  }

  bool isHoliday(DateTime day, List holidays) {
    for (final holiday in holidays) {
      final startDate = DateTime.parse(holiday['start_date']);
      final endDate = DateTime.parse(holiday['end_date']);

      final normalizedDay = DateTime(day.year, day.month, day.day);
      final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

      if (!normalizedDay.isBefore(normalizedStart) &&
          !normalizedDay.isAfter(normalizedEnd)) {
        return true;
      }
    }

    if (day.weekday == DateTime.sunday) {
      return true;
    }

    return false;
  }

  Map<String, dynamic>? getHolidayDetails(DateTime day, List holidays) {
    for (final holiday in holidays) {
      final startDate = DateTime.parse(holiday['start_date']);
      final endDate = DateTime.parse(holiday['end_date']);

      final normalizedDay = DateTime(day.year, day.month, day.day);
      final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

      if (!normalizedDay.isBefore(normalizedStart) &&
          !normalizedDay.isAfter(normalizedEnd)) {
        return holiday;
      }
    }
    return null;
  }

  void showHolidayDialog(DateTime day, List holidays) {
    final holiday = getHolidayDetails(day, holidays);
    final bool isSundayOnly = holiday == null && day.weekday == DateTime.sunday;

    String dateText = '${day.day}-${day.month}-${day.year}';
    String reasonText = 'Sunday';
    String titleText = 'Holiday';

    if (!isSundayOnly && holiday != null) {
      titleText = holiday['title'] ?? 'Holiday';

      final startDate = holiday['start_date'] ?? '';
      final endDate = holiday['end_date'] ?? '';

      dateText = startDate == endDate ? startDate : '$startDate to $endDate';

      if ((holiday['description'] ?? '').toString().trim().isNotEmpty) {
        reasonText = holiday['description'];
      } else {
        reasonText = titleText;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Holiday Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogInfoRow(Icons.celebration_rounded, 'Title', titleText),
            const SizedBox(height: 12),
            _dialogInfoRow(Icons.calendar_today_rounded, 'Date', dateText),
            const SizedBox(height: 12),
            _dialogInfoRow(Icons.notes_rounded, 'Reason', reasonText),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _dialogInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _C.navy.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _C.navy, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.textSub)),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HolidayProvider>();

    return Scaffold(
      backgroundColor: _C.bg,
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
                child: Row(
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Holiday Calendar',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'View holiday dates month-wise with a matching HOD theme',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Monthly View', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _C.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _C.border),
                        boxShadow: [
                          BoxShadow(
                            color: _C.navy.withOpacity(0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: TableCalendar(
                        firstDay: DateTime(2024, 1, 1),
                        lastDay: DateTime(2035, 12, 31),
                        focusedDay: focusedDay,
                        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                        onDaySelected: (selected, focused) {
                          setState(() {
                            selectedDay = selected;
                            focusedDay = focused;
                          });

                          if (isHoliday(selected, provider.holidays)) {
                            showHolidayDialog(selected, provider.holidays);
                          }
                        },
                        onPageChanged: (focused) {
                          focusedDay = focused;
                          context.read<HolidayProvider>().fetchHolidayCalendar(
                            focused.year,
                            focused.month,
                          );
                        },
                        headerStyle: const HeaderStyle(
                          titleCentered: true,
                          formatButtonVisible: false,
                          titleTextStyle: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _C.textPrimary,
                          ),
                          leftChevronIcon: Icon(Icons.chevron_left_rounded, color: _C.navy),
                          rightChevronIcon: Icon(Icons.chevron_right_rounded, color: _C.navy),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.textSub),
                          weekendStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.danger),
                        ),
                        calendarStyle: CalendarStyle(
                          outsideTextStyle: const TextStyle(color: _C.textMuted),
                          todayDecoration: BoxDecoration(
                            color: _C.teal.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: _C.teal),
                          ),
                          todayTextStyle: const TextStyle(color: _C.teal, fontWeight: FontWeight.w800),
                          selectedDecoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [_C.navy, _C.navyLight]),
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          defaultTextStyle: const TextStyle(color: _C.textPrimary, fontWeight: FontWeight.w600),
                          weekendTextStyle: const TextStyle(color: _C.danger, fontWeight: FontWeight.w700),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, _) {
                            if (isHoliday(day, provider.holidays)) {
                              final holiday = getHolidayDetails(day, provider.holidays);
                              final isSundayOnly = holiday == null && day.weekday == DateTime.sunday;
                              final bg = isSundayOnly ? _C.gold.withOpacity(0.18) : _C.dangerBg;
                              final fg = isSundayOnly ? _C.gold : _C.danger;
                              return Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: fg),
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _C.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _C.border),
                        boxShadow: [
                          BoxShadow(
                            color: _C.navy.withOpacity(0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.list_alt_rounded, color: _C.navy, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'This Month Holidays',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.textPrimary),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _C.navy.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${provider.holidays.length}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.navy),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (provider.holidays.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: _C.successBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _C.success.withOpacity(0.18)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: _C.success),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'No holidays this month',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.success),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: provider.holidays.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final holiday = provider.holidays[index];
                                final startDate = holiday['start_date'] ?? '';
                                final endDate = holiday['end_date'] ?? '';
                                final description = (holiday['description'] ?? '').toString();
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: _C.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: _C.dangerBg,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(Icons.event_rounded, color: _C.danger),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              holiday['title'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: _C.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              startDate == endDate ? startDate : '$startDate to $endDate',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _C.textSub,
                                              ),
                                            ),
                                            if (description.trim().isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                description,
                                                style: const TextStyle(fontSize: 12, color: _C.textMuted, height: 1.45),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
