// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:interactive_slider/interactive_slider.dart';
import 'package:intl/intl.dart';
import 'package:minimalauncher/pages/right_screen.dart';
import 'package:minimalauncher/pages/widgets/app_drawer.dart';
import 'package:minimalauncher/variables/strings.dart';
// import 'package:notification_listener/notification_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

bool is24HourFormat = false;
Color textColor = Colors.black;
Color selectedColor = Colors.white;

class HomeScreenState extends State<HomeScreen> {
  int _batteryLevel = 0;
  bool _showEventsOnHomeScreen = true;
  late Timer refreshTimer;

  final progressController = InteractiveSliderController(0.0);
  // Default start and end times (5 am to 10 pm)
  static const defaultStartTime = TimeOfDay(hour: 5, minute: 0);
  static const defaultEndTime = TimeOfDay(hour: 22, minute: 0);

  List<Application> favoriteApps = [];
  List<Event> _eventsToShowOnHome = [];

  Timer? _pollingTimer;
  // final Set<String> _activeNotifications = {};

  void refresh() {
    setState(() {
      _loadPreferences();
      _loadFavoriteApps();
      _loadHomeScreenEvents();
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferences();
      _loadFavoriteApps();
      // _initializeNotificationListener();
      // _startPolling();
      _loadDayProgress();
      _getBatteryPercentage();
      _loadHomeScreenEvents();

      refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (mounted) {
          setState(() {
            _getBatteryPercentage();
            _loadDayProgress();
            _loadHomeScreenEvents();
          });
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    // cancel the timer when the widget is disposed
    refreshTimer.cancel();
    _pollingTimer?.cancel();
    // progressController.dispose();
    super.dispose();
  }

  // Load preferences from shared preferences
  _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      is24HourFormat = prefs.getBool(prefsIs24HourFormat) ?? true;
      int? textColorValue = prefs.getInt(prefsTextColor);
      if (textColorValue != null) {
        textColor = Color(textColorValue);
      }
      int? selectedColorValue = prefs.getInt(prefsSelectedColor);
      if (selectedColorValue != null) {
        selectedColor = Color(selectedColorValue);
      }
      _showEventsOnHomeScreen =
          prefs.getBool(prefsShowEventsOnHomeScreen) ?? true;
    });
  }

  Future<void> _loadHomeScreenEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventList = prefs.getStringList('events') ?? [];

    // Filter events marked for home screen
    final allEvents =
        eventList.map((e) => Event.fromJson(json.decode(e))).toList();

    setState(() {
      _eventsToShowOnHome = allEvents
          .where((event) => event.showOnHomeScreen && !event.isCompleted)
          .toList();
    });
  }

  Future<void> _loadDayProgress() async {
    // Load day start and end times from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // Exit early if the widget is disposed

    final startTimeHour = prefs.getInt('dayStartHour') ?? defaultStartTime.hour;
    final startTimeMinute =
        prefs.getInt('dayStartMinute') ?? defaultStartTime.minute;
    final endTimeHour = prefs.getInt('dayEndHour') ?? defaultEndTime.hour;
    final endTimeMinute = prefs.getInt('dayEndMinute') ?? defaultEndTime.minute;

    // Calculate and set initial progress
    final startTime = TimeOfDay(hour: startTimeHour, minute: startTimeMinute);
    final endTime = TimeOfDay(hour: endTimeHour, minute: endTimeMinute);

    // Ensure widget is still mounted before updating progress
    if (mounted) {
      _updateDayProgress(startTime, endTime);
    }
  }

/*
  void _initializeNotificationListener() async {
    bool isGranted = await AndroidNotificationListener.isGranted();
    if (!isGranted) {
      isGranted = await AndroidNotificationListener.request();
    }
    if (isGranted) {
      // Handle new notifications
      AndroidNotificationListener.accessStream.listen((event) {
        setState(() {
          _activeNotifications.add(event.packageName!);
          for (var app in favoriteApps) {
            if (app.packageName == event.packageName) {
              app.hasNotification = true;
            }
          }
        });
      });
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      try {
        // Fetch active notifications
        // List<Map<String, dynamic>> notifications =
        //     await AndroidNotificationListener.getActiveNotifications();

        AndroidNotificationListener.accessStream.length;

        // Extract package names of active notifications
        // final currentNotifications =
        //     notifications.map((e) => e['packageName'] as String).toSet();

        // setState(() {
        //   for (var app in favoriteApps) {
        //     // Update notification state based on polling
        //     app.hasNotification =
        //         currentNotifications.contains(app.packageName);
        //   }
        // });

        // // Update internal state
        // _activeNotifications
        //   ..clear()
        //   ..addAll(currentNotifications);
      } catch (e) {
        // Handle errors (e.g., permissions not granted)
        print('Error fetching notifications: $e');
      }
    });
  }
*/
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

  Future<void> _saveFavoriteApps() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('favoriteApps',
        jsonEncode(favoriteApps.map((app) => app.toJson()).toList()));
  }

  void _getBatteryPercentage() async {
    int battery = await Battery().batteryLevel;

    setState(() {
      _batteryLevel = battery;
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: screenHeight * 0.075),
        ClockWidget(),
        SizedBox(height: screenHeight * 0.025),
        statsWidget(),
        progressWidget(),
        SizedBox(height: 32.0),
        eventsWidget(),
        Expanded(child: Container()),
        homeScreenApps(),
        Expanded(child: Container()),
        searchWidget(),
        SizedBox(height: screenHeight * 0.05),
      ],
    );
  }

  Widget statsWidget() {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      child: GestureDetector(
        onTap: () async {
          const String url = 'content://com.android.calendar/time/';

          if (await canLaunchUrlString(url)) {
            await launchUrlString(url);
          } else {
            showSnackBar('cannot open calendar');
          }
        },
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text:
                    "${DateFormat.d().format(DateTime.now())} ${DateFormat.MMM().format(DateTime.now()).toUpperCase()}$homeStatsSeperator${DateFormat.EEEE().format(DateTime.now()).toUpperCase()}$homeStatsSeperator$_batteryLevel",
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontFamily: fontNormal,
                ),
              ),
              TextSpan(
                text: '%',
                style: TextStyle(
                  color: textColor,
                  fontSize: 10,
                  fontFamily: fontNormal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget progressWidget() {
    return GestureDetector(
      onTap: _setDayStartEndTime,
      child: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              child: InteractiveSlider(
                controller: progressController,
                startIcon: Icon(Icons.wb_sunny_rounded),
                endIcon: Icon(Icons.nights_stay_rounded),
                iconColor: textColor,
                iconSize: 20,
                enabled: false,
                disabledOpacity: 1,
                backgroundColor: textColor.withOpacity(0.1),
                foregroundColor: textColor.withOpacity(0.8),
                unfocusedOpacity: 1,
              ),
            ),
            Expanded(child: Container()),
          ],
        ),
      ),
    );
  }

  String formatTime(DateTime dateTime) {
    int hour = dateTime.hour;
    int minute = dateTime.minute;
    String period = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;
    hour = hour == 0 ? 12 : hour;

    String time = '$hour:${minute.toString().padLeft(2, '0')} $period';

    String date = '';

    if (dateTime.year == DateTime.now().year &&
        dateTime.month == DateTime.now().month &&
        dateTime.day == DateTime.now().day) {
      date = 'Today';
    } else if (dateTime.year == DateTime.now().year &&
        dateTime.month == DateTime.now().month &&
        dateTime.day == DateTime.now().day + 1) {
      date = 'Tomorrow';
    } else {
      date = '${DateFormat.MMM().format(dateTime)} ${dateTime.day}';
    }

    return '$date • $time';
  }

  Widget eventsWidget() {
    if (!_showEventsOnHomeScreen) return const SizedBox.shrink();
    return _eventsToShowOnHome.isNotEmpty
        ? SizedBox(
            height: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: ListView.builder(
                itemCount: _eventsToShowOnHome.length,
                itemBuilder: (context, index) {
                  final eventItem = _eventsToShowOnHome[index];
                  return event(
                    eventItem.name,
                    formatTime(eventItem.deadline),
                  );
                },
              ),
            ),
          )
        : Center(
            child: event(
              "Add an event now!",
              "No events added yet. Add one now!",
            ),
          );
  }

  Widget event(String title, String desc) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Row(
        children: [
          Text(
            "|",
            style: TextStyle(
              color: textColor,
              fontSize: 32,
              fontFamily: fontNormal,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 8.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontFamily: fontNormal,
                  fontSize: 14.0,
                ),
              ),
              Opacity(
                opacity: 0.7,
                child: Text(
                  desc,
                  style: TextStyle(
                    color: textColor,
                    fontFamily: fontNormal,
                    fontSize: 12.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget homeScreenApps() {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Opacity(
        opacity: 0.8,
        child: favoriteApps.isEmpty
            ? Text(
                "Add a favorite app by \nclicking the STAR ICON \nin the search menu.",
                textAlign: TextAlign.left,
                style: TextStyle(
                    color: textColor.withAlpha(100),
                    fontFamily: fontNormal,
                    fontSize: 12.0),
              )
            : ListView.builder(
                itemCount: favoriteApps.length,
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      InstalledApps.startApp(favoriteApps[index].packageName);
                    },
                    onLongPress: () {
                      HapticFeedback.heavyImpact();
                      editHomeScreenApp(context, index);
                    },
                    child: Row(
                      children: [
                        Text(
                          favoriteApps[index].name,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 21,
                            fontFamily: fontNormal,
                          ),
                        ),
                        Container(height: 2.0),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget searchWidget() {
    return Opacity(
      opacity: 0.35,
      child: Column(
        children: [
          Icon(
            Icons.keyboard_arrow_up_rounded,
            color: textColor,
            size: 20,
          ),
          Text(
            "search",
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontFamily: fontNormal,
            ),
          ),
        ],
      ),
    );
  }

  // HELPER FUNCTIONS ---------------------------------------------------------------------------
  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  void _updateDayProgress(TimeOfDay start, TimeOfDay end) {
    final progress = _calculateDayProgress(start, end);
    progressController.value = progress;
  }

  double _calculateDayProgress(TimeOfDay start, TimeOfDay end) {
    final now = TimeOfDay.now();
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final currentMinutes = now.hour * 60 + now.minute;

    // Calculate progress between 0 (start of day) and 1 (end of day)
    return ((currentMinutes - startMinutes) / (endMinutes - startMinutes))
        .clamp(0.0, 1.0);
  }

  Future<void> _setDayStartEndTime() async {
    final start =
        await _pickTime(context, 'Select Day Start Time', defaultStartTime);
    final end = await _pickTime(context, 'Select Day End Time', defaultEndTime);

    if (start != null && end != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dayStartHour', start.hour);
      await prefs.setInt('dayStartMinute', start.minute);
      await prefs.setInt('dayEndHour', end.hour);
      await prefs.setInt('dayEndMinute', end.minute);

      _updateDayProgress(start, end);
    }
  }

  Future<TimeOfDay?> _pickTime(
      BuildContext context, String title, TimeOfDay initialTime) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: title,
    );
  }

  void editHomeScreenApp(BuildContext context, int index) async {
    TextEditingController nameController =
        TextEditingController(text: favoriteApps[index].name);

    await showModalBottomSheet(
      context: context,
      backgroundColor: selectedColor,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: fontNormal,
                    ),
                    cursorColor: textColor,
                    decoration: InputDecoration(
                      labelText: 'Rename App',
                      labelStyle: TextStyle(
                        color: textColor,
                        fontFamily: fontNormal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(textColor),
                        ),
                        onPressed: () {
                          setState(() {
                            favoriteApps[index].name = nameController.text;
                          });
                          _saveFavoriteApps();
                          setState(() {
                            _loadPreferences();
                          });
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color: selectedColor,
                            fontFamily: fontNormal,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(textColor),
                        ),
                        onPressed: () {
                          setState(() {
                            favoriteApps.removeAt(index);
                          });
                          _saveFavoriteApps();
                          setState(() {
                            _loadPreferences();
                          });
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Remove from Favorites',
                          style: TextStyle(
                            color: selectedColor,
                            fontFamily: fontNormal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32.0),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(textColor),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await showModalBottomSheet(
                        context: context,
                        backgroundColor: selectedColor,
                        builder: (context) {
                          return StatefulBuilder(
                            builder: (context, setState) {
                              return Column(
                                children: [
                                  SizedBox(height: 16),
                                  Text(
                                    "Reorder Apps:",
                                    style: TextStyle(
                                      fontFamily: fontNormal,
                                      color: textColor,
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Expanded(
                                    child: ReorderableListView.builder(
                                      itemCount: favoriteApps.length,
                                      onReorderStart: (index) {
                                        HapticFeedback.mediumImpact();
                                      },
                                      onReorder: (oldIndex, newIndex) async {
                                        setState(() {
                                          if (newIndex > oldIndex) {
                                            newIndex -= 1;
                                          }
                                          final item =
                                              favoriteApps.removeAt(oldIndex);
                                          favoriteApps.insert(newIndex, item);
                                        });
                                        await _saveFavoriteApps();
                                        setState(() {
                                          _loadFavoriteApps();
                                        });
                                      },
                                      itemBuilder: (context, i) {
                                        return ListTile(
                                          key: ValueKey(
                                              favoriteApps[i].packageName),
                                          title: Text(
                                            favoriteApps[i].name,
                                            style: TextStyle(
                                              color: textColor,
                                              fontFamily: fontNormal,
                                            ),
                                          ),
                                          trailing: Icon(
                                            Icons.drag_handle_rounded,
                                            color: textColor,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                    child: Text(
                      'Reorder Apps',
                      style: TextStyle(
                        color: selectedColor,
                        fontFamily: fontNormal,
                      ),
                    ),
                  ),
                  Expanded(child: Container()),
                ],
              ),
            );
          },
        );
      },
    );

    setState(() {
      _loadFavoriteApps();
    });
  }
}

// CLOCK WIDGET --------------------------------------------------------------------------------
class ClockWidget extends StatelessWidget {
  const ClockWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      child: StreamBuilder<int>(
        stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
        builder: (context, snapshot) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              GestureDetector(
                child: Text(
                  is24HourFormat
                      ? formattedTime24(DateTime.now())
                      : formattedTime12(DateTime.now()),
                  style: TextStyle(
                    fontSize: 72,
                    fontFamily: fontTime,
                    letterSpacing: 1.5,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    height: .9,
                  ),
                ),

                // date clicked
                onTap: () async {
                  try {
                    await _channel.invokeMethod('showClock');
                  } on PlatformException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Could not open the clock app. $e"),
                        duration: Duration(seconds: 2),
                        dismissDirection: DismissDirection.horizontal,
                      ),
                    );
                  }
                },
              ),
              if (!is24HourFormat) SizedBox(width: 5),
              if (!is24HourFormat)
                Text(
                  getTimeAbbr(DateTime.now()),
                  style: TextStyle(
                    fontSize: 22,
                    color: textColor,
                    fontFamily: fontTime,
                    fontWeight: FontWeight.w100,
                    height: 1.4,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String formattedTime12(DateTime dateTime) {
    int hour = dateTime.hour;
    int minute = dateTime.minute;
    return '${hour > 12 ? hour - 12 : hour}:${minute > 9 ? minute : '0$minute'}';
  }

  String formattedTime24(DateTime dateTime) {
    int hour = dateTime.hour;
    int minute = dateTime.minute;
    return '$hour:${minute < 10 ? '0$minute' : minute}';
  }

  String getTimeAbbr(DateTime dateTime) {
    int hour = dateTime.hour;
    return hour > 12 ? 'PM' : 'AM';
  }

  static const MethodChannel _channel = MethodChannel('main_channel');
}
