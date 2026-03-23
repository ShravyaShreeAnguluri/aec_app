// lib/services/api_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/document_model.dart';
import '../models/subject_model.dart';
import 'app_config.dart';

class ApiService {
  // ════════════════════════════════════════════════════════════
  //  ⚠️  DO NOT change the URL here anymore!
  //  Update ONLY:  lib/config/app_config.dart → ngrokDomain
  // ════════════════════════════════════════════════════════════

  static String get _base => AppConfig.apiUrl;

  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl:        AppConfig.apiUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout:    AppConfig.uploadTimeout,
      headers:        AppConfig.ngrokHeaders,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers.addAll(AppConfig.ngrokHeaders);
        handler.next(options);
      },
      onError: (DioException e, handler) => handler.next(e),
    ));
  }

  Future<bool> checkHealth() async {
    try {
      final r = await _dio.get('/health');
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<List<DocumentModel>> fetchDocuments({
    int? year, String? department,
    String? category, String? search,
    String? uploadedBy,   // ✅ faculty filter
  }) async {
    final p = <String, dynamic>{};
    if (year       != null) p['year']       = year;
    if (department != null) p['department'] = department;
    if (category   != null) p['category']   = category;
    if (uploadedBy != null && uploadedBy.isNotEmpty) p['uploadedBy'] = uploadedBy;
    if (search     != null && search.isNotEmpty)     p['search']     = search;
    final r = await _dio.get('/documents', queryParameters: p);
    return (r.data['data'] as List)
        .map((e) => DocumentModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> fetchStats() async {
    final r = await _dio.get('/documents/stats/summary');
    return r.data['data'] as Map<String, dynamic>;
  }

  Future<DocumentModel> uploadDocument({
    required File   file,
    required String title,
    required String description,
    required int    year,
    required String department,
    required String subjectId,
    required String subjectName,
    required String category,
    required String uploadedBy,   // ✅ saves real faculty name
    void Function(double)? onProgress,
  }) async {
    final fileName = file.path.split('/').last;
    final form = FormData.fromMap({
      'file':        await MultipartFile.fromFile(file.path, filename: fileName),
      'title':       title,
      'description': description,
      'year':        year.toString(),
      'department':  department,
      'subject':     subjectId,
      'subjectName': subjectName,
      'category':    category,
      'uploadedBy':  uploadedBy,  // ✅ passed to backend
    });

    final r = await _dio.post(
      '/documents/upload',
      data: form,
      options: Options(headers: {
        ...AppConfig.ngrokHeaders,
        'Content-Type': 'multipart/form-data',
      }),
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );
    return DocumentModel.fromJson(r.data['data']);
  }

  Future<DocumentModel> updateDocument(
      String id, String title, String desc, String cat) async {
    final r = await _dio.put('/documents/$id',
        data: {'title': title, 'description': desc, 'category': cat});
    return DocumentModel.fromJson(r.data['data']);
  }

  Future<void> deleteDocument(String id) async =>
      await _dio.delete('/documents/$id');

  Future<List<SubjectModel>> fetchSubjects(
      {int? year, String? department}) async {
    final p = <String, dynamic>{};
    if (year       != null) p['year']       = year;
    if (department != null) p['department'] = department;
    final r = await _dio.get('/subjects', queryParameters: p);
    return (r.data['data'] as List)
        .map((e) => SubjectModel.fromJson(e)).toList();
  }

  Future<List<String>> fetchDepartments() async {
    final r = await _dio.get('/subjects/departments/list');
    return List<String>.from(r.data['data']);
  }

  Future<SubjectModel> createSubject(Map<String, dynamic> body) async {
    final r = await _dio.post('/subjects', data: body);
    return SubjectModel.fromJson(r.data['data']);
  }

  Future<void> deleteSubject(String id) async =>
      await _dio.delete('/subjects/$id');

  Future<void> seedSubjects() async =>
      await _dio.post('/subjects/seed');
}