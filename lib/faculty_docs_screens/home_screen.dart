// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/document_model.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import 'upload_screen.dart';
import 'detail_screen.dart';
import 'subjects_screen.dart';
import 'certificates_screen.dart';

class HomeScreen extends StatefulWidget {
  // ✅ Accept facultyName so we can filter docs by uploader
  final String? facultyName;
  const HomeScreen({super.key, this.facultyName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  bool  _searching  = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<DocumentProvider>();
      // ✅ Pass facultyName so provider filters by uploader
      prov.setFacultyFilter(widget.facultyName);
      prov.init();
    });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentProvider>(
      builder: (_, prov, __) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _appBar(prov),
        body: _body(prov),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _goUpload(prov),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
          label: const Text('Upload',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  // ── AppBar — FIXED overflow ───────────────────────────────────────────────
  PreferredSizeWidget _appBar(DocumentProvider prov) {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      // ✅ Use titleSpacing 0 and tight layout to prevent overflow
      titleSpacing: 0,
      title: _searching
          ? Padding(
        padding: const EdgeInsets.only(left: 8),
        child: TextField(
          controller: _searchCtrl,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Search documents…',
              border: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero),
          style: AppTextStyles.heading3,
          onChanged: prov.setSearch,
        ),
      )
          : Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
                color: AppColors.primary, borderRadius: AppRadius.sm),
            child: const Icon(Icons.school_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          const Text('Faculty Docs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      ),
      // ✅ Only 3 small icons — no overflow
      actions: [
        _iconBtn(
          _searching ? Icons.close_rounded : Icons.search_rounded,
              () {
            setState(() => _searching = !_searching);
            if (!_searching) { _searchCtrl.clear(); prov.setSearch(''); }
          },
        ),
        _iconBtn(Icons.menu_book_rounded, () =>
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SubjectsScreen()))),
        _iconBtn(Icons.workspace_premium_rounded, () =>
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => CertificatesScreen(
                  facultyName: widget.facultyName,
                )))),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34, height: 34,            // ✅ smaller: 34 not 38
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.sm,
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, size: 16, color: AppColors.textDark), // ✅ smaller icon
    ),
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _body(DocumentProvider prov) {
    return RefreshIndicator(
      onRefresh: prov.init,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (prov.error != null)
            SliverToBoxAdapter(child: _errorBanner(prov)),
          if (prov.loading)
            SliverToBoxAdapter(
              child: LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                minHeight: 3,
              ),
            ),

          // ✅ Show whose docs are shown
          if (widget.facultyName != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: AppRadius.sm,
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.person_rounded,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text('Showing docs by: ${widget.facultyName}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ]),
              ),
            ),

          SliverToBoxAdapter(child: _yearStrip(prov)),
          SliverToBoxAdapter(child: _deptStrip(prov)),
          SliverToBoxAdapter(child: _categoryRow(prov)),
          SliverToBoxAdapter(child: _statsBadge(prov)),

          prov.filtered.isEmpty
              ? SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyPane(
              emoji: prov.loading ? '⏳'
                  : prov.error != null ? '📡'
                  : prov.search.isNotEmpty ? '🔍' : '📂',
              title: prov.loading ? 'Loading…'
                  : prov.error != null ? 'No connection'
                  : prov.search.isNotEmpty ? 'No results'
                  : 'No documents yet',
              subtitle: prov.loading
                  ? 'Fetching documents from server'
                  : prov.error != null
                  ? 'Pull down to retry once backend is running'
                  : prov.search.isNotEmpty
                  ? 'Try a different search term'
                  : prov.department != null
                  ? 'No files for ${prov.department} – Year ${prov.year}'
                  : 'Upload the first file for Year ${prov.year}',
              action: (!prov.loading && prov.error == null && prov.search.isEmpty)
                  ? ElevatedButton.icon(
                onPressed: () => _goUpload(prov),
                icon: const Icon(Icons.upload_rounded),
                label: const Text('Upload'),
              )
                  : null,
            ),
          )
              : SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (_, i) {
                  final doc = prov.filtered[i];
                  return DocumentTile(
                    doc:      doc,
                    onTap:    () => _goDetail(doc),
                    onDelete: () => _confirmDelete(doc),
                    onEdit:   () => _editSheet(doc),
                  );
                },
                childCount: prov.filtered.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yearStrip(DocumentProvider prov) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: List.generate(4, (i) {
          final y = i + 1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
              child: YearButton(
                year: y, selected: prov.year == y,
                count: prov.countForYear(y),
                onTap: () => prov.setYear(y),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _deptStrip(DocumentProvider prov) {
    final depts = prov.subjects
        .where((s) => s.year == prov.year)
        .map((s) => s.department)
        .toSet()
        .toList()
      ..sort();
    if (depts.isEmpty) return const SizedBox.shrink();
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('DEPARTMENT', style: AppTextStyles.label),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _deptChip('All Depts', prov.department == null, AppColors.primary,
                  () => prov.setDepartment(null)),
          ...depts.map((d) => _deptChip(d, prov.department == d,
              _deptColor(d), () => prov.setDepartment(d))),
        ]),
      ]),
    );
  }

  Widget _deptChip(String label, bool sel, Color c, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? c : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? c : AppColors.border, width: 1.5),
          boxShadow: sel ? [BoxShadow(color: c.withOpacity(0.3),
              blurRadius: 6, offset: const Offset(0, 2))] : [],
        ),
        child: Text(label, style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w700,
            color: sel ? Colors.white : AppColors.textMid)),
      ),
    );
  }

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

  Widget _categoryRow(DocumentProvider prov) {
    final cats = ['All', ...AppConstants.categories];
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final c   = cats[i];
          final sel = c == 'All' ? prov.category == null : prov.category == c;
          return GestureDetector(
            onTap: () => prov.setCategory(c == 'All' ? null : c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel ? AppColors.primary : AppColors.border),
              ),
              child: Text(c, style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.textMid)),
            ),
          );
        },
      ),
    );
  }

  Widget _statsBadge(DocumentProvider prov) {
    final count = prov.filtered.length;
    final c     = AppColors.forYear(prov.year);
    final label = prov.department != null
        ? '${prov.department}  ·  ${AppConstants.yearLabels[prov.year - 1]}  ·  $count file${count != 1 ? 's' : ''}'
        : '${AppConstants.yearLabels[prov.year - 1]}  ·  $count file${count != 1 ? 's' : ''}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: c)),
        ),
        if (prov.loading) ...[
          const SizedBox(width: 10),
          const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2,
                  color: AppColors.primary)),
        ],
      ]),
    );
  }

  Widget _errorBanner(DocumentProvider prov) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: AppRadius.sm,
        border: Border.all(color: AppColors.error.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(prov.error!,
            style: const TextStyle(fontSize: 12,
                color: AppColors.error, height: 1.5))),
        GestureDetector(
          onTap: prov.clearError,
          child: const Icon(Icons.close_rounded,
              color: AppColors.error, size: 18),
        ),
      ]),
    );
  }

  void _goUpload(DocumentProvider prov) async {
    if (prov.subjects.isEmpty) await prov.loadSubjects();
    if (!mounted) return;
    final ok = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => UploadScreen(
          facultyName: widget.facultyName,
        )));
    if (ok == true && mounted) prov.init();
  }

  void _goDetail(DocumentModel doc) =>
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => DetailScreen(doc: doc)));

  void _editSheet(DocumentModel doc) {
    final titleCtrl = TextEditingController(text: doc.title);
    final descCtrl  = TextEditingController(text: doc.description);
    String cat = doc.category;
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
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Edit Document', style: AppTextStyles.heading2),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 16),
                  TextField(controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 12),
                  TextField(controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 2),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: cat,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: AppConstants.categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setS(() => cat = v!),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final ok = await context.read<DocumentProvider>().update(
                            doc.id, titleCtrl.text.trim(),
                            descCtrl.text.trim(), cat);
                        if (ok && ctx.mounted) {
                          Navigator.pop(ctx);
                          _snack('Updated successfully');
                        }
                      },
                      child: const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ]),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(DocumentModel doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Text('Delete Document'),
        content: Text('Delete "${doc.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final success = await context.read<DocumentProvider>().delete(doc.id);
      _snack(success ? 'Deleted' : 'Failed to delete', isError: !success);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
    ));
  }
}