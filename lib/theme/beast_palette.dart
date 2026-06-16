import 'package:flutter/material.dart';

class BeastPalette {
  const BeastPalette._({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.surfaceStart,
    required this.surfaceMid,
    required this.surfaceEnd,
    required this.surfaceCard,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
  });

  static const lightPrimary = Color(0xFF0057D8);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFD8E6FF);
  static const lightOnPrimaryContainer = Color(0xFF0E2D63);
  static const lightSecondary = Color(0xFF0B57D0);
  static const lightOnSecondary = Color(0xFFFFFFFF);
  static const lightSurfaceStart = Color(0xFFF6FAFF);
  static const lightSurfaceMid = Color(0xFFEDF4FF);
  static const lightSurfaceEnd = Color(0xFFE8F1FF);
  static const lightSurfaceCard = Color(0xFFFDFEFF);
  static const lightOnSurface = Color(0xFF0F172A);
  static const lightOnSurfaceVariant = Color(0xFF334155);
  static const lightOutline = Color(0xFFAFC2DE);

  static const darkPrimary = Color(0xFF8AB4F8);
  static const darkOnPrimary = Color(0xFF06214A);
  static const darkPrimaryContainer = Color(0xFF1E3A66);
  static const darkOnPrimaryContainer = Color(0xFFD9E8FF);
  static const darkSecondary = Color(0xFF90CAF9);
  static const darkOnSecondary = Color(0xFF06233F);
  static const darkSurfaceStart = Color(0xFF0D1624);
  static const darkSurfaceMid = Color(0xFF101B2B);
  static const darkSurfaceEnd = Color(0xFF122034);
  static const darkSurfaceCard = Color(0xFF172338);
  static const darkOnSurface = Color(0xFFE7EEF9);
  static const darkOnSurfaceVariant = Color(0xFFB7C5DB);
  static const darkOutline = Color(0xFF3D5678);

  static const light = BeastPalette._(
    primary: lightPrimary,
    onPrimary: lightOnPrimary,
    primaryContainer: lightPrimaryContainer,
    onPrimaryContainer: lightOnPrimaryContainer,
    secondary: lightSecondary,
    onSecondary: lightOnSecondary,
    surfaceStart: lightSurfaceStart,
    surfaceMid: lightSurfaceMid,
    surfaceEnd: lightSurfaceEnd,
    surfaceCard: lightSurfaceCard,
    onSurface: lightOnSurface,
    onSurfaceVariant: lightOnSurfaceVariant,
    outline: lightOutline,
  );

  static const dark = BeastPalette._(
    primary: darkPrimary,
    onPrimary: darkOnPrimary,
    primaryContainer: darkPrimaryContainer,
    onPrimaryContainer: darkOnPrimaryContainer,
    secondary: darkSecondary,
    onSecondary: darkOnSecondary,
    surfaceStart: darkSurfaceStart,
    surfaceMid: darkSurfaceMid,
    surfaceEnd: darkSurfaceEnd,
    surfaceCard: darkSurfaceCard,
    onSurface: darkOnSurface,
    onSurfaceVariant: darkOnSurfaceVariant,
    outline: darkOutline,
  );

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color surfaceStart;
  final Color surfaceMid;
  final Color surfaceEnd;
  final Color surfaceCard;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;

  static BeastPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  LinearGradient get mainGradient => LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [surfaceStart, surfaceMid, surfaceEnd],
  );
}
