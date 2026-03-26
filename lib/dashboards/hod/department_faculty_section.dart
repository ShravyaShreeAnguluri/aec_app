import 'package:flutter/material.dart';

// ─── Colour palette (mirrors HOD dashboard) ────────────────────────────────
class _C {
  static const navy      = Color(0xFF0A2342);
  static const navyMid   = Color(0xFF1B3F72);
  static const navyLight = Color(0xFF2E5FA3);
  static const teal      = Color(0xFF0077B6);
  static const bg        = Color(0xFFF2F5FB);
  static const card      = Color(0xFFFFFFFF);
  static const border    = Color(0xFFE4EAF4);
  static const success   = Color(0xFF0A7953);
  static const gold      = Color(0xFFB45309);
  static const textPrimary = Color(0xFF0F172A);
  static const textSub     = Color(0xFF64748B);
  static const textMuted   = Color(0xFF94A3B8);
}

/// Full-screen page that shows all department faculty members.
/// Open via [Navigator.push] — it is a self-contained route, not a bottom sheet.
class DepartmentFacultyScreen extends StatefulWidget {
  final List<dynamic> facultyList;
  final String departmentName;

  const DepartmentFacultyScreen({
    super.key,
    required this.facultyList,
    required this.departmentName,
  });

  @override
  State<DepartmentFacultyScreen> createState() =>
      _DepartmentFacultyScreenState();
}

class _DepartmentFacultyScreenState extends State<DepartmentFacultyScreen> {
  String _search = '';
  String _roleFilter = 'All';

  static const _roles = ['All', 'HOD', 'Faculty', 'Dean', 'Operator'];

  List<dynamic> get _filtered {
    return widget.facultyList.where((f) {
      final name  = (f['name']       ?? '').toString().toLowerCase();
      final fid   = (f['faculty_id'] ?? '').toString().toLowerCase();
      final role  = (f['role']       ?? '').toString().toLowerCase();
      final query = _search.toLowerCase();

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          fid.contains(query);

      final matchesRole = _roleFilter == 'All' ||
          role == _roleFilter.toLowerCase();

      return matchesSearch && matchesRole;
    }).toList();
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'hod':      return _C.navy;
      case 'dean':     return _C.teal;
      case 'operator': return _C.gold;
      default:         return _C.success;
    }
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'hod':      return 'HOD';
      case 'dean':     return 'Dean';
      case 'operator': return 'Operator';
      default:         return 'Faculty';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: _C.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ─────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _C.navy,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_C.navy, _C.navyMid, _C.navyLight],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.20)),
                              ),
                              child: const Icon(Icons.groups_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Department Faculty',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800)),
                                  Text(
                                    widget.departmentName,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.65),
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.20)),
                              ),
                              child: Text(
                                '${widget.facultyList.length} members',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Search + Filter ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: _C.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _C.border),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search by name or ID…',
                        hintStyle: const TextStyle(
                            color: _C.textMuted, fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: _C.textMuted, size: 20),
                        suffixIcon: _search.isNotEmpty
                            ? GestureDetector(
                          onTap: () => setState(() => _search = ''),
                          child: const Icon(Icons.close_rounded,
                              color: _C.textMuted, size: 18),
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Role filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _roles.map((role) {
                        final selected = _roleFilter == role;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _roleFilter = role),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? _C.navy : _C.card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? _C.navy
                                      : _C.border,
                                ),
                                boxShadow: selected
                                    ? [
                                  BoxShadow(
                                      color:
                                      _C.navy.withOpacity(0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3))
                                ]
                                    : [],
                              ),
                              child: Text(
                                role,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : _C.textSub,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Result count
                  Row(
                    children: [
                      Text(
                        'Showing ${filtered.length} of ${widget.facultyList.length}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: _C.textMuted,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Faculty list ─────────────────────────────────────────────────
          filtered.isEmpty
              ? SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: _C.textMuted.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.person_search_rounded,
                        color: _C.textMuted, size: 30),
                  ),
                  const SizedBox(height: 16),
                  const Text('No faculty found',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _C.textPrimary)),
                  const SizedBox(height: 6),
                  const Text('Try a different search or filter.',
                      style: TextStyle(
                          color: _C.textMuted, fontSize: 13)),
                ],
              ),
            ),
          )
              : SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                  final f = filtered[i];
                  final name  = (f['name']        ?? '').toString();
                  final fid   = (f['faculty_id']  ?? '').toString();
                  final role  = (f['role']        ?? 'faculty').toString();
                  final desg  = (f['designation'] ?? '').toString();
                  final qual  = (f['qualification'] ?? '').toString();
                  final email = (f['email']       ?? '').toString();

                  final rc = _roleColor(role);
                  final rl = _roleLabel(role);
                  final initials = _initials(name);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _C.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _C.border),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.045),
                            blurRadius: 14,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [
                                _C.navyMid.withOpacity(0.85),
                                _C.navyLight
                              ]),
                            ),
                            child: Center(
                              child: Text(initials,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                // Name + role badge
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(name,
                                          style: const TextStyle(
                                              fontWeight:
                                              FontWeight.w800,
                                              fontSize: 15,
                                              color: _C.textPrimary)),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4),
                                      decoration: BoxDecoration(
                                        color: rc.withOpacity(0.10),
                                        borderRadius:
                                        BorderRadius.circular(10),
                                        border: Border.all(
                                            color:
                                            rc.withOpacity(0.25)),
                                      ),
                                      child: Text(rl,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight:
                                              FontWeight.w700,
                                              color: rc)),
                                    ),
                                  ],
                                ),

                                if (fid.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  _infoRow(Icons.badge_rounded,
                                      fid, _C.navyLight),
                                ],
                                if (email.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  _infoRow(Icons.email_rounded,
                                      email, _C.teal),
                                ],
                                if (desg.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  _infoRow(Icons.work_rounded,
                                      desg, _C.gold),
                                ],
                                if (qual.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  _infoRow(Icons.school_rounded,
                                      qual, _C.success),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color.withOpacity(0.80)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 12,
                color: _C.textSub,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}