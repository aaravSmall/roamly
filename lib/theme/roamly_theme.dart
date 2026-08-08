import 'package:flutter/material.dart';

/// Roamly brand palette.
abstract final class RoamlyPalette {
  static const Color deepSlate = Color(0xFF2F323A);
  static const Color softSand = Color(0xFFECE0D7);
  static const Color mutedTeal = Color(0xFF3B5D5B);
  static const Color skyBlue = Color(0xFF4DA8DA);
  static const Color warmOrange = Color(0xFFF4A261);
  static const Color lightGray = Color(0xFFD9D9D9);
}

@immutable
class RoamlyExtraColors extends ThemeExtension<RoamlyExtraColors> {
  const RoamlyExtraColors({
    required this.travelHighlight,
    required this.visitedMarker,
    required this.secondaryUi,
  });

  final Color travelHighlight;
  final Color visitedMarker;
  final Color secondaryUi;

  @override
  RoamlyExtraColors copyWith({
    Color? travelHighlight,
    Color? visitedMarker,
    Color? secondaryUi,
  }) {
    return RoamlyExtraColors(
      travelHighlight: travelHighlight ?? this.travelHighlight,
      visitedMarker: visitedMarker ?? this.visitedMarker,
      secondaryUi: secondaryUi ?? this.secondaryUi,
    );
  }

  @override
  RoamlyExtraColors lerp(ThemeExtension<RoamlyExtraColors>? other, double t) {
    if (other is! RoamlyExtraColors) return this;
    return RoamlyExtraColors(
      travelHighlight:
          Color.lerp(travelHighlight, other.travelHighlight, t)!,
      visitedMarker: Color.lerp(visitedMarker, other.visitedMarker, t)!,
      secondaryUi: Color.lerp(secondaryUi, other.secondaryUi, t)!,
    );
  }
}

extension RoamlyExtraColorsX on BuildContext {
  RoamlyExtraColors get roamlyExtra {
    return Theme.of(this).extension<RoamlyExtraColors>() ??
        const RoamlyExtraColors(
          travelHighlight: RoamlyPalette.skyBlue,
          visitedMarker: RoamlyPalette.warmOrange,
          secondaryUi: RoamlyPalette.lightGray,
        );
  }
}

ThemeData buildRoamlyTheme() {
  final colorScheme = ColorScheme.light(
    primary: RoamlyPalette.deepSlate,
    onPrimary: RoamlyPalette.softSand,
    primaryContainer: RoamlyPalette.lightGray,
    onPrimaryContainer: RoamlyPalette.deepSlate,
    secondary: RoamlyPalette.mutedTeal,
    onSecondary: RoamlyPalette.softSand,
    secondaryContainer:
        Color.lerp(RoamlyPalette.mutedTeal, RoamlyPalette.softSand, 0.85)!,
    onSecondaryContainer: RoamlyPalette.deepSlate,
    tertiary: RoamlyPalette.skyBlue,
    onTertiary: RoamlyPalette.deepSlate,
    tertiaryContainer:
        Color.lerp(RoamlyPalette.skyBlue, RoamlyPalette.softSand, 0.75)!,
    onTertiaryContainer: RoamlyPalette.deepSlate,
    surface: RoamlyPalette.softSand,
    onSurface: RoamlyPalette.deepSlate,
    surfaceContainerHighest: RoamlyPalette.lightGray,
    onSurfaceVariant: RoamlyPalette.mutedTeal,
    outline: Color.lerp(RoamlyPalette.mutedTeal, RoamlyPalette.lightGray, 0.5)!,
    outlineVariant: RoamlyPalette.lightGray,
    error: const Color(0xFFB3261E),
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: RoamlyPalette.softSand,
    appBarTheme: const AppBarTheme(
      backgroundColor: RoamlyPalette.deepSlate,
      foregroundColor: RoamlyPalette.softSand,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: RoamlyPalette.softSand),
      titleTextStyle: TextStyle(
        color: RoamlyPalette.softSand,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RoamlyPalette.mutedTeal,
        foregroundColor: RoamlyPalette.softSand,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: RoamlyPalette.mutedTeal,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: RoamlyPalette.skyBlue,
      linearTrackColor: RoamlyPalette.lightGray,
    ),
    cardTheme: CardThemeData(
      color: Color.lerp(RoamlyPalette.softSand, Colors.white, 0.4),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: RoamlyPalette.lightGray),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: RoamlyPalette.deepSlate,
      contentTextStyle: TextStyle(color: RoamlyPalette.softSand),
      actionTextColor: RoamlyPalette.skyBlue,
      behavior: SnackBarBehavior.floating,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: RoamlyPalette.mutedTeal,
      collapsedIconColor: RoamlyPalette.mutedTeal,
      textColor: RoamlyPalette.deepSlate,
      collapsedTextColor: RoamlyPalette.deepSlate,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: RoamlyPalette.mutedTeal,
    ),
    extensions: const [
      RoamlyExtraColors(
        travelHighlight: RoamlyPalette.skyBlue,
        visitedMarker: RoamlyPalette.warmOrange,
        secondaryUi: RoamlyPalette.lightGray,
      ),
    ],
  );
}
