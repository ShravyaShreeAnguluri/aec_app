import 'package:flutter/material.dart';

/// Aditya University Timetable – shared design tokens
/// Theme: deep navy + sky blue + white, matching the login page
class TimetableAppTheme {
  TimetableAppTheme._();

  // ── Primary palette ────────────────────────────────────────────
  static const Color primary = Color(0xFF1B3F7A);       // deep navy
  static const Color primaryLight = Color(0xFF2E5FBF);  // medium blue
  static const Color accent = Color(0xFF4A90D9);        // sky blue
  static const Color accentLight = Color(0xFFD6E8FA);   // pale blue tint
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFC62828);
  static const Color warning = Color(0xFFE65100);

  // ── Neutrals ───────────────────────────────────────────────────
  static const Color background = Color(0xFFF0F5FC);    // light blue-grey
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF7FAFF);
  static const Color border = Color(0xFFDDE6F4);
  static const Color textPrimary = Color(0xFF1A2B4A);
  static const Color textSecondary = Color(0xFF4A5E7A);
  static const Color textHint = Color(0xFF94A3B8);

  // ── Gradient (matches login page) ─────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B3F7A), Color(0xFF2E6BC4)],
  );

  // ── Shadows ────────────────────────────────────────────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 8)),
  ];

  // ── Radii ──────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;

  // ── AppBar ─────────────────────────────────────────────────────
  static AppBar buildAppBar(
      BuildContext context,
      String title, {
        List<Widget>? actions,
        Widget? leading,
        bool hasGradient = true,
      }) {
    return AppBar(
      backgroundColor: hasGradient ? Colors.transparent : primary,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: hasGradient
          ? Container(decoration: const BoxDecoration(gradient: primaryGradient))
          : null,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: 0.2,
        ),
      ),
      centerTitle: false,
      actions: actions,
      leading: leading,
    );
  }

  // ── Input decoration ───────────────────────────────────────────
  static InputDecoration inputDecoration(String label, {String? hint, Widget? prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: textHint, fontSize: 13),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: primaryLight, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: error),
      ),
    );
  }

  // ── Card container ────────────────────────────────────────────
  static Widget card({required Widget child, EdgeInsets? padding, Color? color}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(radiusLg),
        boxShadow: cardShadow,
        border: Border.all(color: border.withOpacity(0.5)),
      ),
      child: child,
    );
  }

  // ── Info banner ───────────────────────────────────────────────
  static Widget infoBanner(String text, {IconData icon = Icons.info_outline}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F1FC), Color(0xFFD6E8FA)],
        ),
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: accentLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: primaryLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────
  static Widget sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              gradient: primaryGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: textPrimary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Primary button ─────────────────────────────────────────────
  static Widget primaryButton({
    required String text,
    required VoidCallback? onPressed,
    bool loading = false,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: onPressed == null
                ? const LinearGradient(colors: [Color(0xFFBDCFE8), Color(0xFFBDCFE8)])
                : primaryGradient,
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          child: Container(
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Chip ───────────────────────────────────────────────────────
  static Widget infoChip(String label, dynamic value, {Color? bg, Color? fg}) {
    return Container(
      margin: const EdgeInsets.only(right: 7, bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        "$label: ${value ?? '-'}",
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
          color: fg ?? textSecondary,
        ),
      ),
    );
  }

  static Widget boolChip(String label, bool value) {
    return Container(
      margin: const EdgeInsets.only(right: 7, bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A),
        ),
      ),
      child: Text(
        "$label: ${value ? "Yes" : "No"}",
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: value ? success : error,
        ),
      ),
    );
  }
}