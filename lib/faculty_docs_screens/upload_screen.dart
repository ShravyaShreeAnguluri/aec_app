// lib/screens/upload_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/subject_model.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';

class UploadScreen extends StatefulWidget {
  // ✅ facultyName = who is uploading (stored as uploadedBy in DB)
  final String? facultyName;
  const UploadScreen({super.key, this.facultyName});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  File?   _file;
  String? _fileName;
  int     _year       = 1;
  String? _department;
  String? _subjectId;
  String  _subjectName = '';
  String  _category   = 'Lecture Notes';
  bool    _uploading  = false;
  double  _progress   = 0;

  static const _depts = ['CSE','ECE','MECH','CIVIL','IT','EEE','Other'];
  static const _categories = [
    'Lecture Notes','Assignment','Reference Material',
    'Lab Manual','Question Paper','Others',
  ];

  List<SubjectModel> get _filteredSubjects {
    final prov = context.read<DocumentProvider>();

    final filtered = prov.subjects.where((s) {
      return s.year == _year &&
          (_department == null || s.department == _department);
    }).toList();

    final seen = <String>{};
    return filtered.where((s) => seen.add(s.id)).toList();
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: const Text('Upload Document'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ✅ Show who is uploading
              if (widget.facultyName != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: AppRadius.sm,
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.person_rounded,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Text('Uploading as: ${widget.facultyName}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ]),
                ),

              // File picker
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _file != null
                        ? AppColors.primary.withOpacity(0.05) : AppColors.white,
                    borderRadius: AppRadius.md,
                    border: Border.all(
                      color: _file != null ? AppColors.primary : AppColors.border,
                      width: _file != null ? 2 : 1,
                    ),
                  ),
                  child: _file == null
                      ? Column(children: const [
                    Icon(Icons.upload_file_rounded,
                        size: 40, color: AppColors.primary),
                    SizedBox(height: 10),
                    Text('Tap to select file',
                        style: TextStyle(fontWeight: FontWeight.w600,
                            color: AppColors.textDark)),
                    SizedBox(height: 4),
                    Text('PDF, PPT, DOC, XLS, Images',
                        style: TextStyle(fontSize: 12,
                            color: AppColors.textLight)),
                  ])
                      : Row(children: [
                    const Icon(Icons.insert_drive_file_rounded,
                        color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_fileName!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis)),
                    TextButton(onPressed: _pickFile,
                        child: const Text('Change')),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Document Title *',
                  prefixIcon: Icon(Icons.title_rounded, size: 20),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Year
              DropdownButtonFormField<int>(
                value: _year,
                decoration: const InputDecoration(
                  labelText: 'Year *',
                  prefixIcon: Icon(Icons.school_rounded, size: 20),
                ),
                items: [1,2,3,4].map((y) => DropdownMenuItem(
                    value: y,
                    child: Text(AppConstants.yearLabels[y-1]))).toList(),
                onChanged: (v) => setState(() {
                  _year = v!; _subjectId = null; _subjectName = '';
                }),
              ),
              const SizedBox(height: 12),

              // Department
              DropdownButtonFormField<String>(
                value: _department,
                decoration: const InputDecoration(
                  labelText: 'Department *',
                  prefixIcon: Icon(Icons.apartment_rounded, size: 20),
                ),
                items: _depts.map((d) =>
                    DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => setState(() {
                  _department = v; _subjectId = null; _subjectName = '';
                }),
                validator: (v) => v == null ? 'Select department' : null,
              ),
              const SizedBox(height: 12),

              // Subject
              DropdownButtonFormField<String>(
                value: (_subjectId != null &&
                    _filteredSubjects.any((s) => s.id == _subjectId))
                    ? _subjectId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Subject *',
                  prefixIcon: Icon(Icons.menu_book_rounded, size: 20),
                ),
                items: _filteredSubjects
                    .map((s) => DropdownMenuItem<String>(
                  value: s.id,
                  child: Text('${s.name} (${s.code})'),
                ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final s = _filteredSubjects.firstWhere((s) => s.id == v);
                  setState(() {
                    _subjectId = v;
                    _subjectName = s.name;
                  });
                },
                validator: (v) => v == null ? 'Select subject' : null,
              ),
              const SizedBox(height: 12),

              // Category
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.category_rounded, size: 20),
                ),
                items: _categories.map((c) =>
                    DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 32),

              // Upload button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _upload,
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Upload Document',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),

        // Upload overlay
        if (_uploading)
          Container(
            color: Colors.black.withOpacity(0.4),
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(40),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.lg,
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Uploading… ${(_progress * 100).toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _progress),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf','ppt','pptx','doc','docx','xls','xlsx',
        'jpg','jpeg','png'],
    );
    if (r != null) setState(() {
      _file     = File(r.files.first.path!);
      _fileName = r.files.first.name;
    });
  }

  Future<void> _upload() async {
    if (_file == null) {
      _snack('Please select a file', isError: true); return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() { _uploading = true; _progress = 0; });

    // ✅ Use facultyName as uploadedBy — so filtering works
    final uploadedBy = widget.facultyName ?? 'Faculty';

    final ok = await context.read<DocumentProvider>().upload(
      file:        _file!,
      title:       _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      year:        _year,
      department:  _department!,
      subjectId:   _subjectId!,
      subjectName: _subjectName,
      category:    _category,
      uploadedBy:  uploadedBy,
      onProgress:  (p) => setState(() => _progress = p),
    );

    setState(() => _uploading = false);

    if (ok && mounted) {
      Navigator.pop(context, true);
    } else if (mounted) {
      _snack(context.read<DocumentProvider>().error ?? 'Upload failed',
          isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }
}