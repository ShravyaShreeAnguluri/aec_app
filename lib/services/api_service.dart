import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:faculty_app/services/token_service.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'package:flutter/material.dart';

class ApiService {
  static const String baseUrl =  "https://nongrievously-unpickable-araceli.ngrok-free.dev"; // your FastAPI URL

  static List<String>? cachedDepartments;

  static bool _isHandlingUnauthorized = false;

  static Future<void> handleUnauthorized() async {

    if (_isHandlingUnauthorized) {
      throw Exception("SESSION_EXPIRED");
    }

    _isHandlingUnauthorized = true;
    await TokenService.clearToken();
    final context = navigatorKey.currentContext;

    if (context != null) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Session expired. Please login again"),
        ),
      );

      Navigator.of(context).pushNamedAndRemoveUntil(
        "/login",
            (route) => false,
      );
    }
    _isHandlingUnauthorized = false;
    throw Exception("SESSION_EXPIRED");
  }

  // ---------------- GET TOKEN ----------------
  static Future<String?> getToken() async {
    return await TokenService.getToken();
  }

  static Future<List<String>> getDepartments() async {

    // return cached data if available
    if (cachedDepartments != null) {
      return cachedDepartments!;
    }

    final response = await http.get(
      Uri.parse("$baseUrl/departments"),
    );

    if (response.statusCode == 200) {

      final List data = jsonDecode(response.body);

      cachedDepartments =
          data.map((e) => e["name"].toString()).toList();

      return cachedDepartments!;

    } else {
      throw Exception("Failed to load departments");
    }
  }

  // ---------------- REGISTER ----------------
  static Future<Map<String, dynamic>> registerFaculty({
    required String facultyId,
    required String name,
    required String department,
    required String email,
    required String password,
    String? designation,
    String? qualification,
    required dynamic faceImage, // File (mobile) or Uint8List (web)
    dynamic profileImage,
  }) async {
    var uri = Uri.parse("$baseUrl/register");
    var request = http.MultipartRequest("POST", uri);

    request.fields['faculty_id'] = facultyId;
    request.fields['name'] = name;
    request.fields['department'] = department;
    request.fields['email'] = email;
    request.fields['password'] = password;
    if (designation != null && designation.isNotEmpty) {
      request.fields['designation'] = designation;
    }

    if (qualification != null && qualification.isNotEmpty) {
      request.fields['qualification'] = qualification;
    }


    if (kIsWeb) {
      final mimeType = lookupMimeType("face.jpg")?.split('/');
      request.files.add(
        http.MultipartFile.fromBytes(
          'face_image',
          faceImage,
          filename: "face.jpg",
          contentType: mimeType != null
              ? MediaType(mimeType[0], mimeType[1])
              : MediaType('image', 'jpeg'),
        ),
      );
    } else {
      final mimeType = lookupMimeType(faceImage.path)?.split('/');
      request.files.add(
        await http.MultipartFile.fromPath(
          'face_image',
          faceImage.path,
          contentType: mimeType != null
              ? MediaType(mimeType[0], mimeType[1])
              : MediaType('image', 'jpeg'),
        ),
      );
    }

    // -------- PROFILE IMAGE (OPTIONAL) --------
    if (profileImage != null) {
      if (kIsWeb) {
        final mimeType = lookupMimeType("profile.jpg")?.split('/');
        request.files.add(
          http.MultipartFile.fromBytes(
            'profile_image',
            profileImage,
            filename: "profile.jpg",
            contentType: mimeType != null
                ? MediaType(mimeType[0], mimeType[1])
                : MediaType('image', 'jpeg'),
          ),
        );
      } else {
        final mimeType = lookupMimeType(profileImage.path)?.split('/');
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_image',
            profileImage.path,
            contentType: mimeType != null
                ? MediaType(mimeType[0], mimeType[1])
                : MediaType('image', 'jpeg'),
          ),
        );
      }
    }

    var response = await request.send();
    var respStr = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(respStr);
    } else {
      // Try to parse backend message
      try {
        final Map<String, dynamic> data = jsonDecode(respStr);
        if (data.containsKey('detail')) {
          throw Exception(data['detail']);
        }
      } catch (_) {}
      throw Exception("Registration failed: $respStr");
    }
  }

  // ----------------- LOGIN -----------------
  static Future<Map<String, dynamic>> loginWithPassword(String email, String password) async {
    final url = Uri.parse("$baseUrl/login");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );


    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }  else {
      try {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('detail')) {
          throw Exception(data['detail']);
        }
      } catch (_) {}
      throw Exception("Login failed: ${response.body}");
    }
  }

  // ----------------- REQUEST OTP -----------------
  static Future<bool> requestOtp(String email) async {
    final url = Uri.parse("$baseUrl/login-request");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      try {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('detail')) throw Exception(data['detail']);
      } catch (_) {}
      throw Exception("OTP request failed: ${response.body}");
    }
  }

  // ----------------- VERIFY OTP -----------------
  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    final url = Uri.parse("$baseUrl/verify-otp");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "otp": otp}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // ✅ Save JWT token
      await TokenService.saveUserSession(data);

      return data;
    } else {
      try {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('detail')) throw Exception(data['detail']);
      } catch (_) {}
      throw Exception("OTP verification failed: ${response.body}");
    }
  }

  static Future<Map<String, dynamic>> verifyFaceForAttendance({
    required String email,
    required dynamic faceImage,
  }) async {
    final uri = Uri.parse("$baseUrl/verify-face");
    final request = http.MultipartRequest("POST", uri);

    request.fields['email'] = email;

    final mimeType = lookupMimeType(faceImage.path)?.split('/');
    request.files.add(
      await http.MultipartFile.fromPath(
        'face_image',
        faceImage.path,
        contentType: mimeType != null
            ? MediaType(mimeType[0], mimeType[1])
            : MediaType('image', 'jpeg'),
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      final data = jsonDecode(responseBody);
      throw Exception(data['detail'] ?? "Face verification failed");
    }
  }

  // SEND RESET LINK
  static Future<void> forgotPasswordLink(String email) async {
    final url = Uri.parse("$baseUrl/forgot-password-link");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['detail']);
    }
  }

// RESET PASSWORD
  static Future<void> resetPasswordWithToken(
      String token, String newPassword) async {
    final url = Uri.parse("$baseUrl/reset-password-link");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "token": token,
        "new_password": newPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['detail']);
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {

    final token = await TokenService.getToken();

    final response = await http.get(
      Uri.parse("$baseUrl/profile"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load profile");
    }
  }

  // =====================================================
  // UPDATE PROFILE — FIX: Authorization header added
  // =====================================================
  static Future<void> updateProfile({
    required String name,
    String? designation,
    String? qualification,
    dynamic profileImage,
  }) async {
    // 1. Get token first — if missing, trigger unauthorized flow
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      await handleUnauthorized();
      return;
    }

    var uri = Uri.parse("$baseUrl/update-profile");
    var request = http.MultipartRequest("PUT", uri);

    // 2. CRITICAL: attach the Bearer token to the multipart request
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['name'] = name;

    if (designation != null && designation.isNotEmpty) {
      request.fields['designation'] = designation;
    }

    if (qualification != null && qualification.isNotEmpty) {
      request.fields['qualification'] = qualification;
    }

    if (profileImage != null) {
      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'profile_image',
            profileImage,
            filename: "profile.jpg",
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_image',
            profileImage.path,
          ),
        );
      }
    }

    var response = await request.send();
    final respStr = await response.stream.bytesToString();

    if (response.statusCode == 200) return;

    if (response.statusCode == 401) {
      await handleUnauthorized();
      return;
    }

    try {
      final body = jsonDecode(respStr);
      throw Exception(body['detail'] ?? "Profile update failed");
    } catch (_) {}

    throw Exception("Profile update failed");
  }

  static Future<List<dynamic>> getFacultyList() async {

    final token = await TokenService.getToken();

    final response = await http.get(
      Uri.parse("$baseUrl/faculty-list"),
      headers: {
        "Authorization": "Bearer $token"
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to fetch faculty");
    }
  }

  // ADMIN → UPGRADE TO HOD
  static Future<void> upgradeToHod(String facultyId) async {

    final token = await TokenService.getToken();

    final response = await http.post(
      Uri.parse("$baseUrl/upgrade-hod"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: {
        "faculty_id": facultyId
      },
    );

    if (response.statusCode == 200) {
      return;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data["detail"] ?? "Upgrade failed");
    }
  }

  static Future<void> upgradeToDean(String facultyId) async {

    final token = await TokenService.getToken();

    final response = await http.post(
      Uri.parse("$baseUrl/upgrade-dean"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: {
        "faculty_id": facultyId
      },
    );

    if (response.statusCode != 200) {

      final data = jsonDecode(response.body);

      throw Exception(data["detail"] ?? "Upgrade to Dean failed");

    }

  }

  static Future<dynamic> get(String endpoint) async {

    final token = await TokenService.getToken();

    if (token == null || token.isEmpty) {
      await handleUnauthorized();
    }

    final response = await http.get(
      Uri.parse("$baseUrl$endpoint"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await handleUnauthorized();
    }

    try {
      final body = jsonDecode(response.body);
      if (body["detail"] != null) {
        throw Exception(body["detail"].toString());
      }
    } catch (_) {}

    throw Exception("Request Failed");
  }

  static Future<dynamic> post(
      String endpoint, {
        Map<String, dynamic>? body,
      }) async {

    final token = await TokenService.getToken();

    if (token == null || token.isEmpty) {
      await handleUnauthorized();
    }

    final response = await http.post(
      Uri.parse("$baseUrl$endpoint"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(body ?? {}),
    );

    final data = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await handleUnauthorized();
    }

    try {
      final resBody = jsonDecode(response.body);
      if (resBody["detail"] != null) {
        throw Exception(resBody["detail"].toString());
      }
    } catch (_) {}

    throw Exception(
      data != null && data["detail"] != null
          ? data["detail"]
          : "Request failed",
    );

  }

  static Future applyLeave({
    required DateTime startDate,
    required DateTime endDate,
    required String leaveType,
    required String reason,
    String? permissionDuration,
  }) async {

    return await post(
      "/leave/apply",
      body: {
        "start_date": startDate.toIso8601String(),
        "end_date": endDate.toIso8601String(),
        "leave_type": leaveType,
        "reason": reason,
        "permission_duration": permissionDuration
      },
    );
  }

  static Future approveLeave(int id) async {
    return await post("/leave/approve/$id");
  }

  static Future rejectLeave(int id, String reason) async {
    return await post(
      "/leave/reject/$id",
      body: {"reason": reason},
    );
  }

  static Future<List> getMyLeaves() async {
    return await get("/leave/my-leaves");
  }

  static Future<List> getDepartmentLeaves() async {
    return await get("/leave/department-leaves");
  }

  static Future<List> getHodLeaves() async {
    return await get("/leave/hod-leaves");
  }

  static Future<List> getTodayDepartmentLeaves() async {
    return await get("/leave/today-department-leaves");
  }

  static Future<List> getTodayHodLeaves() async {
    return await get("/leave/today-hod-leaves");
  }

  static Future<List> getCalendarLeaves() async {
    return await get("/leave/calendar-leaves");
  }

  static Future<Map<String, dynamic>> getLeaveBalance() async {
    return await get("/leave/leave-balance");
  }

  static Future<List> getNotifications() async {
    return await get("/notifications");
  }

  static Future cancelLeave(int id) async {
    return await post("/leave/cancel/$id");
  }

  static Future<Map<String, dynamic>> getLeaveStats() async {
    return await get("/leave/leave-stats");
  }

  static Future<List> getHolidays() async {
    final data = await get("/holidays/");
    return data as List;
  }

  static Future<List> getHolidayCalendar(int year, int month) async {
    final data = await get("/holidays/calendar?year=$year&month=$month");
    return data as List;
  }

  static Future<Map<String, dynamic>> getTodayHoliday() async {
    final data = await get("/holidays/today");
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> checkHoliday(DateTime date) async {
    final isoDate =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final data = await get("/holidays/check?check_date=$isoDate");
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> addHoliday({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String holidayType = "CUSTOM",
  }) async {
    final data = await post(
      "/holidays/",
      body: {
        "title": title,
        "start_date":
        "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}",
        "end_date":
        "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}",
        "description": description,
        "holiday_type": holidayType,
        "is_active": true,
      },
    );
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> updateHoliday({
    required int id,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    required bool isActive,
    String holidayType = "CUSTOM",
  }) async {
    final token = await TokenService.getToken();

    if (token == null || token.isEmpty) {
      await handleUnauthorized();
    }

    final response = await http.put(
      Uri.parse("$baseUrl/holidays/$id"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "title": title,
        "start_date":
        "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}",
        "end_date":
        "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}",
        "description": description,
        "holiday_type": holidayType,
        "is_active": isActive,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    if (response.statusCode == 401) {
      await handleUnauthorized();
    }

    try {
      final body = jsonDecode(response.body);
      if (body["detail"] != null) {
        throw Exception(body["detail"].toString());
      }
    } catch (_) {}

    throw Exception("Request failed");
  }

  static Future<void> deleteHoliday(int id) async {
    final token = await TokenService.getToken();

    if (token == null || token.isEmpty) {
      await handleUnauthorized();
    }

    final response = await http.delete(
      Uri.parse("$baseUrl/holidays/$id"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      return;
    }
    if (response.statusCode == 401) {
      await handleUnauthorized();
    }

    try {
      final body = jsonDecode(response.body);
      if (body["detail"] != null) {
        throw Exception(body["detail"].toString());
      }
    } catch (_) {}

    throw Exception("Request failed");
  }

  static Future<Map<String, dynamic>> previewHolidayPdfImport({
    required String filePath,
  }) async {
    final token = await TokenService.getToken();

    if (token == null || token.isEmpty) {
      await handleUnauthorized();
    }

    final uri = Uri.parse("$baseUrl/holidays/import-pdf-preview");
    final request = http.MultipartRequest("POST", uri);
    request.headers["Authorization"] = "Bearer $token";

    request.files.add(
      await http.MultipartFile.fromPath("pdf_file", filePath),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    }
    if (response.statusCode == 401) {
      await handleUnauthorized();
    }

    try {
      final body = jsonDecode(responseBody);
      if (body["detail"] != null) {
        throw Exception(body["detail"].toString());
      }
    } catch (_) {}

    throw Exception("Failed to preview holidays from PDF");
  }

  static Future<Map<String, dynamic>> confirmHolidayPdfImport({
    required List<dynamic> holidays,
  }) async {
    final data = await post(
      "/holidays/import-pdf-confirm",
      body: {
        "holidays": holidays,
      },
    );
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> getTodayAttendanceStatus() async {
    final token = await TokenService.getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/attendance/today-status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch today attendance status');
    }
  }

  static Future<List<dynamic>> getAttendanceHistory({
    String? startDate,
    String? endDate,
  }) async {
    final token = await TokenService.getToken();

    String url = "$baseUrl/attendance/history";
    List<String> params = [];

    if (startDate != null && startDate.isNotEmpty) {
      params.add("start_date=$startDate");
    }
    if (endDate != null && endDate.isNotEmpty) {
      params.add("end_date=$endDate");
    }

    if (params.isNotEmpty) {
      url += "?${params.join("&")}";
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      await handleUnauthorized();
    }

    throw Exception("Failed to load attendance history");
  }

  static Future<Map<String, dynamic>> getAttendanceSummary({
    String? startDate,
    String? endDate,
  }) async {
    final token = await TokenService.getToken();

    String url = "$baseUrl/attendance/report/summary";
    List<String> params = [];

    if (startDate != null && startDate.isNotEmpty) {
      params.add("start_date=$startDate");
    }
    if (endDate != null && endDate.isNotEmpty) {
      params.add("end_date=$endDate");
    }

    if (params.isNotEmpty) {
      url += "?${params.join("&")}";
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      await handleUnauthorized();
    }

    throw Exception("Failed to load attendance summary");
  }
}