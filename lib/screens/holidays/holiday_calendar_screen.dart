import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/holiday_provider.dart';

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
      final startDate = DateTime.parse(holiday["start_date"]);
      final endDate = DateTime.parse(holiday["end_date"]);

      final normalizedDay = DateTime(day.year, day.month, day.day);
      final normalizedStart =
      DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEnd =
      DateTime(endDate.year, endDate.month, endDate.day);

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
      final startDate = DateTime.parse(holiday["start_date"]);
      final endDate = DateTime.parse(holiday["end_date"]);

      final normalizedDay = DateTime(day.year, day.month, day.day);
      final normalizedStart =
      DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEnd =
      DateTime(endDate.year, endDate.month, endDate.day);

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

    String dateText = "${day.day}-${day.month}-${day.year}";
    String reasonText = "Sunday";
    String titleText = "Holiday";

    if (!isSundayOnly && holiday != null) {
      titleText = holiday["title"] ?? "Holiday";

      final startDate = holiday["start_date"] ?? "";
      final endDate = holiday["end_date"] ?? "";

      dateText = startDate == endDate
          ? startDate
          : "$startDate to $endDate";

      if ((holiday["description"] ?? "").toString().trim().isNotEmpty) {
        reasonText = holiday["description"];
      } else {
        reasonText = titleText;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text("Holiday Details"),
        content: Text(
          "Title: $titleText\n"
              "Date: $dateText\n"
              "Reason: $reasonText",
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E4D8F),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HolidayProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Holiday Calendar"),
        backgroundColor: const Color(0xFF1E4D8F),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          TableCalendar(
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
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue.shade300,
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFF1E4D8F),
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                if (isHoliday(day, provider.holidays)) {
                  return Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: provider.holidays.isEmpty
                ? const Center(child: Text("No holidays this month"))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.holidays.length,
              itemBuilder: (context, index) {
                final holiday = provider.holidays[index];
                final startDate = holiday["start_date"] ?? "";
                final endDate = holiday["end_date"] ?? "";

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading:
                    const Icon(Icons.event, color: Colors.red),
                    title: Text(holiday["title"] ?? ""),
                    subtitle: Text(
                      startDate == endDate
                          ? startDate
                          : "$startDate to $endDate",
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
}