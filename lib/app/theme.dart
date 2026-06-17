import 'package:flutter/material.dart';

// ── Semantic color extension ──────────────────────────────────────────────────
// Use context.col.* everywhere in widgets — never hardcode palette values.
// To rebrand: update MogasColors constants + the two ThemeData objects below.
extension MogasColors2 on BuildContext {
  _MogasColorTokens get col => _MogasColorTokens(this);
}

class _MogasColorTokens {
  final BuildContext _ctx;
  const _MogasColorTokens(this._ctx);

  ColorScheme get _cs => Theme.of(_ctx).colorScheme;
  bool get _dark => Theme.of(_ctx).brightness == Brightness.dark;

  // Primary brand color
  Color get primary    => _cs.primary;
  Color get onPrimary  => _cs.onPrimary;

  // Accent — emerald green for money/refund values
  Color get gold    => _dark ? MogasColors.accentDark : MogasColors.accent;

  // Destructive / warning
  Color get crimson => _dark ? MogasColors.redDark : MogasColors.red;

  // Surfaces
  Color get surface     => _cs.surface;
  Color get cardSurface => Theme.of(_ctx).cardTheme.color ?? _cs.surfaceContainerHighest;

  // Subtle tinted container (tip boxes, info banners, eligibility notices)
  Color get subtleFill   => primary.withValues(alpha: _dark ? 0.15 : 0.08);
  Color get subtleBorder => primary.withValues(alpha: _dark ? 0.30 : 0.20);

  // Text hierarchy
  Color get onSurface  => _cs.onSurface;
  Color get labelText  => _cs.onSurface.withValues(alpha: 0.70);
  Color get mutedText  => _cs.onSurface.withValues(alpha: 0.50);

  // Divider / border
  Color get divider => Theme.of(_ctx).dividerColor;

  // Convenience alias — refund values always use accent
  Color get refundText => gold;
}

// ── Palette ───────────────────────────────────────────────────────────────────
//
//  Inspired by Swissborg — deep blue-black surfaces, single vivid green accent.
//
//  Light                            Dark
//  ──────────────────────────────   ────────────────────────────────
//  Scaffold  #EEF2F5  cool gray     Scaffold  #06141B  deep blue-black
//  Surface   #FFFFFF               Surface   #11212D  dark navy
//  Card      #FFFFFF               Card      #1C3347  slightly lighter
//  Primary   #0D9B6A  deep green   Primary   #10C980  vivid mint-emerald
//  Red       #DC2626               Red       #F87171
//
class MogasColors {
  MogasColors._();

  // ── Light mode ───────────────────────────────────────────────────────────
  static const Color accent        = Color(0xFF0D9B6A); // Emerald — deeper for light bg
  static const Color red           = Color(0xFFDC2626); // Red 600
  static const Color scaffoldLight = Color(0xFFEEF2F5); // Cool blue-gray off-white
  static const Color surfaceLight  = Color(0xFFFFFFFF);
  static const Color onLight       = Color(0xFF0D1B26); // Near-black with blue tint

  // In light mode the primary (app bar, buttons) uses the accent green
  // so the app feels cohesive — one colour does the work.
  static const Color primaryLight  = accent;

  // ── Dark mode ────────────────────────────────────────────────────────────
  static const Color scaffoldDark  = Color(0xFF06141B); // Deepest — Swissborg swatch 1
  static const Color surfaceDark   = Color(0xFF11212D); // Dark navy  — swatch 2
  static const Color cardDark      = Color(0xFF1C3347); // Slightly lighter — swatch 3
  static const Color accentDark    = Color(0xFF10C980); // Vivid mint-emerald
  static const Color redDark       = Color(0xFFF87171); // Red 400
  static const Color onDarkSurface = Color(0xFFE8F0F5); // Cool near-white
  static const Color onDarkMuted   = Color(0xFF4A6D84); // Mid blue-gray — swatch 4

  // Shared
  static const Color white  = surfaceLight;
  static const Color onDark = Color(0xFFFFFFFF);

  // ── Legacy aliases — keeps any stray direct references compiling ──────────
  static const Color navy           = Color(0xFF11212D);
  static const Color gold           = accent;
  static const Color amber          = accent;
  static const Color emerald        = accent;
  static const Color crimson        = red;
  static const Color surface        = scaffoldLight;
  static const Color primarySlate   = primaryLight;
  static const Color darkBackground = scaffoldDark;
  static const Color darkSurface    = surfaceDark;
  static const Color darkCard       = cardDark;
  static const Color darkNavy       = accentDark;
  static const Color darkGold       = accentDark;
  static const Color darkCrimson    = redDark;
  static const Color emeraldDark    = accentDark;
}

// ── Light theme ───────────────────────────────────────────────────────────────

final mogasTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: MogasColors.scaffoldLight,
  colorScheme: ColorScheme(
    brightness:   Brightness.light,
    primary:      MogasColors.primaryLight,
    onPrimary:    MogasColors.onDark,
    secondary:    MogasColors.accent,
    onSecondary:  MogasColors.onDark,
    tertiary:     MogasColors.red,
    onTertiary:   MogasColors.onDark,
    error:        MogasColors.red,
    onError:      MogasColors.onDark,
    surface:      MogasColors.surfaceLight,
    onSurface:    MogasColors.onLight,
    surfaceContainerHighest: Color(0xFFDDE4EA),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: MogasColors.onLight,
    foregroundColor: MogasColors.onDark,
    elevation: 0,
    centerTitle: false,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: MogasColors.primaryLight,
      foregroundColor: MogasColors.onDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: MogasColors.primaryLight,
      side: const BorderSide(color: MogasColors.primaryLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: MogasColors.primaryLight,
    foregroundColor: MogasColors.onDark,
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: MogasColors.primaryLight, width: 2),
    ),
    labelStyle: TextStyle(color: MogasColors.onLight.withValues(alpha: 0.7)),
  ),
  cardTheme: CardThemeData(
    elevation: 2,
    color: MogasColors.surfaceLight,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return MogasColors.primaryLight;
      return null;
    }),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: MogasColors.onLight,
    contentTextStyle: TextStyle(color: MogasColors.onDark),
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFFDDE4EA),
  ),
  textTheme: const TextTheme(
    headlineLarge:  TextStyle(color: MogasColors.onLight,      fontWeight: FontWeight.bold, fontSize: 28),
    headlineMedium: TextStyle(color: MogasColors.onLight,      fontWeight: FontWeight.bold, fontSize: 22),
    titleLarge:     TextStyle(color: MogasColors.onLight,      fontWeight: FontWeight.w600, fontSize: 18),
    bodyLarge:      TextStyle(color: MogasColors.onLight,      fontSize: 16),
    bodyMedium:     TextStyle(color: MogasColors.onLight,      fontSize: 14),
    labelLarge:     TextStyle(color: MogasColors.onDark,       fontWeight: FontWeight.w600, fontSize: 16),
  ),
);

// ── Dark theme ────────────────────────────────────────────────────────────────
// Deep blue-black surfaces; single vivid emerald accent à la Swissborg.

final mogasDarkTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: MogasColors.scaffoldDark,
  colorScheme: ColorScheme(
    brightness:   Brightness.dark,
    primary:      MogasColors.accentDark,
    onPrimary:    MogasColors.scaffoldDark,
    secondary:    MogasColors.accentDark,
    onSecondary:  MogasColors.scaffoldDark,
    tertiary:     MogasColors.redDark,
    onTertiary:   MogasColors.onDark,
    error:        MogasColors.redDark,
    onError:      MogasColors.onDark,
    surface:      MogasColors.surfaceDark,
    onSurface:    MogasColors.onDarkSurface,
    surfaceContainerHighest: MogasColors.cardDark,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: MogasColors.surfaceDark,
    foregroundColor: MogasColors.onDarkSurface,
    elevation: 0,
    centerTitle: false,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: MogasColors.accentDark,
      foregroundColor: MogasColors.scaffoldDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: MogasColors.accentDark,
      side: const BorderSide(color: MogasColors.accentDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: MogasColors.accentDark,
    foregroundColor: MogasColors.scaffoldDark,
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: MogasColors.cardDark),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: MogasColors.onDarkMuted.withValues(alpha: 0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: MogasColors.accentDark, width: 2),
    ),
    fillColor: MogasColors.cardDark,
    filled: true,
    labelStyle: const TextStyle(color: MogasColors.onDarkMuted),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: MogasColors.cardDark,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return MogasColors.accentDark;
      return null;
    }),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: MogasColors.cardDark,
    contentTextStyle: TextStyle(color: MogasColors.onDarkSurface),
  ),
  dividerTheme: const DividerThemeData(
    color: MogasColors.cardDark,
  ),
  textTheme: const TextTheme(
    headlineLarge:  TextStyle(color: MogasColors.onDarkSurface, fontWeight: FontWeight.bold, fontSize: 28),
    headlineMedium: TextStyle(color: MogasColors.onDarkSurface, fontWeight: FontWeight.bold, fontSize: 22),
    titleLarge:     TextStyle(color: MogasColors.onDarkSurface, fontWeight: FontWeight.w600, fontSize: 18),
    bodyLarge:      TextStyle(color: MogasColors.onDarkSurface, fontSize: 16),
    bodyMedium:     TextStyle(color: MogasColors.onDarkSurface, fontSize: 14),
    labelLarge:     TextStyle(color: MogasColors.scaffoldDark,  fontWeight: FontWeight.w600, fontSize: 16),
  ),
);
