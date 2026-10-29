import 'package:flutter/material.dart';

class LauncherThemePreset {
  const LauncherThemePreset({
    required this.id,
    required this.name,
    required this.backgroundColor,
    required this.textColor,
  });

  final String id;
  final String name;
  final Color backgroundColor;
  final Color textColor;

  static const presets = <LauncherThemePreset>[
    LauncherThemePreset(
      id: 'light',
      name: 'Light',
      backgroundColor: Color(0xFFE4E4E4),
      textColor: Color(0xFF383838),
    ),
    LauncherThemePreset(
      id: 'dark',
      name: 'Dark',
      backgroundColor: Color(0xFF202124),
      textColor: Color(0xFFF1F3F4),
    ),
    LauncherThemePreset(
      id: 'amoled',
      name: 'AMOLED',
      backgroundColor: Colors.black,
      textColor: Colors.white,
    ),
    LauncherThemePreset(
      id: 'custom',
      name: 'Custom',
      backgroundColor: Color(0xFFE4E4E4),
      textColor: Color(0xFF383838),
    ),
  ];

  static LauncherThemePreset byId(String? id) => presets.firstWhere(
        (preset) => preset.id == id,
        orElse: () => presets.first,
      );

  LauncherThemePreset copyWith({
    Color? backgroundColor,
    Color? textColor,
  }) =>
      LauncherThemePreset(
        id: id,
        name: name,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        textColor: textColor ?? this.textColor,
      );
}
