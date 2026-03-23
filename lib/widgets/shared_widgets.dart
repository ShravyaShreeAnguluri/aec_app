// lib/widgets/shared_widgets.dart
import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../theme/app_theme.dart';

// ── File type icon box ────────────────────────────────────────────────────────

class FileTypeBox extends StatelessWidget {
  final String type;
  final double size;
  const FileTypeBox({super.key, required this.type, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.forFileType(type);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      alignment: Alignment.center,
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.22,
          fontWeight: FontWeight.w900,
          color: c,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

// ── Pill chip ─────────────────────────────────────────────────────────────────

class PillChip extends StatelessWidget {
  final String text;
  final Color  color;
  const PillChip({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600, color: color,
      )),
    );
  }
}

// ── Document tile card ────────────────────────────────────────────────────────

class DocumentTile extends StatelessWidget {
  final DocumentModel doc;
  final VoidCallback  onTap;
  final VoidCallback  onDelete;
  final VoidCallback  onEdit;

  const DocumentTile({
    super.key,
    required this.doc,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.md,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.md,
          splashColor: AppColors.primarySoft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FileTypeBox(type: doc.fileType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        style: AppTextStyles.heading3.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        doc.subjectName,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary, fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        PillChip(text: doc.category, color: AppColors.primary),
                        const SizedBox(width: 6),
                        PillChip(text: doc.formattedSize, color: AppColors.textLight),
                        const SizedBox(width: 6),
                        PillChip(text: doc.shortDate, color: AppColors.textLight),
                      ]),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textLight),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
                  elevation: 3,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: _MenuRow(icon: Icons.edit_outlined, label: 'Edit')),
                    const PopupMenuItem(value: 'delete', child: _MenuRow(icon: Icons.delete_outline_rounded, label: 'Delete', isDestructive: true)),
                  ],
                  onSelected: (v) { if (v == 'edit') onEdit(); else onDelete(); },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     isDestructive;
  const _MenuRow({required this.icon, required this.label, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final c = isDestructive ? AppColors.error : AppColors.textDark;
    return Row(children: [
      Icon(icon, size: 18, color: c),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ── Year selector button ──────────────────────────────────────────────────────

class YearButton extends StatelessWidget {
  final int  year;
  final bool selected;
  final int  count;
  final VoidCallback onTap;

  const YearButton({
    super.key,
    required this.year,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.forYear(year);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? c : AppColors.white,
          borderRadius: AppRadius.sm,
          border: Border.all(color: selected ? c : AppColors.border, width: 1.5),
          boxShadow: selected
              ? [BoxShadow(color: c.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))]
              : [],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Y$year',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: selected ? Colors.white.withOpacity(0.85) : AppColors.textLight,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class EmptyPane extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyPane({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 60)),
          const SizedBox(height: 20),
          Text(title, style: AppTextStyles.heading2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTextStyles.body, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ]),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const SectionHeader({super.key, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      child: Row(children: [
        Text(label.toUpperCase(), style: AppTextStyles.label),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

// ── Custom app bar action button ──────────────────────────────────────────────

class NavIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const NavIconBtn({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadius.sm,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 18, color: AppColors.textDark),
      ),
    );
  }
}