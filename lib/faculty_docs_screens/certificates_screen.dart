// lib/screens/certificates_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../providers/certificate_provider.dart';
import '../models/certificate_model.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_config.dart';

class CertificatesScreen extends StatefulWidget {
  final String? facultyName;
  const CertificatesScreen({super.key, this.facultyName});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<CertificateProvider>();
      prov.setFacultyFilter(widget.facultyName);
      prov.loadCertificates();
    });
  }

  String _certDownloadUrl(String id) =>
      '${AppConfig.apiUrl}/certificates/$id/download';

  String _certViewUrl(String id) =>
      '${AppConfig.apiUrl}/certificates/$id/view';

  Future<void> _viewCertificate(CertificateModel cert) async {
    try {
      final uri = Uri.parse(_certViewUrl(cert.id));
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open certificate'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to view certificate: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openCertificate(CertificateModel cert) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/${cert.originalName}';

      final dio = Dio();
      await dio.download(
        _certDownloadUrl(cert.id),
        savePath,
        options: Options(headers: {'ngrok-skip-browser-warning': 'true'}),
      );

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open file: ${result.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open certificate: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _downloadCertificate(CertificateModel cert) async {
    try {
      Directory? saveDir;

      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) {
          saveDir = await getExternalStorageDirectory();
        }
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      final savePath = '${saveDir!.path}/${cert.originalName}';

      final dio = Dio();
      await dio.download(
        _certDownloadUrl(cert.id),
        savePath,
        options: Options(headers: {'ngrok-skip-browser-warning': 'true'}),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded to: $savePath'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<CertificateProvider>(
      builder: (_, prov, __) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.workspace_premium_rounded,
                color: Color(0xFF1A56DB), size: 20),
            SizedBox(width: 8),
            Text('Certificates',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          bottom: TabBar(
            controller: _tab,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMid,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Achievements'),
              Tab(text: 'Training'),
            ],
          ),
        ),
        body: Column(children: [

          // ── Error banner ─────────────────────────────────────────────────
          if (prov.error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: AppRadius.sm,
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.wifi_off_rounded,
                    color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(prov.error!,
                    style: const TextStyle(fontSize: 12,
                        color: AppColors.error))),
                GestureDetector(
                  onTap: () {
                    prov.loadCertificates();
                  },
                  child: const Text('Retry',
                      style: TextStyle(color: AppColors.primary,
                          fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ]),
            ),

          // ── Whose certs banner ────────────────────────────────────────────
          if (widget.facultyName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.primary.withOpacity(0.07),
              child: Row(children: [
                const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 14),
                const SizedBox(width: 6),
                Text('Showing: ${widget.facultyName}',
                    style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ]),
            ),

          // ── Loading bar ───────────────────────────────────────────────────
          if (prov.loading)
            LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              minHeight: 3,
            ),

          // ── Stats strip ───────────────────────────────────────────────────
          _statsStrip(prov),

          // ── Dept filter chips ─────────────────────────────────────────────
          _deptChips(prov),

          // ── Tab content ───────────────────────────────────────────────────
          Expanded(
            child: TabBarView(controller: _tab, children: [
              _certList(prov, null),
              _certList(prov, 'Faculty Achievement'),
              _certList(prov, 'Training & Workshop'),
            ]),
          ),
        ]),

        floatingActionButton: FloatingActionButton.extended(
          onPressed: prov.loading ? null : () => _showAddSheet(prov),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Certificate',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────────
  Widget _statsStrip(CertificateProvider prov) {
    final all   = prov.filtered(null).length;
    final ach   = prov.filtered('Faculty Achievement').length;
    final train = prov.filtered('Training & Workshop').length;
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        _statBox('Total',        '$all',   AppColors.primary),
        const SizedBox(width: 10),
        _statBox('Achievements', '$ach',   const Color(0xFF1A56DB)),
        const SizedBox(width: 10),
        _statBox('Trainings',    '$train', const Color(0xFF7C3AED)),
      ]),
    );
  }

  Widget _statBox(String label, String val, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: AppRadius.sm,
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(val, style: TextStyle(fontSize: 20,
            fontWeight: FontWeight.bold, color: c)),
        Text(label, style: TextStyle(fontSize: 10,
            color: c, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  // ── Dept chips ────────────────────────────────────────────────────────────
  Widget _deptChips(CertificateProvider prov) {
    final depts = ['All', 'CSE', 'ECE', 'MECH', 'CIVIL', 'IT', 'EEE'];
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: depts.length,
        itemBuilder: (_, i) {
          final d   = depts[i];
          final sel = d == 'All' ? prov.deptFilter == null : prov.deptFilter == d;
          return GestureDetector(
            onTap: () => prov.setDeptFilter(d == 'All' ? null : d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? AppColors.primary : AppColors.border),
              ),
              child: Text(d, style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : AppColors.textMid)),
            ),
          );
        },
      ),
    );
  }

  // ── Certificate list ──────────────────────────────────────────────────────
  Widget _certList(CertificateProvider prov, String? type) {
    final items = prov.filtered(type);
    if (prov.loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.workspace_premium_outlined,
              size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          Text(
              prov.error != null
                  ? 'Connection failed'
                  : widget.facultyName != null
                  ? 'No certificates for ${widget.facultyName}'
                  : 'No certificates yet',
              style: const TextStyle(color: AppColors.textMid,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
              prov.error != null
                  ? 'Update ngrok URL and retry'
                  : 'Tap "+ Add Certificate" to upload',
              style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
          if (prov.error != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: prov.loadCertificates,
              child: const Text('Retry'),
            ),
          ],
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: prov.loadCertificates,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
        itemCount: items.length,
        itemBuilder: (_, i) => _certCard(items[i], prov),
      ),
    );
  }

  Widget _certCard(CertificateModel cert, CertificateProvider prov) {
    final isAch     = cert.type == 'Faculty Achievement';
    final typeColor = isAch ? const Color(0xFF1A56DB) : const Color(0xFF7C3AED);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1), borderRadius: AppRadius.sm),
          child: Icon(isAch ? Icons.emoji_events_rounded : Icons.school_rounded,
              color: typeColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cert.title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text(cert.facultyName,
                style: const TextStyle(fontSize: 12, color: AppColors.textMid)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _chip(cert.department, _deptColor(cert.department)),
              _chip(cert.issueDate.length >= 10
                  ? cert.issueDate.substring(0, 10) : cert.issueDate,
                  AppColors.textMid, icon: Icons.calendar_today_rounded),
              if (cert.issuedBy.isNotEmpty)
                _chip(cert.issuedBy, AppColors.textLight,
                    icon: Icons.business_rounded),
              _chip(_fmtSize(cert.fileSize), AppColors.textLight),
            ]),
          ],
        )),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMid),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (value) {
            switch (value) {
              case 'view':
                _viewCertificate(cert);
                break;
              case 'open':
                _openCertificate(cert);
                break;
              case 'download':
                _downloadCertificate(cert);
                break;
              case 'delete':
                _confirmDelete(cert, prov);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility_rounded, size: 18, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('View'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF059669)),
                  SizedBox(width: 10),
                  Text('Open'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'download',
              child: Row(
                children: [
                  Icon(Icons.download_rounded, size: 18, color: Color(0xFF7C3AED)),
                  SizedBox(width: 10),
                  Text('Download'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                  SizedBox(width: 10),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _chip(String label, Color c, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 10, color: c), const SizedBox(width: 3)],
      Text(label, style: TextStyle(fontSize: 10,
          fontWeight: FontWeight.w600, color: c)),
    ]),
  );

  Color _deptColor(String d) {
    switch (d.toUpperCase()) {
      case 'CSE':   return const Color(0xFF1A56DB);
      case 'ECE':   return const Color(0xFF7C3AED);
      case 'MECH':  return const Color(0xFFD97706);
      case 'CIVIL': return const Color(0xFF059669);
      case 'IT':    return const Color(0xFFDB2777);
      case 'EEE':   return const Color(0xFF0891B2);
      default:      return AppColors.primary;
    }
  }

  String _fmtSize(int b) {
    if (b < 1024)       return '$b B';
    if (b < 1048576)    return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1048576).toStringAsFixed(1)} MB';
  }

  // ── Add certificate bottom sheet ──────────────────────────────────────────
  void _showAddSheet(CertificateProvider prov) {
    final titleCtrl    = TextEditingController();
    final issuedByCtrl = TextEditingController();
    final facultyCtrl  = TextEditingController(text: widget.facultyName ?? '');
    String certType    = 'Faculty Achievement';
    String dept        = 'CSE';
    DateTime issueDate = DateTime.now();
    File?   file;
    String? fileName;
    bool    uploading  = false;
    String? sheetError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
                color: AppColors.white, borderRadius: AppRadius.top),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // Header
                    Row(children: [
                      const Text('Add Certificate',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                          onPressed: uploading ? null : () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close)),
                    ]),

                    // ── Sheet error ─────────────────────────────────────────────
                    if (sheetError != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.08),
                          borderRadius: AppRadius.sm,
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(sheetError!,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.error))),
                        ]),
                      ),

                    const SizedBox(height: 4),

                    // ── Type toggle ─────────────────────────────────────────────
                    Row(children: [
                      Expanded(child: _typeBtn('Achievement', 'Faculty Achievement',
                          certType, const Color(0xFF1A56DB),
                              () => setS(() => certType = 'Faculty Achievement'),
                          uploading)),
                      const SizedBox(width: 10),
                      Expanded(child: _typeBtn('Training', 'Training & Workshop',
                          certType, const Color(0xFF7C3AED),
                              () => setS(() => certType = 'Training & Workshop'),
                          uploading)),
                    ]),
                    const SizedBox(height: 14),

                    // ── Faculty name ────────────────────────────────────────────
                    TextField(
                      controller: facultyCtrl,
                      readOnly: widget.facultyName != null,
                      decoration: InputDecoration(
                        labelText: 'Faculty Name *',
                        prefixIcon: const Icon(Icons.person_rounded, size: 18),
                        filled: true,
                        fillColor: widget.facultyName != null
                            ? const Color(0xFFF5F5F5) : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Title ───────────────────────────────────────────────────
                    TextField(
                      controller: titleCtrl,
                      enabled: !uploading,
                      decoration: const InputDecoration(
                        labelText: 'Certificate Title *',
                        prefixIcon: Icon(Icons.title_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Issued by ────────────────────────────────────────────────
                    TextField(
                      controller: issuedByCtrl,
                      enabled: !uploading,
                      decoration: const InputDecoration(
                        labelText: 'Issued By (e.g. NPTEL, Coursera) *',
                        prefixIcon: Icon(Icons.business_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Department ───────────────────────────────────────────────
                    DropdownButtonFormField<String>(
                      value: dept,
                      decoration: const InputDecoration(
                        labelText: 'Department *',
                        prefixIcon: Icon(Icons.apartment_rounded, size: 18),
                      ),
                      items: ['CSE','ECE','MECH','CIVIL','IT','EEE','Other']
                          .map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: uploading ? null : (v) => setS(() => dept = v!),
                    ),
                    const SizedBox(height: 12),

                    // ── Issue date ───────────────────────────────────────────────
                    GestureDetector(
                      onTap: uploading ? null : () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: issueDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setS(() => issueDate = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppRadius.sm,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(
                            'Issue Date: ${issueDate.year}-'
                                '${issueDate.month.toString().padLeft(2,'0')}-'
                                '${issueDate.day.toString().padLeft(2,'0')}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── File picker ──────────────────────────────────────────────
                    GestureDetector(
                      onTap: uploading ? null : () async {
                        final r = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf','jpg','jpeg','png','doc','docx'],
                        );
                        if (r != null) setS(() {
                          file     = File(r.files.first.path!);
                          fileName = r.files.first.name;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: file != null
                              ? AppColors.primary.withOpacity(0.05) : Colors.white,
                          borderRadius: AppRadius.sm,
                          border: Border.all(
                              color: file != null ? AppColors.primary : AppColors.border,
                              width: file != null ? 2 : 1),
                        ),
                        child: Row(children: [
                          Icon(Icons.attach_file_rounded,
                              color: file != null ? AppColors.primary : AppColors.textLight,
                              size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            file != null ? fileName! : 'Attach Certificate File *  (PDF/Image)',
                            style: TextStyle(
                                color: file != null ? AppColors.textDark : AppColors.textLight,
                                fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          )),
                          if (file != null)
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.success, size: 18),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Upload button ─────────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: uploading ? null : () async {
                          // Validate
                          final name = facultyCtrl.text.trim();
                          final titleText = titleCtrl.text.trim();
                          final issuedByText = issuedByCtrl.text.trim();

                          if (name.isEmpty) {
                            setS(() => sheetError = 'Faculty name is required'); return;
                          }
                          if (titleText.isEmpty) {
                            setS(() => sheetError = 'Certificate title is required'); return;
                          }
                          if (issuedByText.isEmpty) {
                            setS(() => sheetError = '"Issued By" is required'); return;
                          }
                          if (file == null) {
                            setS(() => sheetError = 'Please attach a certificate file'); return;
                          }

                          setS(() { uploading = true; sheetError = null; });

                          final ok = await prov.uploadCertificate(
                            file:        file!,
                            title:       titleText,
                            facultyName: name,
                            department:  dept,
                            type:        certType,
                            issuedBy:    issuedByText,
                            issueDate:
                            '${issueDate.year}-'
                                '${issueDate.month.toString().padLeft(2,'0')}-'
                                '${issueDate.day.toString().padLeft(2,'0')}',
                          );

                          if (ok) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Certificate uploaded!'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating),
                              );
                            }
                          } else {
                            setS(() {
                              uploading  = false;
                              sheetError = prov.error ?? 'Upload failed — check connection';
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: uploading
                            ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Uploading…',
                                style: TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        )
                            : const Text('Upload Certificate',
                            style: TextStyle(fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeBtn(String label, String value, String current,
      Color c, VoidCallback onTap, bool disabled) {
    final sel = current == value;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: sel ? c : AppColors.background,
          borderRadius: AppRadius.sm,
          border: Border.all(color: c, width: sel ? 0 : 1.5),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700,
                color: sel ? Colors.white : c)),
      ),
    );
  }

  void _confirmDelete(CertificateModel cert, CertificateProvider prov) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Text('Delete Certificate'),
        content: Text('Delete "${cert.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final success = await prov.deleteCertificate(cert.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Deleted' : 'Failed to delete'),
          backgroundColor: success ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}