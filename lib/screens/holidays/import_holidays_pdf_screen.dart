import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/holiday_import_provider.dart';
import '../../providers/holiday_provider.dart';

class ImportHolidaysPdfScreen extends StatefulWidget {
  const ImportHolidaysPdfScreen({super.key});

  @override
  State<ImportHolidaysPdfScreen> createState() => _ImportHolidaysPdfScreenState();
}

class _ImportHolidaysPdfScreenState extends State<ImportHolidaysPdfScreen> {
  String? selectedFilePath;
  String? selectedFileName;

  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["pdf"],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        selectedFilePath = result.files.single.path;
        selectedFileName = result.files.single.name;
      });
    }
  }

  Future<void> previewPdf() async {
    if (selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a PDF file")),
      );
      return;
    }

    await context.read<HolidayImportProvider>().previewHolidayPdf(selectedFilePath!);
  }

  Future<void> confirmImport() async {
    final importProvider = context.read<HolidayImportProvider>();

    if (importProvider.extractedHolidays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No holidays available to import")),
      );
      return;
    }

    final success = await importProvider.confirmImport();

    if (!mounted) return;

    if (success) {
      await context.read<HolidayProvider>().fetchHolidays();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Import Successful"),
          content: Text(
            importProvider.successMessage ?? "Holidays imported successfully.",
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E4D8F),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Import Failed"),
          content: Text(importProvider.errorMessage ?? "Failed to import holidays."),
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
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HolidayImportProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Import Holidays from PDF"),
        backgroundColor: const Color(0xFF1E4D8F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    InkWell(
                      onTap: pickPdf,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          selectedFileName ?? "Select Holiday PDF",
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E4D8F),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: provider.isLoading ? null : previewPdf,
                        child: provider.isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Extract Holiday Preview"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (provider.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  provider.errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: provider.extractedHolidays.isEmpty
                  ? const Center(child: Text("No holidays extracted yet"))
                  : ListView.builder(
                itemCount: provider.extractedHolidays.length,
                itemBuilder: (context, index) {
                  final holiday = provider.extractedHolidays[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.event, color: Colors.green),
                      title: Text(holiday["title"] ?? ""),
                      subtitle: Text(
                        holiday["start_date"] == holiday["end_date"]
                            ? holiday["start_date"] ?? ""
                            : "${holiday["start_date"]} to ${holiday["end_date"]}",
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          context.read<HolidayImportProvider>().removeExtractedHoliday(index);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            if (provider.extractedHolidays.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E4D8F),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: provider.isImporting ? null : confirmImport,
                  child: provider.isImporting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Import Holidays"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}