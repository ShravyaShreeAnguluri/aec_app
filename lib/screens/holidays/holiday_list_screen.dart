import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/holiday_provider.dart';
import 'add_holiday_screen.dart';
import 'edit_holiday_screen.dart';
import 'holiday_calendar_screen.dart';
import 'import_holidays_pdf_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HolidayProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Holidays"),
        backgroundColor: const Color(0xFF1E4D8F),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: "Import Holidays from PDF",
              onPressed: () async {
                final imported = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ImportHolidaysPdfScreen(),
                  ),
                );
                if (imported == true && mounted) {
                  context.read<HolidayProvider>().fetchHolidays();
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HolidayCalendarScreen(),
                ),
              );
                if (mounted) {
                  context.read<HolidayProvider>().fetchHolidays();
                }
            },
          ),
        ],
      ),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton(
        backgroundColor: const Color(0xFF1E4D8F),
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddHolidayScreen(),
            ),
          );
          if (mounted) {
            context.read<HolidayProvider>().fetchHolidays();
          }
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      )
          : null,
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      )
          : provider.holidays.isEmpty
          ? const Center(child: Text("No holidays available"))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.holidays.length,
        itemBuilder: (context, index) {
          final holiday = provider.holidays[index];
          final startDate = holiday["start_date"] ?? "";
          final endDate = holiday["end_date"] ?? "";

          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              title: Text(
                holiday["title"] ?? "",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    startDate == endDate
                        ? "Date: $startDate"
                        : "Date: $startDate to $endDate",
                  ),
                  if ((holiday["description"] ?? "").toString().trim().isNotEmpty)
                    Text("Reason: ${holiday["description"]}"),
                ],
              ),
              trailing: widget.isAdmin
                  ? PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == "edit") {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditHolidayScreen(holiday: holiday),
                      ),
                    );
                    if (mounted) {
                      context.read<HolidayProvider>().fetchHolidays();
                    }
                  } else if (value == "delete") {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Delete Holiday"),
                        content: Text(
                          "Are you sure you want to delete '${holiday["title"]}'?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Delete"),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        await provider.deleteHoliday(holiday["id"]);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Holiday deleted successfully"),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceAll("Exception: ", ""),
                            ),
                          ),
                        );
                      }
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: "edit",
                    child: Text("Edit"),
                  ),
                  PopupMenuItem(
                    value: "delete",
                    child: Text("Delete"),
                  ),
                ],
              )
                  : null,
            ),
          );
        },
      ),
    );
  }
}