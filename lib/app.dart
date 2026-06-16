import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/locator_screen.dart';
import 'theme/beast_palette.dart';

class BeastLocatorApp extends StatelessWidget {
  const BeastLocatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeastLocator',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja'), Locale('en'), Locale('zh', 'CN')],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: BeastPalette.lightPrimary,
          onPrimary: BeastPalette.lightOnPrimary,
          primaryContainer: BeastPalette.lightPrimaryContainer,
          onPrimaryContainer: BeastPalette.lightOnPrimaryContainer,
          secondary: BeastPalette.lightSecondary,
          onSecondary: BeastPalette.lightOnSecondary,
          surface: BeastPalette.lightSurfaceStart,
          onSurface: BeastPalette.lightOnSurface,
          outline: BeastPalette.lightOutline,
        ),
        scaffoldBackgroundColor: BeastPalette.lightSurfaceStart,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: BeastPalette.darkPrimary,
          onPrimary: BeastPalette.darkOnPrimary,
          primaryContainer: BeastPalette.darkPrimaryContainer,
          onPrimaryContainer: BeastPalette.darkOnPrimaryContainer,
          secondary: BeastPalette.darkSecondary,
          onSecondary: BeastPalette.darkOnSecondary,
          surface: BeastPalette.darkSurfaceStart,
          onSurface: BeastPalette.darkOnSurface,
          outline: BeastPalette.darkOutline,
        ),
        scaffoldBackgroundColor: BeastPalette.darkSurfaceStart,
      ),
      home: const LocatorScreen(),
    );
  }
}
