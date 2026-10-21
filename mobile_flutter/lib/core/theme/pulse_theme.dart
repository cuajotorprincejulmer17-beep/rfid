import 'package:flutter/material.dart';

import 'pulse_tokens.dart';

/// The type scale. Nothing is smaller than 12 sp.
abstract final class PulseType {
  static const TextStyle title = TextStyle(
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle label = TextStyle(
    fontSize: 14,
    height: 18 / 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );
}

/// The spacing scale (dp).
abstract final class PulseSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// The radius scale (dp).
abstract final class PulseRadius {
  static const double input = 12;
  static const double card = 16;
  static const double sheet = 24;
  static const double pill = 32;
}

/// The minimum interactive target (dp). Also the accessibility floor.
const double kMinTouch = 48;

/// Builds a full [ThemeData] for one palette.
ThemeData buildPulseTheme(PulseTokens t) {
  final base = t.isLight
      ? ThemeData.light(useMaterial3: true)
      : ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: t.background,
    canvasColor: t.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: t.primary,
      brightness: t.isLight ? Brightness.light : Brightness.dark,
    ).copyWith(
      primary: t.primary,
      onPrimary: t.onPrimary,
      surface: t.surface,
      onSurface: t.textPrimary,
      error: t.error,
      outline: t.border,
    ),
    textTheme: base.textTheme
        .apply(
          bodyColor: t.textPrimary,
          displayColor: t.textPrimary,
          fontFamily: 'Inter',
        )
        .copyWith(
          titleLarge: PulseType.title.copyWith(color: t.textPrimary),
          titleMedium: PulseType.heading.copyWith(color: t.textPrimary),
          bodyMedium: PulseType.body.copyWith(color: t.textPrimary),
          bodySmall: PulseType.caption.copyWith(color: t.textSecondary),
          labelLarge: PulseType.label.copyWith(color: t.textPrimary),
          labelMedium: PulseType.label.copyWith(color: t.textSecondary),
          labelSmall: PulseType.caption.copyWith(color: t.textSecondary),
        ),
    dividerColor: t.border,
    splashFactory: InkSparkle.splashFactory,
    extensions: <ThemeExtension<dynamic>>[t],
  );
}
