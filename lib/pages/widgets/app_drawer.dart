import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:minimalauncher/pages/helpers/app_icon.dart';
import 'package:minimalauncher/variables/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Application {
  String name;
  String packageName;
  bool hasNotification;
  DateTime? installTime;

  Application(
      {required this.name,
      required this.packageName,
      required this.installTime,
      this.hasNotification = false});

  factory Application.fromJson(Map<String, dynamic> json) {
    return Application(
      name: json['name'],
      packageName: json['packageName'],
      installTime: DateTime.parse(json['installTime']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'packageName': packageName,
      'installTime': installTime!.toIso8601String(),
    };
  }
}

class AppDrawer extends StatefulWidget {
  final bool autoFocusSearch;
  final bool initiallyShowAllApps;
  final bool showWallpaper;
  final Color bgColor, textColor;

  const AppDrawer({
    super.key,
    required this.autoFocusSearch,
    required this.bgColor,
    required this.textColor,
    required this.showWallpaper,
    this.initiallyShowAllApps = false,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  List<Application> apps = [];
  List<Application> recentApps = [];
  List<Application> favoriteApps = [];
  TextEditingController searchController = TextEditingController();
  String filter = "";
  bool showAllApps = false;
  bool showRecentApps = true;
  int appDrawerColumns = 4;

  Color get bgColor => widget.bgColor;
  Color get textColor => widget.textColor;

  @override
  void initState() {
    super.initState();
    showAllApps = widget.initiallyShowAllApps;
    searchController.addListener(() {
      setState(() {
        filter = searchController.text;
      });
    });
    _loadApps();
    _loadFavoriteApps();
    _loadDrawerPreferences();
  }

  Future<void> _loadDrawerPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      showRecentApps = prefs.getBool(prefsShowRecentApps) ?? true;
      final savedColumns = prefs.getInt(prefsAppDrawerColumns) ?? 4;
      appDrawerColumns = [3, 4, 5].contains(savedColumns) ? savedColumns : 4;
    });
  }

  Future<void> _loadApps() async {
    // Load cached apps data for instant display without delay
    final prefs = await SharedPreferences.getInstance();
    final String? cachedApps = prefs.getString('cachedApps');
    final String? cachedRecentApps = prefs.getString('recentApps');

    if (cachedApps != null) {
      List<dynamic> jsonApps = jsonDecode(cachedApps);
      apps = jsonApps.map((app) => Application.fromJson(app)).toList();
    }

    if (cachedRecentApps != null) {
      List<dynamic> jsonRecentApps = jsonDecode(cachedRecentApps);
      recentApps =
          jsonRecentApps.map((app) => Application.fromJson(app)).toList();
    }

    if (mounted) setState(() {});

    // Fetch and cache apps in the background
    _fetchAndCacheApps();
  }

  Future<DateTime?> getInstallTime(String packageName) async {
    try {
      final int? timestamp = await _channel
          .invokeMethod('getAppInstallTime', {'packageName': packageName});
      return timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null;
    } catch (e) {
      print('Error getting install time: $e');
      return null;
    }
  }

  Future<void> _fetchAndCacheApps() async {
    List<AppInfo> installedApps =
        await InstalledApps.getInstalledApps(false, false);

    // Sort the apps by install time (most recent first)
    // installedApps
    //     .sort((a, b) => b.installedTimestamp.compareTo(a.installedTimestamp));

    installedApps = (await Future.wait(installedApps.map((app) async {
      bool canLaunch = await canLaunchApp(app.packageName);
      return canLaunch ? app : null;
    })))
        .whereType<AppInfo>()
        .toList();

    List<Application> allAppsList =
        await Future.wait(installedApps.map((app) async {
      DateTime? installTime = await getInstallTime(app.packageName);
      return Application(
        name: app.name,
        packageName: app.packageName,
        installTime: installTime,
      );
    }));

    allAppsList.sort((a, b) =>
        b.installTime?.compareTo(
            a.installTime ?? DateTime.fromMillisecondsSinceEpoch(0)) ??
        0);

    List<Application> recentAppsList =
        allAppsList.take(5).toList().reversed.toList();

    // Cache both full app list and recent apps
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cachedApps',
        jsonEncode(allAppsList.map((app) => app.toJson()).toList()));
    await prefs.setString('recentApps',
        jsonEncode(recentAppsList.map((app) => app.toJson()).toList()));

    // Update state in background to reflect new data
    if (!mounted) return;
    setState(() {
      apps = allAppsList;
      recentApps = recentAppsList;
    });
  }

  Future<void> _loadFavoriteApps() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedFavorites = prefs.getString('favoriteApps');

    if (cachedFavorites != null) {
      List<dynamic> jsonFavorites = jsonDecode(cachedFavorites);
      setState(() {
        favoriteApps =
            jsonFavorites.map((app) => Application.fromJson(app)).toList();
      });
    }
  }

  Future<void> _toggleFavorite(Application app) async {
    final prefs = await SharedPreferences.getInstance();

    if (favoriteApps.any((fav) => fav.packageName == app.packageName)) {
      favoriteApps.removeWhere((fav) => fav.packageName == app.packageName);
    } else {
      favoriteApps.add(app);
    }

    await prefs.setString(
      'favoriteApps',
      jsonEncode(favoriteApps.map((fav) => fav.toJson()).toList()),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    filter = filter.trim();
    final sortedApps = [...apps]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final filteredApps = filter.isEmpty
        ? []
        : [
            ...apps.where((app) =>
                app.name.toLowerCase().startsWith(filter.toLowerCase())),
            ...apps.where((app) =>
                app.name.toLowerCase().contains(filter.toLowerCase()) &&
                !app.name.toLowerCase().startsWith(filter.toLowerCase())),
          ].toList();

    if (showAllApps) {
      final cellWidth = (MediaQuery.of(context).size.width -
              32 -
              (appDrawerColumns - 1) * 12) /
          appDrawerColumns;
      final iconSize = (cellWidth * 0.75).clamp(36.0, 70.0).toDouble();
      return Scaffold(
        backgroundColor:
            widget.showWallpaper ? Colors.transparent : widget.bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: textColor,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back to app search',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => setState(() => showAllApps = false),
          ),
          title: Text(
            'All apps',
            style: TextStyle(color: textColor, fontFamily: fontNormal),
          ),
        ),
        body: GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: appDrawerColumns,
            mainAxisSpacing: 12.0,
            crossAxisSpacing: 12.0,
            childAspectRatio: 0.72,
          ),
          itemCount: sortedApps.length,
          itemBuilder: (context, index) {
            final app = sortedApps[index];
            return GestureDetector(
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FutureBuilder<String?>(
                      future: getAppIcon(app.packageName),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          if (snapshot.hasError) {
                            return Icon(Icons.apps_rounded,
                                color: textColor, size: iconSize);
                          } else if (snapshot.data?.isNotEmpty == true) {
                            return Image.file(
                              File(snapshot.data!),
                              width: iconSize,
                              height: iconSize,
                              cacheWidth: (iconSize * 2).round(),
                              cacheHeight: (iconSize * 2).round(),
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.apps_rounded,
                                      color: textColor, size: iconSize),
                            );
                          } else {
                            return Icon(Icons.apps_rounded,
                                color: textColor, size: iconSize);
                          }
                        } else {
                          return Icon(Icons.apps_rounded,
                              color: textColor.withAlpha(100), size: iconSize);
                        }
                      },
                    ),
                    Text(
                      app.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () {
                Navigator.pop(context, app.packageName);
              },
              onLongPress: () {
                HapticFeedback.heavyImpact();
                InstalledApps.openSettings(app.packageName);
              },
            );
          },
        ),
      );
    }

    return Scaffold(
      floatingActionButton: Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.4,
          child: FloatingActionButton.extended(
            onPressed: () {
              setState(() {
                showAllApps = true;
              });
            },
            backgroundColor: textColor.withOpacity(0.8),
            icon: Icon(
              Icons.grid_view_rounded,
              color: bgColor,
            ),
            label: Text(
              'All Apps',
              style: TextStyle(
                color: bgColor,
                fontFamily: fontNormal,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      backgroundColor: widget.showWallpaper ? Colors.transparent : bgColor,
      body: Column(
        children: [
          // Displaying 5 most recently installed apps
          if (showRecentApps && recentApps.isNotEmpty && filter.isEmpty)
            Expanded(
              flex: 4,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: recentApps.map((app) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context, app.packageName);
                      },
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        InstalledApps.openSettings(app.packageName);
                        Navigator.pop(context, null);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          app.name,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontFamily: fontNormal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          if (!showRecentApps || recentApps.isEmpty)
            const Expanded(child: SizedBox.shrink()),

          if (filter.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: filteredApps.length,
                reverse: true,
                itemBuilder: (context, index) {
                  final app = filteredApps[index];
                  final isFavorite = favoriteApps
                      .any((fav) => fav.packageName == app.packageName);

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context, app.packageName);
                    },
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      InstalledApps.openSettings(app.packageName);
                      Navigator.pop(context, null);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4.0, horizontal: 16.0),
                      child: Row(
                        // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            child: Icon(
                              isFavorite
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: isFavorite ? Colors.orange : textColor,
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _toggleFavorite(app);
                            },
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Text(
                              app.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontFamily: fontNormal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  searchGoogle(searchController.text);
                  Navigator.pop(context, null);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: textColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Image.asset(
                    'assets/apps/google.png',
                    width: 40,
                    color: textColor,
                  ),
                ),
              ),
              SizedBox(width: 8.0),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  searchPlayStore(searchController.text);
                  Navigator.pop(context, null);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Image.asset(
                    'assets/apps/playstore.png',
                    width: 40,
                    color: textColor,
                  ),
                ),
              ),
              SizedBox(width: 8.0),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  searchDefaultBrowser(searchController.text);
                  Navigator.pop(context, null);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Image.asset(
                    'assets/apps/web.png',
                    width: 40,
                    color: textColor,
                  ),
                ),
              ),
              SizedBox(width: 16.0),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 6.0,
            ),
            child: TextField(
              controller: searchController,
              autofocus: widget.autoFocusSearch,
              cursorColor: textColor,
              style: TextStyle(
                color: textColor,
                fontFamily: fontNormal,
              ),
              decoration: InputDecoration(
                hintText: "Search apps...",
                hintStyle: TextStyle(
                  color: textColor,
                  fontFamily: fontNormal,
                  fontWeight: FontWeight.w300,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (value) {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, filteredApps[0].packageName);
              },
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool> canLaunchApp(String packageName) async {
    try {
      final bool result = await _channel
          .invokeMethod('canLaunchApp', {'packageName': packageName});
      // print("$packageName can launch: $result");
      return result;
    } on PlatformException {
      // print("Error: ${e.message}");
      return false;
    }
  }

  Future<void> searchPlayStore(String query) async {
    if (query.trim() == "") {
      openAppByPackageName(googleplaystorePackageName);
      return;
    }
    try {
      await _channel.invokeMethod('searchPlayStore', {'query': query});
    } catch (e) {
      // print('Error invoking search play store method: $e');
    }
  }

  Future<void> searchGoogle(String query) async {
    if (query.trim() == "") {
      openAppByPackageName(googlePackageName);
      return;
    }
    try {
      await _channel.invokeMethod('searchGoogle', {'query': query});
    } catch (e) {
      // print('Error invoking searchGoogle method: $e');
    }
  }

  Future<void> searchDefaultBrowser(String query) async {
    try {
      await _channel.invokeMethod('searchDefaultBrowser', {'query': query});
    } catch (e) {
      // print('Error invoking searchGoogle method: $e');
    }
  }

  Future<void> openAppByPackageName(String packageName) async {
    try {
      await _channel.invokeMethod('openApp', {'packageName': packageName});
    } catch (e) {
      // print('error in launching app $e');
    }
  }

  static const MethodChannel _channel = MethodChannel('main_channel');
}
