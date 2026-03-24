import 'package:faculty_app/screens/operator/timetable/timetableapp_theme.dart';
import 'package:flutter/material.dart';
import '../../services/token_service.dart';

import 'rooms/create_room_screen.dart';
import 'rooms/view_rooms_screen.dart';
import 'sections/create_section_screen.dart';
import 'sections/view_sections_screen.dart';
import 'subjects/create_subject_screen.dart';
import 'subjects/view_subjects_screen.dart';
import 'mappings/create_mapping_screen.dart';
import 'mappings/view_mappings_screen.dart';
import 'timetable/generate_timetable_screen.dart';
import 'timetable/view_faculty_timetable_screen.dart';
import 'timetable/view_section_timetable_screen.dart';

class OperatorDashboardScreen extends StatelessWidget {
  final String name;
  final String department;
  final String token;

  const OperatorDashboardScreen({
    super.key,
    required this.name,
    required this.department,
    required this.token,
  });

  void open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> logout(BuildContext context) async {
    await TokenService.clearToken();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil("/login", (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final groups = [
      _DashboardGroup(
        title: "Rooms & Labs",
        icon: Icons.meeting_room_outlined,
        color: const Color(0xFF1565C0),
        items: [
          _DashboardItem("Create Room", Icons.add_circle_outline, CreateRoomScreen(token: token)),
          _DashboardItem("View Rooms", Icons.domain_outlined, ViewRoomsScreen(token: token)),
        ],
      ),
      _DashboardGroup(
        title: "Sections",
        icon: Icons.class_outlined,
        color: const Color(0xFF00695C),
        items: [
          _DashboardItem("Create Section", Icons.add_circle_outline, CreateSectionScreen(token: token)),
          _DashboardItem("View Sections", Icons.view_list_outlined, ViewSectionsScreen(token: token)),
        ],
      ),
      _DashboardGroup(
        title: "Subjects",
        icon: Icons.menu_book_outlined,
        color: const Color(0xFF6A1B9A),
        items: [
          _DashboardItem("Create Subject", Icons.add_circle_outline, CreateSubjectScreen(token: token)),
          _DashboardItem("View Subjects", Icons.library_books_outlined, ViewSubjectsScreen(token: token)),
        ],
      ),
      _DashboardGroup(
        title: "Faculty Mappings",
        icon: Icons.people_alt_outlined,
        color: const Color(0xFFBF360C),
        items: [
          _DashboardItem("Create Mapping", Icons.link_outlined, CreateFacultyMappingScreen(token: token)),
          _DashboardItem("View Mappings", Icons.account_tree_outlined, ViewMappingsScreen(token: token)),
        ],
      ),
      _DashboardGroup(
        title: "Timetable",
        icon: Icons.calendar_month_outlined,
        color: TimetableAppTheme.primary,
        items: [
          _DashboardItem("Generate Timetable", Icons.auto_awesome_outlined, GenerateTimetableScreen(token: token)),
          _DashboardItem("Section Timetable", Icons.grid_view_rounded, ViewSectionTimetableScreen(token: token)),
          _DashboardItem("Faculty Timetable", Icons.badge_outlined, ViewFacultyTimetableScreen(token: token)),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: TimetableAppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            collapsedHeight: 60,
            pinned: true,
            backgroundColor: TimetableAppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: TimetableAppTheme.primaryGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white30),
                              ),
                              child: const Icon(Icons.person_outline, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Welcome, $name",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.domain_outlined, size: 13, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      Text(
                                        department,
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title: const Text(
                "Operator Dashboard",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
              ),
              titlePadding: const EdgeInsets.only(left: 60, bottom: 14),
            ),
            actions: [
              IconButton(
                tooltip: "Logout",
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: () => logout(context),
              ),
            ],
          ),

          // ── Content ───────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final group = groups[index];
                  return _GroupCard(
                    group: group,
                    onTap: (screen) => open(context, screen),
                  );
                },
                childCount: groups.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final IconData icon;
  final Widget screen;
  const _DashboardItem(this.title, this.icon, this.screen);
}

class _DashboardGroup {
  final String title;
  final IconData icon;
  final Color color;
  final List<_DashboardItem> items;
  const _DashboardGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class _GroupCard extends StatelessWidget {
  final _DashboardGroup group;
  final void Function(Widget screen) onTap;

  const _GroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TimetableAppTheme.radiusLg),
        boxShadow: TimetableAppTheme.cardShadow,
        border: Border.all(color: TimetableAppTheme.border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: group.color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(TimetableAppTheme.radiusLg)),
              border: Border(bottom: BorderSide(color: group.color.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: group.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(group.icon, color: group.color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  group.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: group.color,
                  ),
                ),
              ],
            ),
          ),
          // Items
          ...group.items.map(
                (item) => _ItemTile(item: item, color: group.color, onTap: onTap),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final _DashboardItem item;
  final Color color;
  final void Function(Widget screen) onTap;

  const _ItemTile({required this.item, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(item.screen),
      borderRadius: BorderRadius.circular(TimetableAppTheme.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(item.icon, color: color.withOpacity(0.8), size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: TimetableAppTheme.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }
}