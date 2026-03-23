import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/holiday_provider.dart';

class EditHolidayScreen extends StatefulWidget {
  final Map<String, dynamic> holiday;

  const EditHolidayScreen({super.key, required this.holiday});

  @override
  State<EditHolidayScreen> createState() => _EditHolidayScreenState();
}

class _EditHolidayScreenState extends State<EditHolidayScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController titleController;
  late TextEditingController descriptionController;

  DateTime? startDate;
  DateTime? endDate;
  bool isActive = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.holiday["title"] ?? "");
    descriptionController = TextEditingController(
      text: widget.holiday["description"] ?? "",
    );
    startDate = DateTime.parse(widget.holiday["start_date"]);
    endDate = DateTime.parse(widget.holiday["end_date"]);
    isActive = widget.holiday["is_active"] ?? true;
  }

  Future<void> pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        startDate = picked;
        if (endDate != null && endDate!.isBefore(startDate!)) {
          endDate = startDate;
        }
      });
    }
  }

  Future<void> pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? startDate ?? DateTime.now(),
      firstDate: startDate ?? DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        endDate = picked;
      });
    }
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select start and end date")),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      await context.read<HolidayProvider>().updateHoliday(
        id: widget.holiday["id"],
        title: titleController.text.trim(),
        startDate: startDate!,
        endDate: endDate!,
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        isActive: isActive,
        holidayType: widget.holiday["holiday_type"] ?? "CUSTOM",
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Holiday updated successfully")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Holiday"),
        backgroundColor: const Color(0xFF1E4D8F),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: "Holiday Title",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Holiday title is required";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: pickStartDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        startDate == null
                            ? "Select Start Date"
                            : "Start Date: ${startDate!.day}-${startDate!.month}-${startDate!.year}",
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: pickEndDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        endDate == null
                            ? "Select End Date"
                            : "End Date: ${endDate!.day}-${endDate!.month}-${endDate!.year}",
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Reason / Description (optional)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (value) {
                      setState(() {
                        isActive = value;
                      });
                    },
                    title: const Text("Active Holiday"),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E4D8F),
                      ),
                      onPressed: isSubmitting ? null : submit,
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Update Holiday"),
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
}