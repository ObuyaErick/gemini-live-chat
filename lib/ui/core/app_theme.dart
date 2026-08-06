import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the Live Chat design system.
///
/// A theme-aware [ThemeExtension] carrying every semantic color, elevation and
/// diff token from the design. Access via `context.tokens`. Values re-resolve
/// automatically when the app switches between light and dark.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  // Surfaces
  final Color docBg; // page canvas behind the app frame
  final Color bgApp; // main conversation background
  final Color bg2; // sidebar / muted
  final Color bg3; // inset surface
  final Color surface; // cards, composer

  // Lines
  final Color border;
  final Color borderStrong;
  final Color scroll;

  // Text
  final Color text1;
  final Color text2;
  final Color text3;

  // Accent (violet)
  final Color accent;
  final Color accentHover;
  final Color accentSoft;
  final Color accentBorder;
  final Color onAccent;

  // User bubble
  final Color userBg;
  final Color userBorder;

  // Status
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  // Diff
  final Color diffAdd;
  final Color diffAddLine;
  final Color diffDel;
  final Color diffDelLine;

  // Elevation
  final List<BoxShadow> e1;
  final List<BoxShadow> e2;
  final List<BoxShadow> e3;

  const AppTokens({
    required this.docBg,
    required this.bgApp,
    required this.bg2,
    required this.bg3,
    required this.surface,
    required this.border,
    required this.borderStrong,
    required this.scroll,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    required this.accentBorder,
    required this.onAccent,
    required this.userBg,
    required this.userBorder,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.diffAdd,
    required this.diffAddLine,
    required this.diffDel,
    required this.diffDelLine,
    required this.e1,
    required this.e2,
    required this.e3,
  });

  /// The signature avatar / brand gradient.
  LinearGradient get accentGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, const Color(0xFFC9B6FF)],
  );

  static const AppTokens light = AppTokens(
    docBg: Color(0xFFE6E6EC),
    bgApp: Color(0xFFFFFFFF),
    bg2: Color(0xFFF7F7FA),
    bg3: Color(0xFFEEEEF3),
    surface: Color(0xFFFFFFFF),
    border: Color(0x14161628), // rgba(22,22,42,.08)
    borderStrong: Color(0x26161628), // .15
    scroll: Color(0x2E161628),
    text1: Color(0xFF191922),
    text2: Color(0xFF585866),
    text3: Color(0xFF8C8C9A),
    accent: Color(0xFF7C5CFF),
    accentHover: Color(0xFF6B48FF),
    accentSoft: Color(0x1A7C5CFF), // .10
    accentBorder: Color(0x4D7C5CFF), // .30
    onAccent: Color(0xFFFFFFFF),
    userBg: Color(0xFFF1EFFE),
    userBorder: Color(0x297C5CFF), // .16
    success: Color(0xFF199A56),
    successSoft: Color(0x1F199A56),
    warning: Color(0xFFB7830B),
    warningSoft: Color(0x1FB7830B),
    danger: Color(0xFFD13D3D),
    dangerSoft: Color(0x1AD13D3D),
    diffAdd: Color(0x21199A56),
    diffAddLine: Color(0xFF199A56),
    diffDel: Color(0x1CD13D3D),
    diffDelLine: Color(0xFFD13D3D),
    e1: [
      BoxShadow(color: Color(0x0F161628), blurRadius: 2, offset: Offset(0, 1)),
    ],
    e2: [
      BoxShadow(color: Color(0x17161628), blurRadius: 18, offset: Offset(0, 4)),
    ],
    e3: [
      BoxShadow(
        color: Color(0x29161628),
        blurRadius: 48,
        offset: Offset(0, 16),
      ),
    ],
  );

  static const AppTokens dark = AppTokens(
    docBg: Color(0xFF050507),
    bgApp: Color(0xFF0F0F14),
    bg2: Color(0xFF0A0A0E),
    bg3: Color(0xFF17171E),
    surface: Color(0xFF16161E),
    border: Color(0x14FFFFFF), // rgba(255,255,255,.08)
    borderStrong: Color(0x29FFFFFF), // .16
    scroll: Color(0x24FFFFFF),
    text1: Color(0xFFECECF2),
    text2: Color(0xFFA1A1B0),
    text3: Color(0xFF6C6C7C),
    accent: Color(0xFF8F74FF),
    accentHover: Color(0xFFA58FFF),
    accentSoft: Color(0x298F74FF), // .16
    accentBorder: Color(0x5C8F74FF), // .36
    onAccent: Color(0xFF0B0910),
    userBg: Color(0x268F74FF), // .15
    userBorder: Color(0x428F74FF), // .26
    success: Color(0xFF39C583),
    successSoft: Color(0x2639C583),
    warning: Color(0xFFE0A63A),
    warningSoft: Color(0x24E0A63A),
    danger: Color(0xFFEF6A6A),
    dangerSoft: Color(0x21EF6A6A),
    diffAdd: Color(0x2639C583),
    diffAddLine: Color(0xFF39C583),
    diffDel: Color(0x24EF6A6A),
    diffDelLine: Color(0xFFEF6A6A),
    e1: [
      BoxShadow(color: Color(0x80000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
    e2: [
      BoxShadow(color: Color(0x8C000000), blurRadius: 28, offset: Offset(0, 8)),
    ],
    e3: [
      BoxShadow(
        color: Color(0xB3000000),
        blurRadius: 64,
        offset: Offset(0, 24),
      ),
    ],
  );

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<BoxShadow> s(List<BoxShadow> a, List<BoxShadow> b) =>
        BoxShadow.lerpList(a, b, t) ?? b;
    return AppTokens(
      docBg: c(docBg, other.docBg),
      bgApp: c(bgApp, other.bgApp),
      bg2: c(bg2, other.bg2),
      bg3: c(bg3, other.bg3),
      surface: c(surface, other.surface),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      scroll: c(scroll, other.scroll),
      text1: c(text1, other.text1),
      text2: c(text2, other.text2),
      text3: c(text3, other.text3),
      accent: c(accent, other.accent),
      accentHover: c(accentHover, other.accentHover),
      accentSoft: c(accentSoft, other.accentSoft),
      accentBorder: c(accentBorder, other.accentBorder),
      onAccent: c(onAccent, other.onAccent),
      userBg: c(userBg, other.userBg),
      userBorder: c(userBorder, other.userBorder),
      success: c(success, other.success),
      successSoft: c(successSoft, other.successSoft),
      warning: c(warning, other.warning),
      warningSoft: c(warningSoft, other.warningSoft),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      diffAdd: c(diffAdd, other.diffAdd),
      diffAddLine: c(diffAddLine, other.diffAddLine),
      diffDel: c(diffDel, other.diffDel),
      diffDelLine: c(diffDelLine, other.diffDelLine),
      e1: s(e1, other.e1),
      e2: s(e2, other.e2),
      e3: s(e3, other.e3),
    );
  }
}

/// Convenience accessor: `context.tokens`.
extension AppTokensX on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
}

/// Builds the app-wide [ThemeData] for a given token set / brightness.
class AppTheme {
  static const _radius = 12.0;

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    final textTheme = GoogleFonts.soraTextTheme(
      base.textTheme,
    ).apply(bodyColor: t.text1, displayColor: t.text1);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: t.accent,
          brightness: brightness,
        ).copyWith(
          primary: t.accent,
          onPrimary: t.onAccent,
          surface: t.bgApp,
          onSurface: t.text1,
          onSurfaceVariant: t.text2,
          outline: t.borderStrong,
          outlineVariant: t.border,
          error: t.danger,
        );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: t.bgApp,
      canvasColor: t.bgApp,
      dividerColor: t.border,
      textTheme: textTheme,
      extensions: [t],
      splashFactory: InkSparkle.splashFactory,
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: t.border),
          boxShadow: t.e2,
        ),
        textStyle: GoogleFonts.sora(fontSize: 12, color: t.text1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.text1,
        contentTextStyle: GoogleFonts.sora(fontSize: 13, color: t.bgApp),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      splashColor: t.accentSoft,
      highlightColor: t.accentSoft,
    );
  }

  static ThemeData light() => _build(AppTokens.light, Brightness.light);
  static ThemeData dark() => _build(AppTokens.dark, Brightness.dark);

  /// Radius shorthand shared across components.
  static const double radiusSm = 8;
  static const double radiusMd = _radius;
  static const double radiusLg = 16;

  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );
}
