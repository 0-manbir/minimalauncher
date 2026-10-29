import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:minimalauncher/pages/helpers/app_icon.dart';
import 'package:minimalauncher/pages/right_screen.dart';
import 'package:minimalauncher/pages/settings_page.dart';
import 'package:minimalauncher/pages/widgets/app_drawer.dart';
import 'package:minimalauncher/variables/strings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';
// import 'package:wallpaper/wallpaper.dart';
import 'package:weather/weather.dart';

class LeftScreen extends StatefulWidget {
  const LeftScreen({super.key, this.onSettingsChanged});

  final VoidCallback? onSettingsChanged;

  @override
  State<LeftScreen> createState() => _LeftScreenState();
}

class _LeftScreenState extends State<LeftScreen> with WidgetsBindingObserver {
  final TextEditingController weatherApiKeyController = TextEditingController();

  late SharedPreferences _prefs;
  Color textColor = Colors.black;
  Color selectedColor = Colors.white;
  bool showWallpaper = false;
  bool focusModeEnabled = false;
  bool dndEnabled = false;
  bool dndAccessGranted = false;
  Set<String> focusBlockedApps = {};

  static const int maxQuickApps = 10;
  List<String?> quickApps = List<String?>.filled(maxQuickApps, null);

  List<Event> _events = [];

  // ignore: non_constant_identifier_names
  String WEATHERMAP_API_KEY = "";
  String _temperature = "--";
  String _weatherLocation = "Location";
  String _weatherSummary = "Summary";

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _loadQuickApps();
    _loadHomeScreenEvents();
    _loadFocusPreferences();
        // Defer DND status loading to after the first frame to ensure method channel is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Small delay to ensure Flutter engine and method channel are fully initialized
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _loadDndStatus();
            }
          });
        });

        super.initState();
      }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    weatherApiKeyController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDndStatus();
    }
  }

  Future<void> _loadFocusPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      focusModeEnabled = prefs.getBool(prefsFocusModeEnabled) ?? false;
      focusBlockedApps =
          prefs.getStringList(prefsFocusBlockedApps)?.toSet() ?? <String>{};
    });
  }

  Future<void> _loadDndStatus() async {
    try {
      final status = Map<String, dynamic>.from(
        await _channel.invokeMapMethod<String, dynamic>('getDndStatus') ??
            <String, dynamic>{},
      );
      if (!mounted) return;
      setState(() {
        dndAccessGranted = status['accessGranted'] as bool? ?? false;
        dndEnabled = dndAccessGranted && (status['enabled'] as bool? ?? false);
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        dndAccessGranted = false;
        dndEnabled = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read Do Not Disturb status.')),
      );
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        dndAccessGranted = false;
        dndEnabled = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Update the app to enable the Do Not Disturb control.'),
        ),
      );
    }
  }

  Future<bool> _canLaunchApp(String packageName) async {
    final canLaunch = await _channel.invokeMethod<bool>(
      'canLaunchApp',
      {'packageName': packageName},
    );
    if (canLaunch == null) {
      throw PlatformException(
        code: 'INVALID_RESPONSE',
        message: 'Could not determine whether $packageName can be launched.',
      );
    }
    return canLaunch;
  }

  Future<void> _configureFocusApps() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final installedApps = await InstalledApps.getInstalledApps(false, false);
      final launchableApps = (await Future.wait<AppInfo?>(
        installedApps.map((app) async {
          return await _canLaunchApp(app.packageName) ? app : null;
        }),
      ))
          .whereType<AppInfo>()
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;

      final selectedPackages = Set<String>.from(focusBlockedApps);
      var search = '';
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: selectedColor,
        builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredApps = launchableApps
                .where((app) =>
                    app.name.toLowerCase().contains(search.toLowerCase()))
                .toList();
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.9,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Apps to hide in Focus mode',
                              style: TextStyle(
                                color: textColor,
                                fontFamily: fontNormal,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${selectedPackages.length} selected',
                            style: TextStyle(
                              color: textColor.withAlpha(160),
                              fontFamily: fontNormal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        autofocus: false,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Search apps',
                          prefixIcon: Icon(Icons.search, color: textColor),
                        ),
                        onChanged: (value) =>
                            setSheetState(() => search = value.trim()),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = filteredApps[index];
                          final isSelected =
                              selectedPackages.contains(app.packageName);
                          return CheckboxListTile(
                            value: isSelected,
                            activeColor: textColor,
                            checkColor: selectedColor,
                            title: Text(
                              app.name,
                              style: TextStyle(
                                color: textColor,
                                fontFamily: fontNormal,
                              ),
                            ),
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  selectedPackages.add(app.packageName);
                                } else {
                                  selectedPackages.remove(app.packageName);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: textColor,
                            foregroundColor: selectedColor,
                          ),
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setStringList(
                              prefsFocusBlockedApps,
                              selectedPackages.toList(),
                            );
                            if (!mounted || !context.mounted) return;
                            setState(() {
                              focusBlockedApps = selectedPackages;
                            });
                            widget.onSettingsChanged?.call();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Save blocked apps'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } on PlatformException catch (error) {
      messenger.showSnackBar(
        SnackBar(
            content: Text('Could not load installed apps: ${error.message}')),
      );
    }
  }

  Future<void> _toggleFocusMode() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = !focusModeEnabled;
    await prefs.setBool(prefsFocusModeEnabled, enabled);
    if (!mounted) return;
    setState(() => focusModeEnabled = enabled);
    widget.onSettingsChanged?.call();
  }

  Future<void> _toggleDndMode() async {
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>(
        'getDndStatus',
      );
      final accessGranted = status?['accessGranted'] as bool? ?? false;
      if (!accessGranted) {
        await _channel.invokeMethod<void>('requestDndAccess');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Allow Do Not Disturb access, then tap DND again.'),
            ),
          );
        }
        return;
      }

      final enabled = !(status?['enabled'] as bool? ?? false);
      final applied = await _channel.invokeMethod<bool>(
        'setDndEnabled',
        {'enabled': enabled},
      );
      if (applied != true) {
        throw PlatformException(
          code: 'DND_UPDATE_FAILED',
          message: 'Android did not apply the Do Not Disturb setting.',
        );
      }
      if (!mounted) return;
      setState(() {
        dndAccessGranted = true;
        dndEnabled = enabled;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update DND: ${error.message}')),
      );
      _loadDndStatus();
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Update the app to enable the Do Not Disturb control.'),
        ),
      );
    }
  }

  // Load preferences from shared preferences
  _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    if (!_prefs.containsKey(prefsSelectedColor)) {
      _prefs.setInt(prefsSelectedColor, selectedColor.toARGB32());
    }
    if (!_prefs.containsKey(prefsTextColor)) {
      _prefs.setInt(prefsTextColor, textColor.toARGB32());
    }

    setState(() {
      selectedColor = Color(_prefs.getInt(prefsSelectedColor)!);
      textColor = Color(_prefs.getInt(prefsTextColor)!);
      showWallpaper = _prefs.getBool(prefsShowWallpaper) ?? false;

      WEATHERMAP_API_KEY = _prefs.getString(prefsWeatherApiKey) ?? "";
      _temperature = _prefs.getString(prefsWeatherTemp) ?? "--";
      _weatherSummary = _prefs.getString(prefsWeatherDesc) ??
          "The weather summary will appear here (click to enter your API key)";
      _weatherLocation = _prefs.getString(prefsWeatherLocation) ?? "Location";
    });
  }

  Future<void> _loadQuickApps() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      quickApps = prefs.getStringList('quick_apps')?.map((e) => e).toList() ??
          List<String?>.filled(maxQuickApps, null);
    });
  }

  Future<void> _saveQuickApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'quick_apps', quickApps.map((e) => e ?? '').toList());
  }

  Future<void> _loadHomeScreenEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventList = prefs.getStringList('events') ?? [];

    // Filter events marked for home screen
    final allEvents =
        eventList.map((e) => Event.fromJson(json.decode(e))).toList();

    setState(() {
      _events = allEvents.where((event) => !event.isCompleted).toList();
    });
  }

  Future<void> savePrefs(String key, dynamic value) async {
    if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    }
  }

  // Quick Apps
  Future<void> _selectApp(int index) async {
    final String? selectedPackage = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      useRootNavigator: true,
      enableDrag: false,
      builder: (BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).height,
        width: MediaQuery.sizeOf(context).width,
        child: AppDrawer(
          autoFocusSearch: true,
          bgColor: selectedColor,
          textColor: textColor,
          showWallpaper: showWallpaper,
          initiallyShowAllApps: true,
        ),
      ),
    );

    if (selectedPackage != null && selectedPackage.isNotEmpty) {
      setState(() {
        quickApps[index] = selectedPackage;
      });
      await _saveQuickApps();
    }
  }

  Future<void> _removeApp(int index) async {
    setState(() {
      quickApps[index] = '';
    });
    await _saveQuickApps();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      child: Column(
        children: [
          quickSettings(context),
          divider(),
          temperatureWidget(context),
          divider(),
          focusAndDndControls(),
          divider(),
          Expanded(child: Container()),
          quickAppsWidget(),
        ],
      ),
    );
  }

  Widget divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Divider(color: textColor.withAlpha(51)),
    );
  }

  Widget quickSettings(BuildContext buildContext) {
    double borderRadius = 16.0;
    double padding = 8.0;
    double iconSize = 32.0;
    Color bgColor = textColor.withAlpha(230);
    Color iconColor = selectedColor;
    return SizedBox(
      height: MediaQuery.of(buildContext).size.height * 0.09,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: EdgeInsets.all(padding),
            child: GestureDetector(
              child: Icon(
                Icons.wallpaper_rounded,
                size: iconSize,
                color: iconColor,
              ),
              onTap: () {
                HapticFeedback.mediumImpact();
                _changeWallpaper(context);
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: EdgeInsets.all(padding),
            child: GestureDetector(
              child: Icon(
                Icons.rocket_rounded,
                color: iconColor,
                size: iconSize,
              ),
              onTap: () {
                HapticFeedback.mediumImpact();
                changeLauncher();
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: EdgeInsets.all(padding),
            child: GestureDetector(
              child: Icon(
                Icons.settings_suggest_rounded,
                color: iconColor,
                size: iconSize,
              ),
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(),
                  ),
                ).then((_) {
                  _loadPreferences();
                  widget.onSettingsChanged?.call();
                });
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: EdgeInsets.all(padding),
            child: GestureDetector(
              child: Icon(
                Icons.settings_rounded,
                color: iconColor,
                size: iconSize,
              ),
              onTap: () async {
                HapticFeedback.mediumImpact();

                const intent =
                    AndroidIntent(action: 'android.settings.SETTINGS');

                try {
                  await intent.launch();
                } catch (e) {
                  showSnackBar(e.toString());
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget focusAndDndControls() {
    final inactiveBackground = textColor.withAlpha(20);
    final inactiveForeground = textColor;
    final enabledBackground = textColor;
    final enabledForeground = selectedColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _modeButton(
              icon: Icons.center_focus_strong_rounded,
              label: 'Focus mode',
              enabled: focusModeEnabled,
              onPressed: _toggleFocusMode,
              onSetPressed: _configureFocusApps,
              inactiveBackground: inactiveBackground,
              inactiveForeground: inactiveForeground,
              enabledBackground: enabledBackground,
              enabledForeground: enabledForeground,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: _modeButton(
              icon: Icons.do_not_disturb_on_rounded,
              label: 'DND',
              enabled: dndEnabled,
              onPressed: _toggleDndMode,
              inactiveBackground: inactiveBackground,
              inactiveForeground: inactiveForeground,
              enabledBackground: enabledBackground,
              enabledForeground: enabledForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
    required Color inactiveBackground,
    required Color inactiveForeground,
    required Color enabledBackground,
    required Color enabledForeground,
    VoidCallback? onSetPressed,
  }) {
    final background = enabled ? enabledBackground : inactiveBackground;
    final foreground = enabled ? enabledForeground : inactiveForeground;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 28),
              const SizedBox(width: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontFamily: fontNormal,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(child: Container()),
              if (onSetPressed != null)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: foreground,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onSetPressed();
                  },
                  child: Icon(
                    Icons.tune_rounded,
                    color: foreground,
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget temperatureWidget(BuildContext buildContext) {
    return SizedBox(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _temperature = "--";
            _getWeather(buildContext);
          });
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          searchGoogle("weather");
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Icon(
                Icons.thermostat_rounded,
                color: textColor.withAlpha(230),
                size: 36,
              ),
              Container(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _temperature,
                          style: TextStyle(
                            fontFamily: fontNormal,
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                            height: 1.25,
                          ),
                        ),
                        TextSpan(
                          text: "°C",
                          style: TextStyle(
                            fontFamily: fontNormal,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _weatherLocation,
                    style: TextStyle(
                      fontFamily: fontNormal,
                      fontSize: 14,
                      color: textColor.withAlpha(204),
                      height: 1.25,
                    ),
                  ),
                  Container(height: 2),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: Text(
                      _weatherSummary,
                      style: TextStyle(
                        fontFamily: fontNormal,
                        fontSize: 11,
                        color: textColor.withAlpha(204),
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget quickAppsWidget() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 10.0,
          crossAxisSpacing: 10.0,
        ),
        itemCount: maxQuickApps,
        itemBuilder: (context, index) {
          final storedPackageName = quickApps[index];
          final packageName =
              focusModeEnabled && focusBlockedApps.contains(storedPackageName)
                  ? null
                  : storedPackageName;
          return GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              if (packageName == null || packageName == '') {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 2),
                      content: Text('Select an app to add to QUICK APPS'),
                    ),
                  );
                }
                await _selectApp(index);
              } else {
                InstalledApps.startApp(packageName);
              }
            },
            onLongPress: packageName != null && packageName != ''
                ? () async {
                    HapticFeedback.heavyImpact();
                    await _removeApp(index);
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Container(
                decoration: BoxDecoration(
                  color: packageName == null || packageName == ''
                      ? textColor.withAlpha(13)
                      : textColor.withAlpha(0),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Center(
                  child: packageName == null || packageName == ''
                      ? Icon(
                          Icons.add_rounded,
                          color: textColor.withAlpha(76),
                          size: 42,
                        )
                      : FutureBuilder<String>(
                          future: getAppIcon(packageName),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
                              if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}');
                              } else if (snapshot.data?.isNotEmpty == true) {
                                return ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: ColorFiltered(
                                      colorFilter: ColorFilter.mode(
                                        Colors.black.withAlpha(102),
                                        BlendMode.saturation,
                                      ),
                                      child: ColorFiltered(
                                        colorFilter: ColorFilter.mode(
                                          textColor,
                                          BlendMode.color,
                                        ),
                                        child: Image.file(
                                          File(snapshot.data!),
                                          width: 75,
                                          height: 75,
                                          cacheWidth: 140,
                                          cacheHeight: 140,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Icon(
                                            Icons.apps_rounded,
                                            color: textColor,
                                            size: 45,
                                          ),
                                        ),
                                      ),
                                    ));
                              } else {
                                return const Text('?');
                              }
                            } else {
                              return const CircularProgressIndicator();
                            }
                          },
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // HELPER FUNCTIONS----------------------------------------------------------------------------------------

  Future<void> _changeWallpaper(BuildContext buildContext) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    File file;

    if (result != null) {
      file = File(result.files.single.path!);
    } else {
      if (buildContext.mounted) {
        ScaffoldMessenger.of(buildContext).showSnackBar(
          const SnackBar(
            content: Text('No wallpaper selected'),
          ),
        );
      }
      return;
    }

    if (!buildContext.mounted) return;

    // Show bottom sheet for screen selection
    showModalBottomSheet(
      context: buildContext,
      builder: (context) {
        return SizedBox(
          height: 200,
          child: Column(
            children: [
              ListTile(
                title: const Text('Home Screen'),
                onTap: () {
                  Navigator.pop(context);
                  _applyWallpaper(
                      file, WallpaperManagerFlutter.homeScreen, buildContext);
                },
              ),
              ListTile(
                title: const Text('Lock Screen'),
                onTap: () {
                  Navigator.pop(context);
                  _applyWallpaper(
                      file, WallpaperManagerFlutter.lockScreen, buildContext);
                },
              ),
              ListTile(
                title: const Text('Both'),
                onTap: () {
                  Navigator.pop(context);
                  _applyWallpaper(
                      file, WallpaperManagerFlutter.bothScreens, buildContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _applyWallpaper(
      File file, int location, BuildContext buildContext) async {
    try {
      final wmf = WallpaperManagerFlutter();
      await wmf.setWallpaper(file, location);
      if (buildContext.mounted) {
        ScaffoldMessenger.of(buildContext).showSnackBar(
          const SnackBar(content: Text('Wallpaper applied')),
        );
      }
    } catch (e) {
      if (buildContext.mounted) {
        ScaffoldMessenger.of(buildContext).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _getWeather(BuildContext buildContext) async {
    try {
      if (!await Permission.location.isGranted) {
        await Permission.location.request();
      }

      Position position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));

      WeatherFactory wf = WeatherFactory(WEATHERMAP_API_KEY);

      Weather weather = await wf.currentWeatherByLocation(
        position.latitude,
        position.longitude,
      );

      // Get and format the weather description to title case
      String description = (weather.weatherDescription ?? "Clear");

      // Collect additional weather details: feels like, min, max
      String feelsLike = weather.tempFeelsLike?.celsius?.toInt().toString() ??
          weather.temperature!.celsius!.toInt().toString();
      String minTemp = weather.tempMin?.celsius?.toInt().toString() ?? '-';
      String maxTemp = weather.tempMax?.celsius?.toInt().toString() ?? '-';
      int humidity = weather.humidity != null ? weather.humidity!.toInt() : 0;

      // Create a detailed weather summary
      String weatherSummary = "$description  •  Feels like $feelsLike°C.\n"
          "Min $minTemp°C  •  Max $maxTemp°C  •  Humidity $humidity%\n"
          "Sunrise ${weather.sunrise!.toString().substring(11, 16)}  •  "
          "Sunset ${weather.sunset!.toString().substring(11, 16)}";

      setState(() {
        savePrefs(
            prefsWeatherTemp, weather.temperature!.celsius!.toInt().toString());
        savePrefs(prefsWeatherLocation, weather.areaName!);
        savePrefs(prefsWeatherDesc, weatherSummary);
        _loadPreferences();
      });
    } catch (e) {
      if (buildContext.mounted) {
        showModalBottomSheet(
          context: buildContext,
          backgroundColor: selectedColor,
          builder: (BuildContext context) {
            return SizedBox(
              width: double.maxFinite,
              child: Column(
                children: [
                  const SizedBox(height: 16.0),
                  Text(
                    "Enter your OpenWeather API:",
                    style: TextStyle(
                      fontFamily: fontNormal,
                      fontSize: 20,
                      color: textColor.withAlpha(204),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Container(
                    margin: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: weatherApiKeyController,
                      style: TextStyle(
                        fontFamily: fontNormal,
                        fontSize: 16,
                        color: textColor,
                      ),
                      onTap: () {
                        weatherApiKeyController.text = WEATHERMAP_API_KEY;
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        savePrefs(
                            prefsWeatherApiKey, weatherApiKeyController.text);
                        _loadPreferences();
                      });
                      Navigator.pop(context);
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(textColor),
                      foregroundColor: WidgetStateProperty.all(selectedColor),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 12.0),
                      child: Text(
                        'Save API Key',
                        style: TextStyle(
                          fontFamily: fontNormal,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    }
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  Future<void> changeLauncher() async {
    try {
      await _channel.invokeMethod('changeLauncher');
    } catch (e) {
      showSnackBar(e.toString());
    }
  }

  Future<void> searchGoogle(String query) async {
    try {
      await _channel.invokeMethod('searchGoogle', {'query': query});
    } catch (e) {
      showSnackBar(e.toString());
    }
  }

  static const MethodChannel _channel = MethodChannel('main_channel');
}
