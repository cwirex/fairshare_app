// lib/shared/theme/app_theme.dart
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_theme.g.dart';

/// The [AppTheme] defines light and dark themes for the FairShare app.
///
/// Uses FlexColorScheme v8 with indigoM3 color scheme for modern Material 3 design.
@riverpod
class AppTheme extends _$AppTheme {
  @override
  ThemeData build() {
    // Return light theme by default
    return light;
  }

  // The FlexColorScheme defined light mode ThemeData
  static ThemeData light = FlexThemeData.light(
    // Using FlexColorScheme built-in FlexScheme enum based colors
    scheme: FlexScheme.indigoM3,
    // Component theme configurations for light mode
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      useM2StyleDividerInM3: true,
      inputDecoratorIsFilled: true,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      alignedDropdown: true,
      navigationRailUseIndicator: true,
    ),
    // Direct ThemeData properties
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );

  // The FlexColorScheme defined dark mode ThemeData
  static ThemeData dark = FlexThemeData.dark(
    // Using FlexColorScheme built-in FlexScheme enum based colors
    scheme: FlexScheme.indigoM3,
    // Component theme configurations for dark mode
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      blendOnColors: true,
      useM2StyleDividerInM3: true,
      inputDecoratorIsFilled: true,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      alignedDropdown: true,
      navigationRailUseIndicator: true,
    ),
    // Direct ThemeData properties
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );

  // Method to switch to dark theme
  void setDarkMode() {
    state = dark;
  }

  // Method to switch to light theme
  void setLightMode() {
    state = light;
  }

  // Method to toggle between themes
  void toggleTheme() {
    state = state.brightness == Brightness.light ? dark : light;
  }
}
