import 'package:shared_preferences/shared_preferences.dart';

class TokenService {

  static const String _tokenKey = "token";

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> saveUserSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("token", data["access_token"]);
    await prefs.setString("email", data["email"]);
    await prefs.setString("name", data["name"]);
    await prefs.setString("facultyId", data["faculty_id"]);
    await prefs.setString("department", data["department"]);
    await prefs.setString("role", data["role"]);
    if (data["designation"] != null) {
      await prefs.setString("designation", data["designation"]);
    }

    if (data["qualification"] != null) {
      await prefs.setString("qualification", data["qualification"]);
    }

    if (data["profile_image"] != null) {
      await prefs.setString("profileImage", data["profile_image"]);
    }
  }

  static Future<Map<String, String?>> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      "token": prefs.getString("token"),
      "email": prefs.getString("email"),
      "name": prefs.getString("name"),
      "facultyId": prefs.getString("facultyId"),
      "department": prefs.getString("department"),
      "designation": prefs.getString("designation"),
      "qualification": prefs.getString("qualification"),
      "profileImage": prefs.getString("profileImage"),
      "role": prefs.getString("role"),
    };
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}