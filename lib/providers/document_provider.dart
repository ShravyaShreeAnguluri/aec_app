// lib/providers/document_provider.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/document_model.dart';
import '../models/subject_model.dart';
import '../services/app_config.dart';

class DocumentProvider extends ChangeNotifier {

  late final Dio _dio;

  DocumentProvider() {
    _dio = Dio(BaseOptions(
      baseUrl:        AppConfig.apiUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout:    AppConfig.uploadTimeout,
      headers:        AppConfig.ngrokHeaders,
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) { o.headers.addAll(AppConfig.ngrokHeaders); h.next(o); },
    ));
  }

  // ── State ─────────────────────────────────────────────────────────────────
  List<DocumentModel>  _docs     = [];
  List<SubjectModel>   _subjects = [];

  bool    _loading   = false;
  String? _error;
  int     _year      = 1;
  String? _department;
  String? _category;
  String  _search    = '';
  String? _facultyFilter;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<DocumentModel> get docs     => _docs;
  List<SubjectModel>  get subjects => _subjects;
  bool    get loading    => _loading;
  String? get error      => _error;
  int     get year       => _year;
  String? get department => _department;
  String? get category   => _category;
  String  get search     => _search;
  String get baseUrl => AppConfig.apiUrl;

  List<DocumentModel> get filtered {
    var list = List<DocumentModel>.from(_docs);
    list = list.where((d) => d.year == _year).toList();
    if (_department != null) list = list.where((d) => d.department == _department).toList();
    if (_category   != null) list = list.where((d) => d.category   == _category  ).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((d) =>
      d.title.toLowerCase().contains(q)       ||
          d.subjectName.toLowerCase().contains(q) ||
          d.department.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  int countForYear(int y) => _docs.where((d) => d.year == y).length;

  // ── Setters ───────────────────────────────────────────────────────────────
  void setYear(int y)           { _year = y; _department = null; notifyListeners(); }
  void setDepartment(String? d) { _department = d; notifyListeners(); }
  void setCategory(String? c)   { _category = c;   notifyListeners(); }
  void setSearch(String s)      { _search = s;     notifyListeners(); }
  void clearError()             { _error = null;   notifyListeners(); }
  void setFacultyFilter(String? name) { _facultyFilter = name; }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    _loading = true; _error = null; notifyListeners();
    try {
      await Future.wait([loadDocs(), loadSubjects()])
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      _error = _err(e);
    } finally {
      _loading = false; notifyListeners();
    }
  }

  Future<void> loadDocs() async {
    final params = <String, dynamic>{};
    if (_facultyFilter != null && _facultyFilter!.isNotEmpty) {
      params['uploadedBy'] = _facultyFilter;
    }
    final r = await _dio.get('/documents', queryParameters: params);
    _docs = (r.data['data'] as List).map((e) => DocumentModel.fromJson(e)).toList();
  }

  Future<void> loadSubjects() async {
    final r = await _dio.get('/subjects');
    _subjects = (r.data['data'] as List).map((e) => SubjectModel.fromJson(e)).toList();
  }

  // ── Upload ────────────────────────────────────────────────────────────────
  Future<bool> upload({
    required File   file,
    required String title,
    required String description,
    required int    year,
    required String department,
    required String subjectId,
    required String subjectName,
    required String category,
    required String uploadedBy,
    void Function(double)? onProgress,
  }) async {
    try {
      final form = FormData.fromMap({
        'file':        await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
        'title':       title,
        'description': description,
        'year':        year.toString(),
        'department':  department,
        'subject':     subjectId,
        'subjectName': subjectName,
        'category':    category,
        'uploadedBy':  uploadedBy,
      });
      final r = await _dio.post('/documents/upload', data: form,
        options: Options(headers: {...AppConfig.ngrokHeaders, 'Content-Type': 'multipart/form-data'}),
        onSendProgress: (s, t) { if (t > 0) onProgress?.call(s / t); },
      );
      _docs.insert(0, DocumentModel.fromJson(r.data['data']));
      notifyListeners(); return true;
    } catch (e) { _error = _err(e); notifyListeners(); return false; }
  }

  Future<bool> update(String id, String title, String desc, String cat) async {
    try {
      final r = await _dio.put('/documents/$id',
          data: {'title': title, 'description': desc, 'category': cat});
      final i = _docs.indexWhere((d) => d.id == id);
      if (i != -1) _docs[i] = DocumentModel.fromJson(r.data['data']);
      notifyListeners(); return true;
    } catch (e) { _error = _err(e); notifyListeners(); return false; }
  }

  Future<bool> delete(String id) async {
    try {
      await _dio.delete('/documents/$id');
      _docs.removeWhere((d) => d.id == id);
      notifyListeners(); return true;
    } catch (e) { _error = _err(e); notifyListeners(); return false; }
  }

  Future<bool> addSubject(Map<String, dynamic> body) async {
    try {
      final r = await _dio.post('/subjects', data: body);
      _subjects.add(SubjectModel.fromJson(r.data['data']));
      notifyListeners(); return true;
    } catch (e) { _error = _err(e); notifyListeners(); return false; }
  }

  Future<bool> removeSubject(String id) async {
    try {
      await _dio.delete('/subjects/$id');
      _subjects.removeWhere((s) => s.id == id);
      notifyListeners(); return true;
    } catch (e) { _error = _err(e); notifyListeners(); return false; }
  }

  Future<void> seedSubjects() async {
    try { await _dio.post('/subjects/seed'); await loadSubjects(); }
    catch (e) { _error = _err(e); notifyListeners(); }
  }

  String _err(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError   ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Network error — update ngrok URL in lib/config/app_config.dart';
      }
      return e.response?.data?['detail'] ?? e.message ?? 'Network error';
    }
    return e.toString();
  }
}