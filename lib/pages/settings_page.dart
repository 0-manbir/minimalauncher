import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:minimalauncher/variables/launcher_theme.dart';
import 'package:minimalauncher/variables/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool showWallpaper = false;
  bool is24HourFormat = false;
  bool showRecentApps = true;
  int appDrawerColumns = 4;
  LauncherThemePreset selectedTheme = LauncherThemePreset.presets.first;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final storedTheme = prefs.getString(prefsLauncherTheme);
    final legacyBackground = prefs.getInt(prefsSelectedColor);
    final legacyText = prefs.getInt(prefsTextColor);
    final theme = storedTheme == null
        ? LauncherThemePreset.presets.firstWhere(
            (preset) =>
                preset.backgroundColor.toARGB32() == legacyBackground &&
                preset.textColor.toARGB32() == legacyText,
            orElse: () => LauncherThemePreset.presets.first,
          )
        : LauncherThemePreset.byId(storedTheme);
    final selectedTheme = theme.id == 'custom'
        ? theme.copyWith(
            backgroundColor: Color(
              legacyBackground ?? theme.backgroundColor.toARGB32(),
            ),
            textColor: Color(
              legacyText ?? theme.textColor.toARGB32(),
            ),
          )
        : theme;

    setState(() {
      showWallpaper = prefs.getBool(prefsShowWallpaper) ?? false;
      is24HourFormat = prefs.getBool(prefsIs24HourFormat) ?? false;
      showRecentApps = prefs.getBool(prefsShowRecentApps) ?? true;
      appDrawerColumns = prefs.getInt(prefsAppDrawerColumns) ?? 4;
      this.selectedTheme = selectedTheme;
    });
    if (storedTheme == null) {
      await prefs.setString(prefsLauncherTheme, selectedTheme.id);
      await prefs.setInt(
        prefsSelectedColor,
        selectedTheme.backgroundColor.toARGB32(),
      );
      await prefs.setInt(prefsTextColor, selectedTheme.textColor.toARGB32());
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsLauncherTheme, selectedTheme.id);
    await prefs.setBool(prefsShowWallpaper, showWallpaper);
    await prefs.setBool(prefsIs24HourFormat, is24HourFormat);
    await prefs.setBool(prefsShowRecentApps, showRecentApps);
    await prefs.setInt(prefsAppDrawerColumns, appDrawerColumns);
    await prefs.setInt(
      prefsSelectedColor,
      selectedTheme.backgroundColor.toARGB32(),
    );
    await prefs.setInt(prefsTextColor, selectedTheme.textColor.toARGB32());
  }

  Future<void> _selectTheme(LauncherThemePreset theme) async {
    setState(() {
      selectedTheme = theme.id == 'custom'
          ? theme.copyWith(
              backgroundColor: selectedTheme.backgroundColor,
              textColor: selectedTheme.textColor,
            )
          : theme;
    });
    await _savePreferences();
  }

  Future<void> _pickCustomColor({required bool background}) async {
    var pickedColor = background
        ? selectedTheme.backgroundColor
        : selectedTheme.textColor;
    final updatedColor = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(background ? 'Background color' : 'Text color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickedColor,
            onColorChanged: (color) => pickedColor = color,
            enableAlpha: false,
            displayThumbColor: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, pickedColor),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (updatedColor == null || !mounted) return;
    setState(() {
      selectedTheme = selectedTheme.copyWith(
        backgroundColor: background ? updatedColor : null,
        textColor: background ? null : updatedColor,
      );
    });
    await _savePreferences();
  }

  Future<void> _setWallpaper(bool value) async {
    setState(() {
      showWallpaper = value;
    });
    await _savePreferences();
  }

  Future<void> _set24HourFormat(bool value) async {
    setState(() {
      is24HourFormat = value;
    });
    await _savePreferences();
  }

  Future<void> _setShowRecentApps(bool value) async {
    setState(() {
      showRecentApps = value;
    });
    await _savePreferences();
  }

  Future<void> _setAppDrawerColumns(int value) async {
    setState(() {
      appDrawerColumns = value;
    });
    await _savePreferences();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        showWallpaper ? Colors.transparent : selectedTheme.backgroundColor;
    final textColor = selectedTheme.textColor;
    final sectionColor = Color.alphaBlend(
      textColor.withAlpha(13),
      selectedTheme.backgroundColor,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(color: textColor, fontFamily: fontNormal),
        ),
        foregroundColor: textColor,
        backgroundColor: backgroundColor,
        systemOverlayStyle: SystemUiOverlayStyle(
          systemNavigationBarColor: backgroundColor,
          systemNavigationBarIconBrightness:
              ThemeData.estimateBrightnessForColor(textColor),
          systemNavigationBarContrastEnforced: false,
          statusBarColor: backgroundColor,
          statusBarIconBrightness:
              ThemeData.estimateBrightnessForColor(textColor),
          systemStatusBarContrastEnforced: false,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Appearance', textColor),
          Card(
            color: showWallpaper ? textColor.withAlpha(20) : sectionColor,
            child: Column(
              children: [
                RadioGroup<String>(
                  groupValue: selectedTheme.id,
                  onChanged: (value) {
                    if (value != null) {
                      _selectTheme(LauncherThemePreset.byId(value));
                    }
                  },
                  child: Column(
                    children: [
                      for (final theme in LauncherThemePreset.presets)
                        RadioListTile<String>(
                          value: theme.id,
                          title: Text(
                            theme.name,
                            style: TextStyle(
                              color: textColor,
                              fontFamily: fontNormal,
                            ),
                          ),
                          secondary: CircleAvatar(
                            backgroundColor: theme.id == 'custom'
                                ? selectedTheme.backgroundColor
                                : theme.backgroundColor,
                            child: Icon(
                              Icons.palette_outlined,
                              color: theme.id == 'custom'
                                  ? selectedTheme.textColor
                                  : theme.textColor,
                            ),
                          ),
                          if (selectedTheme.id == 'custom') ...[
                            const Divider(height: 1),
                            ListTile(
                              title: Text(
                                'Background color',
                                style:
                                    TextStyle(color: textColor, fontFamily: fontNormal),
                              ),
                              trailing: _colorPreview(selectedTheme.backgroundColor),
                              onTap: () => _pickCustomColor(background: true),
                            ),
                            ListTile(
                              title: Text(
                                'Text color',
                                style:
                                    TextStyle(color: textColor, fontFamily: fontNormal),
                              ),
                              trailing: _colorPreview(selectedTheme.textColor),
                              onTap: () => _pickCustomColor(background: false),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(
                    'Show wallpaper',
                    style: TextStyle(color: textColor, fontFamily: fontNormal),
                  ),
                  subtitle: Text(
                    'Use your device wallpaper behind launcher screens.',
                    style: TextStyle(
                      color: textColor.withAlpha(170),
                      fontFamily: fontNormal,
                      fontSize: 12,
                    ),
                  ),
                  value: showWallpaper,
                  activeThumbColor: textColor,
                  onChanged: _setWallpaper,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader('Time', textColor),
          Card(
            color: showWallpaper ? textColor.withAlpha(20) : sectionColor,
            child: SwitchListTile(
              title: Text(
                '24-hour clock',
                style: TextStyle(color: textColor, fontFamily: fontNormal),
              ),
              value: is24HourFormat,
              activeThumbColor: textColor,
              onChanged: _set24HourFormat,
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader('Home screen', textColor),
          Card(
            color: showWallpaper ? textColor.withAlpha(20) : sectionColor,
            child: SwitchListTile(
              title: Text(
                'Show events on home screen',
                style: TextStyle(color: textColor, fontFamily: fontNormal),
              ),
              subtitle: Text(
                'Show upcoming events below the clock.',
                style: TextStyle(
                  color: textColor.withAlpha(170),
                  fontFamily: fontNormal,
                  fontSize: 12,
                ),
              ),
              value: showEventsOnHomeScreen,
              activeThumbColor: textColor,
              onChanged: _setShowEventsOnHomeScreen,
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader('App drawer', textColor),
          Card(
            color: showWallpaper ? textColor.withAlpha(20) : sectionColor,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Show recent apps',
                    style: TextStyle(color: textColor, fontFamily: fontNormal),
                  ),
                  value: showRecentApps,
                  activeThumbColor: textColor,
                  onChanged: _setShowRecentApps,
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(
                    'Icon grid columns',
                    style: TextStyle(color: textColor, fontFamily: fontNormal),
                  ),
                  trailing: DropdownButton<int>(
                    value: appDrawerColumns,
                    dropdownColor: selectedTheme.backgroundColor,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: fontNormal,
                    ),
                    items: const [3, 4, 5]
                        .map(
                          (columns) => DropdownMenuItem(
                            value: columns,
                            child: Text('$columns'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _setAppDrawerColumns(value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, Color textColor) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontFamily: fontNormal,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _colorPreview(Color color) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selectedTheme.textColor.withAlpha(100)),
        ),
      );
}
