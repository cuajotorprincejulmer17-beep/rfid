import 'package:flutter/material.dart';

/// The semantic colour tokens for the Pulse app.
///
/// Every widget reads colours through `context.pulse`. There are no hex
/// literals outside this directory (see `core/theme/`).
///
/// The three palettes are the ones named in the specification: Pulse Purple
/// Dark (the default), Mono and Light. The values come from the spec's
/// measured token table, where every text pair is at least 4.5:1 and every
/// control outline (`borderStrong`) is at least 3:1.
@immutable
class PulseTokens extends ThemeExtension<PulseTokens> {
  const PulseTokens({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.borderStrong,
    required this.primary,
    required this.onPrimary,
    required this.glow,
    required this.accentCyan,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.error,
    required this.navSelected,
    required this.navUnselected,
    required this.scrim,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color borderStrong;
  final Color primary;
  final Color onPrimary;
  final Color glow;
  final Color accentCyan;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color error;
  final Color navSelected;
  final Color navUnselected;
  final Color scrim;

  /// Pulse Purple Dark. The default look.
  static const PulseTokens dark = PulseTokens(
    background: Color(0xFF070B1C),
    surface: Color(0xFF0F1530),
    surfaceElevated: Color(0xFF171E42),
    border: Color(0xFF2B3566),
    borderStrong: Color(0xFF6672B8),
    primary: Color(0xFF7C3AED),
    onPrimary: Color(0xFFFFFFFF),
    glow: Color(0xFF8B5CF6),
    accentCyan: Color(0xFF22D3EE),
    textPrimary: Color(0xFFF1F3FF),
    textSecondary: Color(0xFFA9B2DB),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
    navSelected: Color(0xFFB79CFF),
    navUnselected: Color(0xFF8F99C7),
    scrim: Color(0xCC03050F),
  );

  /// Mono. Truly monochrome: hierarchy comes from contrast, type, elevation
  /// and shape, never from hue.
  static const PulseTokens mono = PulseTokens(
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF141414),
    surfaceElevated: Color(0xFF1F1F1F),
    border: Color(0xFF3A3A3A),
    borderStrong: Color(0xFF808080),
    primary: Color(0xFFF2F2F2),
    onPrimary: Color(0xFF0A0A0A),
    glow: Color(0xFFFFFFFF),
    accentCyan: Color(0xFFD4D4D4),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFB8B8B8),
    success: Color(0xFFE5E5E5),
    warning: Color(0xFFC8C8C8),
    error: Color(0xFFFFFFFF),
    navSelected: Color(0xFFFFFFFF),
    navUnselected: Color(0xFFA3A3A3),
    scrim: Color(0xCC000000),
  );

  /// Light.
  static const PulseTokens light = PulseTokens(
    background: Color(0xFFF6F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFD8DCEF),
    borderStrong: Color(0xFF7A82A6),
    primary: Color(0xFF6D28D9),
    onPrimary: Color(0xFFFFFFFF),
    glow: Color(0xFF7C3AED),
    accentCyan: Color(0xFF0E7490),
    textPrimary: Color(0xFF14172B),
    textSecondary: Color(0xFF525873),
    success: Color(0xFF047857),
    warning: Color(0xFF92400E),
    error: Color(0xFFB91C1C),
    navSelected: Color(0xFF6D28D9),
    navUnselected: Color(0xFF5B6180),
    scrim: Color(0x8014172B),
  );

  @override
  PulseTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? borderStrong,
    Color? primary,
    Color? onPrimary,
    Color? glow,
    Color? accentCyan,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? warning,
    Color? error,
    Color? navSelected,
    Color? navUnselected,
    Color? scrim,
  }) {
    return PulseTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      glow: glow ?? this.glow,
      accentCyan: accentCyan ?? this.accentCyan,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      navSelected: navSelected ?? this.navSelected,
      navUnselected: navUnselected ?? this.navUnselected,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  PulseTokens lerp(ThemeExtension<PulseTokens>? other, double t) {
    if (other is! PulseTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return PulseTokens(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceElevated: mix(surfaceElevated, other.surfaceElevated),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      glow: mix(glow, other.glow),
      accentCyan: mix(accentCyan, other.accentCyan),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      error: mix(error, other.error),
      navSelected: mix(navSelected, other.navSelected),
      navUnselected: mix(navUnselected, other.navUnselected),
      scrim: mix(scrim, other.scrim),
    );
  }

  /// The fill of a selected dock pill: `primary` at 22% alpha.
  Color get selectedPillFill => primary.withValues(alpha: 0.22);

  /// The outline of a selected dock pill: `primary` at 60% alpha.
  Color get selectedPillBorder => primary.withValues(alpha: 0.60);

  /// The soft fill used behind an icon, a chip or a hover surface.
  Color get softFill => primary.withValues(alpha: 0.12);

  /// The colour of a card that carries the single glow of its region.
  ///
  /// In Light the glow is a soft coloured tint; in the dark themes it is a
  /// translucent tint of the primary.
  Color get featuredFill => isLight
      ? Color.lerp(surface, primary, 0.10)!
      : Color.lerp(surface, primary, 0.16)!;

  /// Whether this palette is a light one.
  bool get isLight => background.computeLuminance() > 0.5;
}

/// The three named themes.
enum PulseThemeName { dark, mono, light }

extension PulseThemeNameX on PulseThemeName {
  /// The name shown in the Appearance page.
  String get label => switch (this) {
        PulseThemeName.dark => 'Pulse Purple Dark',
        PulseThemeName.mono => 'Mono',
        PulseThemeName.light => 'Light',
      };

  /// The short name used in golden file names.
  String get shortLabel => switch (this) {
        PulseThemeName.dark => 'Dark',
        PulseThemeName.mono => 'Mono',
        PulseThemeName.light => 'Light',
      };

  PulseTokens get tokens => switch (this) {
        PulseThemeName.dark => PulseTokens.dark,
        PulseThemeName.mono => PulseTokens.mono,
        PulseThemeName.light => PulseTokens.light,
      };
}

/// The three palettes.
abstract final class PulsePalettes {
  static PulseTokens of(PulseThemeName name) => name.tokens;
}

/// Convenience accessor: `context.pulse`.
///
/// Falls back to the dark palette when the extension is missing, so a widget
/// can be rendered in isolation (tests, previews) without a crash.
extension PulseThemeContext on BuildContext {
  PulseTokens get pulse =>
      Theme.of(this).extension<PulseTokens>() ?? PulseTokens.dark;
}
