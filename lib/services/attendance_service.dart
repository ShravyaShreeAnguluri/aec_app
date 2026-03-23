import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'api_service.dart';

class AttendanceService {
  static const String baseUrl =
      "https://nongrievously-unpickable-araceli.ngrok-free.dev";

  static Future<Map<String, dynamic>> markAttendance({
    required String email,
    required double latitude,
    required double longitude,
    required File faceImage,
    required String type,
  }) async {
    final uri = Uri.parse("$baseUrl/attendance/$type");
    final token = await ApiService.getToken();

    final request = http.MultipartRequest("POST", uri);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['email'] = email;
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();

    final mimeType = lookupMimeType(faceImage.path)?.split('/') ?? ['image', 'jpeg'];

    request.files.add(
      await http.MultipartFile.fromPath(
        'face_image',
        faceImage.path,
        contentType: MediaType(mimeType[0], mimeType[1]),
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(responseBody);
    } catch (_) {
      data = null;
    }

    if (response.statusCode == 200) {
      return data ?? {"message": "Attendance marked successfully"};
    }

    if (data != null && data["detail"] != null) {
      throw Exception(data["detail"].toString());
    }

    throw Exception("Attendance request failed");
  }
}