// lib/screens/detail_screen.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../models/document_model.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/app_config.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailScreen extends StatefulWidget {
  final DocumentModel doc;
  const DetailScreen({super.key, required this.doc});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool   _downloading = false;
  double _progress    = 0;
  String? _savedPath;

  String get _downloadUrl =>
      '${AppConfig.apiUrl}/documents/${widget.doc.id}/download';

  String get _viewUrl =>
      '${AppConfig.apiUrl}/documents/${widget.doc.id}/view';

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final typeColor = AppColors.forFileType(doc.fileType);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Document Details'),
        actions: [
          // ✅ Share / Open in browser button
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: 'Open in browser',
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── File icon + title ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: AppRadius.lg,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: AppRadius.md,
                ),
                child: Center(
                  child: Text(
                    doc.fileType.toUpperCase(),
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w900, color: typeColor),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(doc.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 6),
              Text(doc.subjectName,
                  style: const TextStyle(color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(doc.originalName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12,
                      color: AppColors.textLight)),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Metadata ──────────────────────────────────────────────────────
          _metaCard([
            _row(Icons.school_rounded,         'Year',      'Year ${doc.year}'),
            _row(Icons.apartment_rounded,      'Department', doc.department),
            _row(Icons.category_rounded,       'Category',  doc.category),
            _row(Icons.person_rounded,         'Uploaded By', doc.uploadedBy),
            _row(Icons.data_usage_rounded,     'File Size', doc.formattedSize),
            _row(Icons.download_rounded,       'Downloads', '${doc.downloadCount}'),
            _row(Icons.calendar_today_rounded, 'Date',      doc.shortDate),
          ]),

          if (doc.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            _metaCard([
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Description',
                        style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textLight)),
                    const SizedBox(height: 6),
                    Text(doc.description,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textMid,
                            height: 1.5)),
                  ],
                ),
              ),
            ]),
          ],

          const SizedBox(height: 24),

          // ── Download progress bar ─────────────────────────────────────────
          if (_downloading) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.download_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Downloading… ${(_progress * 100).toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ]),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _progress,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // ── Success message after download ────────────────────────────────
          if (_savedPath != null && !_downloading) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Downloaded!',
                          style: TextStyle(fontWeight: FontWeight.w700,
                              color: AppColors.success)),
                      Text(_savedPath!,
                          style: const TextStyle(fontSize: 11,
                              color: AppColors.textMid),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _openSavedFile,
                  child: const Text('Open'),
                ),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // ── Action buttons ────────────────────────────────────────────────
          Row(children: [
            // Open / View button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _downloading ? null : _openFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.visibility_rounded,
                    color: Colors.white, size: 18),
                label: const Text('Open File',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            // Download & save button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _downloading ? null : _downloadFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.download_rounded,
                    color: Colors.white, size: 18),
                label: const Text('Download',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),

          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  // ── Open file: download to temp then open with system viewer ─────────────
  Future<void> _openFile() async {
    setState(() { _downloading = true; _progress = 0; });
    try {
      final tempDir  = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/${widget.doc.originalName}';

      final dio = Dio();
      await dio.download(
        _downloadUrl,
        savePath,
        options: Options(headers: {'ngrok-skip-browser-warning': 'true'}),
        onReceiveProgress: (received, total) {
          if (total > 0) setState(() => _progress = received / total);
        },
      );

      setState(() { _downloading = false; _savedPath = null; });

      // ✅ Open with system app (PDF reader, Office, image viewer etc.)
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && mounted) {
        _snack('Cannot open: ${result.message}. Try Download instead.',
            isError: true);
      }
    } catch (e) {
      setState(() => _downloading = false);
      _snack('Failed to open: $e', isError: true);
    }
  }

  // ── Download: save to Downloads folder ───────────────────────────────────
  Future<void> _downloadFile() async {
    setState(() { _downloading = true; _progress = 0; _savedPath = null; });
    try {
      // Android: save to /storage/emulated/0/Download/
      // iOS: save to app Documents folder
      Directory? saveDir;
      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) {
          saveDir = await getExternalStorageDirectory();
        }
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      final savePath = '${saveDir!.path}/${widget.doc.originalName}';

      final dio = Dio();
      await dio.download(
        _downloadUrl,
        savePath,
        options: Options(headers: {'ngrok-skip-browser-warning': 'true'}),
        onReceiveProgress: (received, total) {
          if (total > 0) setState(() => _progress = received / total);
        },
      );

      setState(() { _downloading = false; _savedPath = savePath; });
      _snack('Saved to Downloads folder!');
    } catch (e) {
      setState(() => _downloading = false);
      _snack('Download failed: $e', isError: true);
    }
  }

  // ── Open already-saved file ───────────────────────────────────────────────
  Future<void> _openSavedFile() async {
    if (_savedPath == null) return;
    final result = await OpenFilex.open(_savedPath!);
    if (result.type != ResultType.done && mounted) {
      _snack('Cannot open file', isError: true);
    }
  }

  // ── Open in browser (fallback) ────────────────────────────────────────────
  Future<void> _openInBrowser() async {
    try {
      final uri = Uri.parse(_viewUrl);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!ok && mounted) {
        _snack('Could not open browser', isError: true);
      }
    } catch (e) {
      _snack('Failed to open in browser: $e', isError: true);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _metaCard(List<Widget> rows) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: AppRadius.md,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: rows),
  );

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 10),
      Text('$label  ',
          style: const TextStyle(fontSize: 13,
              color: AppColors.textLight, fontWeight: FontWeight.w500)),
      Expanded(
        child: Text(value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: AppColors.textDark)),
      ),
    ]),
  );

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10))),
    ));
  }
}