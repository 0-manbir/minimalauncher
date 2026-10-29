// ignore_for_file: prefer_const_constructors

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:minimalauncher/pages/home_page.dart';
import 'package:minimalauncher/pages/left_screen.dart';
import 'package:minimalauncher/pages/right_screen.dart';
import 'package:minimalauncher/pages/widgets/app_drawer.dart';
import 'package:minimalauncher/variables/launcher_theme.dart';
import 'package:minimalauncher/variables/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/installed_apps.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();
  runApp(Launcher());
}

class Launcher extends StatefulWidget {
  const Launcher({super.key});

  @override
  State<Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<Launcher> {
  bool showWallpaper = false;
  Color selectedColor = Colors.white;
  Color textColor = Colors.black;

  final PageController _pageController = PageController(initialPage: 1);

  final GlobalKey<HomeScreenState> _homeScreenKey =
      GlobalKey<HomeScreenState>();
  final GlobalKey<RightScreenState> _rightScreenKey =
      GlobalKey<RightScreenState>();

  static const double _bottomGestureExclusionHeight = 24;
  bool _verticalDragStartedAtBottom = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // Load preferences from shared preferences
  _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey(prefsShowWallpaper)) {
      await prefs.setBool(prefsShowWallpaper, false);
    }
    if (!prefs.containsKey(prefsSelectedColor)) {
      await prefs.setInt(
        prefsSelectedColor,
        LauncherThemePreset.presets.first.backgroundColor.toARGB32(),
      );
    }
    if (!prefs.containsKey(prefsTextColor)) {
      await prefs.setInt(
        prefsTextColor,
        LauncherThemePreset.presets.first.textColor.toARGB32(),
      );
    }

    final theme = LauncherThemePreset.fromPreferences(
      id: prefs.getString(prefsLauncherTheme),
      backgroundColor: prefs.getInt(prefsSelectedColor),
      textColor: prefs.getInt(prefsTextColor),
    );
    if (!prefs.containsKey(prefsLauncherTheme)) {
      await prefs.setString(prefsLauncherTheme, theme.id);
      await prefs.setInt(prefsSelectedColor, theme.backgroundColor.toARGB32());
      await prefs.setInt(prefsTextColor, theme.textColor.toARGB32());
    }

    if (!mounted) return;
    setState(() {
      showWallpaper = prefs.getBool(prefsShowWallpaper) ?? false;
      selectedColor = theme.backgroundColor;
      textColor = theme.textColor;
    });
  }

  @override
  Widget build(BuildContext context) {
    double appDrawerHeight =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;

    Brightness iconsBrightness =
        ThemeData.estimateBrightnessForColor(textColor);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          _pageController.jumpToPage(1);
        },
        child: Scaffold(
          backgroundColor: showWallpaper ? Colors.transparent : selectedColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            toolbarHeight: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              systemNavigationBarColor:
                  showWallpaper ? Colors.transparent : selectedColor,
              systemNavigationBarIconBrightness: iconsBrightness,
              systemNavigationBarContrastEnforced: false,
              statusBarColor:
                  showWallpaper ? Colors.transparent : selectedColor,
              statusBarIconBrightness: iconsBrightness,
              systemStatusBarContrastEnforced: false,
            ),
          ),
          body: Builder(
            builder: (context) {
              return LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  onVerticalDragStart: (details) {
                    _verticalDragStartedAtBottom =
                        details.localPosition.dy >=
                            constraints.maxHeight -
                                _bottomGestureExclusionHeight;
                  },
                  onVerticalDragEnd: (details) {
                    final startedAtBottom = _verticalDragStartedAtBottom;
                    _verticalDragStartedAtBottom = false;
                    if (startedAtBottom) return;

                    if (details.primaryVelocity! > 0) {
                      // Swipe down
                      expandNotification();
                    } else if (details.primaryVelocity! < 0) {
                      openAppDrawer(context, appDrawerHeight);
                    }
                  },
                  onVerticalDragCancel: () {
                    _verticalDragStartedAtBottom = false;
                  },
                  onLongPress: () {
                    // HapticFeedback.heavyImpact();
                    // Open app settings (now moved to Left Screen)
                  },
                  child: PageView(
                    controller: _pageController,
                    pageSnapping: true,
                    physics: const SnappyScrollPhysics(), // custom physics
                    children: [
                      LeftScreen(
                        onSettingsChanged: () async {
                          await _loadPreferences();
                          _refreshScreens();
                        },
                      ),
                      HomeScreen(key: _homeScreenKey),
                      RightScreen(key: _rightScreenKey),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void openAppDrawer(BuildContext buildContext, double height) async {
    // Open the app drawer and wait for a package name to be selected
    if (!buildContext.mounted) return;
    final String? selectedPackage = await showModalBottomSheet<String>(
      context: buildContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      builder: (BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height),
        child: AppDrawer(
          autoFocusSearch: true,
          bgColor: selectedColor,
          textColor: textColor,
          showWallpaper: showWallpaper,
        ),
      ),
    );

    if (selectedPackage != null) {
      HapticFeedback.mediumImpact();
      InstalledApps.startApp(selectedPackage);
    }

    _refreshScreens();
  }

  void _refreshScreens() {
    _homeScreenKey.currentState?.refresh();
    _rightScreenKey.currentState?.refresh();
  }

  // native methods----------------------------------------------------------------------------------------------------------
  Future<void> expandNotification() async {
    try {
      await _channel.invokeMethod(nativeExpandNotification);
    } catch (e) {
      // print('Error invoking expand method: $e');
    }
  }

  static const MethodChannel _channel = MethodChannel('main_channel');
}

class SnappyScrollPhysics extends PageScrollPhysics {
  const SnappyScrollPhysics({super.parent});

  @override
  SnappyScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnappyScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingDistance => 5.0;
  @override
  double get minFlingVelocity => 100.0;
  @override
  double get maxFlingVelocity => 8000.0;

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.5,
        stiffness: 800,
        damping: 40,
      );
}
