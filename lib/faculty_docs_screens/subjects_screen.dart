// lib/screens/operator_subjects_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/subject_model.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});
  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  int     _year = 1;
  String? _dept;

  static const _deptList = ['CSE', 'ECE', 'MECH', 'CIVIL', 'IT', 'EEE', 'Other'];

  static const _deptColors = {
    'CSE':   Color(0xFF1A56DB),
    'ECE':   Color(0xFF7C3AED),
    'MECH':  Color(0xFFD97706),
    'CIVIL': Color(0xFF059669),
    'IT':    Color(0xFFDB2777),
    'EEE':   Color(0xFF0891B2),
  };

  Color _deptColor(String d) => _deptColors[d] ?? AppColors.primary;

  @override
  void initState() {
    super.initState();
    // Load subjects when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentProvider>().loadSubjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentProvider>(
      builder: (ctx, prov, __) {
        final list = prov.subjects.where((s) {
          if (s.year != _year) return false;
          if (_dept != null && s.department != _dept) return false;
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.white,
            title: const Text('Subjects'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  _showLoadingDialog('Seeding subjects…');
                  await prov.seedSubjects();
                  if (mounted) {
                    Navigator.pop(context);
                    _snack('✅ Loaded subjects for CSE, ECE, MECH, CIVIL, IT');
                  }
                },
                icon: const Icon(Icons.auto_fix_high_rounded, size: 17),
                label: const Text('Seed'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppColors.border),
            ),
          ),
          // ✅ FAB uses outer context's prov directly
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddSheet(context, prov),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
          body: Column(children: [
            // Year tabs
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: List.generate(4, (i) {
                final y   = i + 1;
                final c   = AppColors.forYear(y);
                final sel = _year == y;
                return Expanded(child: GestureDetector(
                  onTap: () => setState(() { _year = y; _dept = null; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? c : AppColors.white,
                      borderRadius: AppRadius.sm,
                      border: Border.all(color: sel ? c : AppColors.border, width: 1.5),
                    ),
                    child: Text('Year $y',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : AppColors.textDark)),
                  ),
                ));
              })),
            ),

            // Department filter chips
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _deptChip('All', _dept == null, AppColors.primary,
                          () => setState(() => _dept = null)),
                  ..._deptList.map((d) => _deptChip(
                      d, _dept == d, _deptColor(d),
                          () => setState(() => _dept = d))),
                ]),
              ),
            ),

            // Count badge
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.forYear(_year).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _dept != null
                        ? '$_dept · Year $_year · ${list.length} subject${list.length != 1 ? 's' : ''}'
                        : 'Year $_year · ${list.length} subject${list.length != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppColors.forYear(_year)),
                  ),
                ),
                if (prov.loading) ...[
                  const SizedBox(width: 10),
                  const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: AppColors.primary)),
                ],
              ]),
            ),

            // Subject list
            Expanded(
              child: list.isEmpty
                  ? EmptyPane(
                emoji: '📚',
                title: 'No subjects',
                subtitle: _dept != null
                    ? 'No subjects for $_dept – Year $_year\nTap + to add or use Seed'
                    : 'Tap + to add or tap Seed to load defaults',
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: list.length,
                itemBuilder: (_, i) => _SubjectCard(
                  subject: list[i],
                  onDelete: () => _confirmDelete(prov, list[i]),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _deptChip(String label, bool sel, Color c, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? c : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? c : AppColors.border, width: 1.5),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: sel ? Colors.white : AppColors.textMid,
        )),
      ),
    );
  }

  // ── Add Subject Sheet ─────────────────────────────────────────────────────
  // ✅ Takes BuildContext and DocumentProvider directly — no nested context issues

  void _showAddSheet(BuildContext screenContext, DocumentProvider prov) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    int yr = _year;
    String dept = _dept ?? _deptList.first;
    int semester = _year == 1 ? 1 : ((_year - 1) * 2) + 1;
    final fKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: screenContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // ✅ useRootNavigator avoids context issues with nested navigators
      useRootNavigator: false,
      builder: (sheetCtx) {
        // ✅ Use StatefulBuilder with its own state
        return StatefulBuilder(
          builder: (_, setModal) {
            bool saving = false;

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                    color: AppColors.white, borderRadius: AppRadius.top),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Form(
                  key: fKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Header
                      Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: _deptColor(dept).withOpacity(0.1),
                            borderRadius: AppRadius.sm,
                          ),
                          child: Icon(Icons.menu_book_rounded,
                              color: _deptColor(dept), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text('Add Subject', style: AppTextStyles.heading2),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ]),
                      const SizedBox(height: 20),

                      // Subject Name
                      TextFormField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Subject Name *',
                          hintText: 'e.g. Data Structures',
                          prefixIcon: Icon(Icons.menu_book_outlined, size: 20),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Subject name is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Subject Code
                      TextFormField(
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Subject Code *',
                          hintText: 'e.g. CS301',
                          prefixIcon: Icon(Icons.tag_rounded, size: 20),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Code is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Department
                      DropdownButtonFormField<String>(
                        value: dept,
                        decoration: const InputDecoration(
                          labelText: 'Department *',
                          prefixIcon: Icon(Icons.apartment_rounded, size: 20),
                        ),
                        items: _deptList.map((d) => DropdownMenuItem(
                            value: d, child: Text(d))).toList(),
                        onChanged: (v) => setModal(() => dept = v!),
                        validator: (v) => v == null ? 'Select department' : null,
                      ),
                      const SizedBox(height: 12),

                      // Year
                      DropdownButtonFormField<int>(
                        value: yr,
                        decoration: const InputDecoration(
                          labelText: 'Year *',
                          prefixIcon: Icon(Icons.school_rounded, size: 20),
                        ),
                        items: [1, 2, 3, 4].map((y) => DropdownMenuItem(
                            value: y,
                            child: Text(AppConstants.yearLabels[y - 1]))).toList(),
                        onChanged: (v) => setModal(() => yr = v!),
                      ),

                      const SizedBox(height: 12),

                      DropdownButtonFormField<int>(
                        value: semester,
                        decoration: const InputDecoration(
                          labelText: 'Semester *',
                          prefixIcon: Icon(Icons.calendar_view_week_rounded, size: 20),
                        ),
                        items: [1, 2, 3, 4, 5, 6, 7, 8]
                            .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text('Semester $s'),
                        ))
                            .toList(),
                        onChanged: (v) => setModal(() => semester = v!),
                      ),

                      const SizedBox(height: 24),

                      // ✅ Save button — calls prov directly, not via context.read
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: StatefulBuilder(
                          builder: (_, setSaveBtn) => ElevatedButton(
                            onPressed: saving ? null : () async {
                              if (!fKey.currentState!.validate()) return;

                              setSaveBtn(() => saving = true);

                              try {
                                // ✅ Call provider directly — no context.read needed
                                final success = await prov.addSubject({
                                  'name': nameCtrl.text.trim(),
                                  'code': codeCtrl.text.trim().toUpperCase(),
                                  'year': yr,
                                  'department': dept,
                                  'semester': semester,
                                  'description': '',
                                });

                                if (success) {
                                  Navigator.pop(sheetCtx);
                                  setState(() { _year = yr; _dept = dept; });
                                  _snack('✅ ${nameCtrl.text.trim()} added to $dept – Year $yr');
                                } else {
                                  setSaveBtn(() => saving = false);
                                  _snack(prov.error ?? 'Failed to add subject. Check connection.',
                                      isError: true);
                                }
                              } catch (e) {
                                setSaveBtn(() => saving = false);
                                _snack('Error: $e', isError: true);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              shape: const RoundedRectangleBorder(
                                  borderRadius: AppRadius.md),
                            ),
                            child: saving
                                ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2.5)),
                                  SizedBox(width: 12),
                                  Text('Adding Subject…'),
                                ])
                                : const Text('Add Subject',
                                style: TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(DocumentProvider prov, SubjectModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Text('Delete Subject'),
        content: Text('Delete "${s.name}" (${s.department})?'),
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
      await prov.removeSubject(s.id);
      _snack('Subject deleted');
    }
  }

  void _showLoadingDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text(msg)),
        ]),
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
      duration: Duration(seconds: isError ? 4 : 2),
    ));
  }
}

// ── Subject Card ──────────────────────────────────────────────────────────────

class _SubjectCard extends StatelessWidget {
  final SubjectModel subject;
  final VoidCallback onDelete;
  const _SubjectCard({required this.subject, required this.onDelete});

  static const _deptColors = {
    'CSE':   Color(0xFF1A56DB),
    'ECE':   Color(0xFF7C3AED),
    'MECH':  Color(0xFFD97706),
    'CIVIL': Color(0xFF059669),
    'IT':    Color(0xFFDB2777),
    'EEE':   Color(0xFF0891B2),
  };

  @override
  Widget build(BuildContext context) {
    final yearC = AppColors.forYear(subject.year);
    final deptC = _deptColors[subject.department] ?? AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: deptC.withOpacity(0.1),
            borderRadius: AppRadius.sm,
            border: Border.all(color: deptC.withOpacity(0.2)),
          ),
          alignment: Alignment.center,
          child: Text(
            subject.code.length > 5 ? subject.code.substring(0, 5) : subject.code,
            style: TextStyle(color: deptC, fontWeight: FontWeight.w800,
                fontSize: 10, letterSpacing: -0.5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(subject.name, style: AppTextStyles.heading3,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Wrap(spacing: 6, children: [
            _pill(subject.department, deptC),
            _pill(AppConstants.yearLabels[subject.year - 1], yearC),
            _pill('Sem ${subject.semester}', AppColors.textLight),
          ]),
        ])),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppColors.error, size: 20),
          onPressed: onDelete,
        ),
      ]),
    );
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: TextStyle(fontSize: 10,
        fontWeight: FontWeight.w600, color: color)),
  );
}