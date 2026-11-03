import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:minimalauncher/services/github_update_service.dart';
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
  bool showEventsOnHomeScreen = true;
  bool showRecentApps = true;
  int appDrawerColumns = 4;
  LauncherThemePreset selectedTheme = LauncherThemePreset.presets.first;
  bool isCheckingForUpdates = false;

  final GitHubUpdateService _updateService = GitHubUpdateService();

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
    final selectedTheme = LauncherThemePreset.fromPreferences(
      id: storedTheme,
      backgroundColor: legacyBackground,
      textColor: legacyText,
    );

    setState(() {
      showWallpaper = prefs.getBool(prefsShowWallpaper) ?? false;
      is24HourFormat = prefs.getBool(prefsIs24HourFormat) ?? false;
      showEventsOnHomeScreen =
          prefs.getBool(prefsShowEventsOnHomeScreen) ?? true;
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
    await prefs.setBool(
      prefsShowEventsOnHomeScreen,
      showEventsOnHomeScreen,
    );
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
    var pickedColor =
        background ? selectedTheme.backgroundColor : selectedTheme.textColor;
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

  Future<void> _setShowEventsOnHomeScreen(bool value) async {
    setState(() {
      showEventsOnHomeScreen = value;
    });
    await _savePreferences();
  }

  Future<void> _setAppDrawerColumns(int value) async {
    setState(() {
      appDrawerColumns = value;
    });
    await _savePreferences();
  }

  Future<void> _checkForUpdates() async {
    if (isCheckingForUpdates) return;
    setState(() => isCheckingForUpdates = true);
    try {
      final installedInfo = await const MethodChannel('main_channel')
          .invokeMapMethod<String, String>('getAppVersion');
      final currentVersion = installedInfo?['version'];
      final buildNumber = installedInfo?['buildNumber'];
      if (currentVersion == null || currentVersion.isEmpty) {
        throw const UpdateException(
          'Could not read the installed app version from Android.',
        );
      }

      final release = await _updateService.fetchLatestRelease();
      if (!mounted) return;

      final installedVersion = buildNumber == null || buildNumber.isEmpty
          ? currentVersion
          : '$currentVersion+$buildNumber';
      if (!isUpdateAvailable(release.version, installedVersion)) {
        await _showUpdateMessage(
          title: 'You’re up to date',
          message: 'Installed version: $installedVersion',
          textColor: selectedTheme.textColor,
        );
        return;
      }

      await _showReleaseDetails(
        release,
        installedVersion: installedVersion,
        textColor: selectedTheme.textColor,
      );
    } catch (error) {
      if (mounted) {
        await _showUpdateMessage(
          title: 'Update check failed',
          message: error.toString(),
          textColor: selectedTheme.textColor,
        );
      }
    } finally {
      if (mounted) setState(() => isCheckingForUpdates = false);
    }
  }

  Future<void> _showReleaseDetails(
    GitHubReleaseUpdate release, {
    required String installedVersion,
    required Color textColor,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Version ${release.version} is available',
          style: TextStyle(color: textColor, fontFamily: fontNormal),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Installed: $installedVersion',
                style: TextStyle(color: textColor.withAlpha(180)),
              ),
              const SizedBox(height: 12),
              Text(
                'Release notes',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontFamily: fontNormal,
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    release.releaseNotes,
                    style: TextStyle(color: textColor, fontFamily: fontNormal),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Later', style: TextStyle(color: textColor)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_downloadAndInstall(release));
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall(GitHubReleaseUpdate release) async {
    var receivedBytes = 0;
    int? totalBytes;
    StateSetter? updateProgressState;
    var progressDialogVisible = true;
    final navigator = Navigator.of(context);
    final textColor = selectedTheme.textColor;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              updateProgressState = setDialogState;
              final progress = totalBytes == null || totalBytes == 0
                  ? null
                  : (receivedBytes / totalBytes!).clamp(0.0, 1.0).toDouble();
              final label = progress == null
                  ? '${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB downloaded'
                  : '${(progress * 100).toStringAsFixed(0)}%';
              return AlertDialog(
                title: Text(
                  'Downloading update',
                  style: TextStyle(color: textColor, fontFamily: fontNormal),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 12),
                    Text(label, style: TextStyle(color: textColor)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    try {
      final apk = await _updateService.downloadApk(
        release,
        onProgress: (received, total) {
          receivedBytes = received;
          totalBytes = total;
          updateProgressState?.call(() {});
        },
      );
      if (!mounted) return;
      navigator.pop();
      progressDialogVisible = false;

      final installerOpened = await const MethodChannel('main_channel')
          .invokeMethod<bool>('installApk', {'path': apk.path});
      if (!mounted) return;
      final message = installerOpened == true
          ? 'Android package installer opened. Follow its prompts to finish.'
          : 'Allow installs from Minimal Launcher in Android settings, then check for updates and tap Update Now.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      if (progressDialogVisible) navigator.pop();
      await _showUpdateMessage(
        title: 'Update failed',
        message: error.toString(),
        textColor: textColor,
      );
    }
  }

  Future<void> _showUpdateMessage({
    required String title,
    required String message,
    required Color textColor,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(color: textColor)),
        content: SelectableText(
          message,
          style: TextStyle(color: textColor, fontFamily: fontNormal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: textColor)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _updateService.close();
    super.dispose();
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
                        ),
                    ],
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
          const SizedBox(height: 16),
          _sectionHeader('Updates', textColor),
          Card(
            color: showWallpaper ? textColor.withAlpha(20) : sectionColor,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.system_update_alt, color: textColor),
                  title: Text(
                    'Check for Updates',
                    style: TextStyle(color: textColor, fontFamily: fontNormal),
                  ),
                  subtitle: Text(
                    isCheckingForUpdates
                        ? 'Checking GitHub Releases…'
                        : 'Check for a newer launcher version.',
                    style: TextStyle(
                      color: textColor.withAlpha(170),
                      fontFamily: fontNormal,
                      fontSize: 12,
                    ),
                  ),
                  trailing: isCheckingForUpdates
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: textColor,
                          ),
                        )
                      : Icon(Icons.chevron_right, color: textColor),
                  onTap: isCheckingForUpdates ? null : _checkForUpdates,
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
