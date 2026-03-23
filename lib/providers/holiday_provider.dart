import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HolidayProvider extends ChangeNotifier {
  List<dynamic> holidays = [];
  Map<String, dynamic>? todayHolidayStatus;
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchHolidays() async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      holidays = await ApiService.getHolidays();
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchHolidayCalendar(int year, int month) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      holidays = await ApiService.getHolidayCalendar(year, month);
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTodayHolidayStatus() async {
    try {
      todayHolidayStatus = await ApiService.getTodayHoliday();
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<bool> isTodayHoliday() async {
    await fetchTodayHolidayStatus();
    return todayHolidayStatus?['is_holiday'] == true;
  }

  Future<void> addHoliday({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String holidayType = "CUSTOM",
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      await ApiService.addHoliday(
        title: title,
        startDate: startDate,
        endDate: endDate,
        description: description,
        holidayType: holidayType,
      );

      await fetchHolidays();
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateHoliday({
    required int id,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    required bool isActive,
    String holidayType = "CUSTOM",
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      await ApiService.updateHoliday(
        id: id,
        title: title,
        startDate: startDate,
        endDate: endDate,
        description: description,
        holidayType: holidayType,
        isActive: isActive,
      );

      await fetchHolidays();
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteHoliday(int id) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      await ApiService.deleteHoliday(id);
      await fetchHolidays();
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}