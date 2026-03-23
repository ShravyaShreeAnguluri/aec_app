import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/certificate_model.dart';
import '../services/app_config.dart';

class CertificateProvider extends ChangeNotifier {
  late final Dio _dio;

  CertificateProvider() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.uploadTimeout,
        headers: AppConfig.ngrokHeaders,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          o.headers.addAll(AppConfig.ngrokHeaders);
          h.next(o);
        },
      ),
    );
  }

  List<CertificateModel> _certs = [];
  bool _loading = false;
  String? _error;
  String? _deptFilter;
  String? _facultyFilter;

  bool get loading => _loading;
  String? get error => _error;
  String? get deptFilter => _deptFilter;
  String get baseUrl => AppConfig.baseUrl;

  List<CertificateModel> filtered(String? type) {
    var list = List<CertificateModel>.from(_certs);

    if (type != null) {
      list = list.where((c) => c.type == type).toList();
    }

    if (_deptFilter != null) {
      list = list.where((c) => c.department == _deptFilter).toList();
    }

    return list;
  }

  void setDeptFilter(String? d) {
    _deptFilter = d;
    notifyListeners();
  }

  void setFacultyFilter(String? name) {
    _facultyFilter = name;
  }

  Future<void> loadCertificates() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, dynamic>{};

      if (_facultyFilter != null && _facultyFilter!.isNotEmpty) {
        params['facultyName'] = _facultyFilter;
      }

      final r = await _dio.get('/certificates', queryParameters: params);

      _certs = (r.data['data'] as List)
          .map((e) => CertificateModel.fromJson(e))
          .toList();
    } catch (e) {
      _error = _err(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadCertificate({
    required File file,
    required String title,
    required String facultyName,
    required String department,
    required String type,
    required String issuedBy,
    required String issueDate,
  }) async {
    const allowed = ['Faculty Achievement', 'Training & Workshop'];

    if (!allowed.contains(type)) {
      _error =
      'Invalid type. Must be "Faculty Achievement" or "Training & Workshop"';
      notifyListeners();
      return false;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final fileName = file.path.split('/').last;

      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
        'title': title.trim(),
        'facultyName': facultyName.trim(),
        'department': department.trim(),
        'type': type,
        'issuedBy': issuedBy.trim(),
        'issueDate': issueDate,
      });

      final r = await _dio.post(
        '/certificates/upload',
        data: form,
        options: Options(
          headers: {
            ...AppConfig.ngrokHeaders,
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      final newCert = CertificateModel.fromJson(r.data['data']);
      _certs.insert(0, newCert);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _err(e);
      notifyListeners();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCertificate(String id) async {
    try {
      await _dio.delete('/certificates/$id');
      _certs.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _err(e);
      notifyListeners();
      return false;
    }
  }

  String _err(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Network error — update ngrok URL in app_config.dart';
      }

      final detail = e.response?.data?['detail'];
      if (detail != null) return detail.toString();

      return e.message ?? 'Request failed';
    }

    return e.toString();
  }
}