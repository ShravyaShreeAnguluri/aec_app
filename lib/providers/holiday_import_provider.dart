import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HolidayImportProvider extends ChangeNotifier {
  bool isLoading = false;
  bool isImporting = false;
  String? errorMessage;
  String? successMessage;
  List<dynamic> extractedHolidays = [];
  String? uploadedFilePath;

  Future<void> previewHolidayPdf(String filePath) async {
    try {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
      extractedHolidays = [];
      uploadedFilePath = null;
      notifyListeners();

      final data = await ApiService.previewHolidayPdfImport(filePath: filePath);

      extractedHolidays = data["holidays"] ?? [];
      uploadedFilePath = data["file_path"];
    } catch (e) {
      errorMessage = e.toString().replaceAll("Exception: ", "");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> confirmImport() async {
    try {
      isImporting = true;
      errorMessage = null;
      successMessage = null;
      notifyListeners();

      final data = await ApiService.confirmHolidayPdfImport(
        holidays: extractedHolidays,
      );

      successMessage = data["message"] ?? "Holiday import completed successfully.";
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll("Exception: ", "");
      return false;
    } finally {
      isImporting = false;
      notifyListeners();
    }
  }

  void removeExtractedHoliday(int index) {
    if (index >= 0 && index < extractedHolidays.length) {
      extractedHolidays.removeAt(index);
      notifyListeners();
    }
  }

  void clear() {
    isLoading = false;
    isImporting = false;
    errorMessage = null;
    successMessage = null;
    extractedHolidays = [];
    uploadedFilePath = null;
    notifyListeners();
  }
}