import 'package:flutter/material.dart';

/// App-wide light/dark mode controller. Kept intentionally simple — a single
/// [ValueNotifier] the [MaterialApp] listens to and any widget can flip.
class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool isDark(BuildContext context) {
    final m = mode.value;
    if (m == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return m == ThemeMode.dark;
  }

  static void toggle(BuildContext context) {
    mode.value = isDark(context) ? ThemeMode.light : ThemeMode.dark;
  }
}
