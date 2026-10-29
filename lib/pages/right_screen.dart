import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:minimalauncher/variables/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:minimalauncher/pages/widgets/calendar_view.dart';
import 'dart:convert';

class Event {
  String name;
  String description;
  DateTime deadline;
  bool showOnHomeScreen;
  bool isCompleted;

  Event({
    required this.name,
    required this.description,
    required this.deadline,
    this.showOnHomeScreen = false,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'deadline': deadline.toIso8601String(),
        'showOnHomeScreen': showOnHomeScreen,
        'isCompleted': isCompleted,
      };

  static Event fromJson(Map<String, dynamic> json) => Event(
        name: json['name'],
        description: json['description'],
        deadline: DateTime.parse(json['deadline']),
        showOnHomeScreen: json['showOnHomeScreen'],
        isCompleted: json['isCompleted'],
      );
}

class RightScreen extends StatefulWidget {
  const RightScreen({super.key});

  @override
  RightScreenState createState() => RightScreenState();
}

class RightScreenState extends State<RightScreen> {
  List<Event> _events = [];
  Color selectedColor = Colors.transparent;
  Color textColor = Colors.transparent;
  bool showWallpaper = false;

  @override
  void initState() {
    _loadPreferences();
    _loadEvents();
    super.initState();
  }

  _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      int? colorValue = prefs.getInt(prefsSelectedColor);
      if (colorValue != null) {
        selectedColor = Color(colorValue);
      }
      int? textColorValue = prefs.getInt(prefsTextColor);
      if (textColorValue != null) {
        textColor = Color(textColorValue);
      }
      showWallpaper = prefs.getBool(prefsShowWallpaper) ?? false;
    });
  }

  void refresh() {
    _loadPreferences();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventList = prefs.getStringList('events') ?? [];
    if (!mounted) return;
    setState(() {
      _events = eventList.map((e) => Event.fromJson(json.decode(e))).toList();
    });
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();

    // Sort events by deadline (ascending), so closest deadlines come first
    _events.sort((a, b) => a.deadline.compareTo(b.deadline));

    // Convert sorted events to JSON and save to SharedPreferences
    final eventList = _events.map((e) => json.encode(e.toJson())).toList();
    prefs.setStringList('events', eventList);
  }

  void _scheduleAlarm(Event event) async {
    final alarmId = event.name.hashCode;

    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: event.deadline,
      assetAudioPath: 'assets/notification.mp3',
      loopAudio: false,
      vibrate: true,
      fadeDuration: 1.0,
      androidFullScreenIntent: true,
      notificationSettings: NotificationSettings(
        title: event.name,
        body: event.description,
        stopButton: 'Mark as done',
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);
  }

  void _cancelAlarm(Event event) async {
    final alarmId = event.name.hashCode;
    await Alarm.stop(alarmId);
  }

  void _addEvent(Event event) {
    setState(() {
      _events.add(event);
    });
    _scheduleAlarm(event);
    _saveEvents();
  }

  void _deleteEvent(Event event) {
    setState(() {
      _events.remove(event);
    });
    _cancelAlarm(event);
    _saveEvents();
  }

  void _toggleComplete(Event event) {
    setState(() {
      event.isCompleted = !event.isCompleted;
    });
    _saveEvents();
  }

  String _formatDate(DateTime dateTime) {
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

  void showAddEventDialog(DateTime deadline) {
    // Move the variables outside the builder to retain their values
    String name = '';
    String description = '';
    bool showOnHomeScreen = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: showWallpaper ? Colors.transparent : selectedColor,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 32.0),
                  Text(
                    'Add Event',
                    style: TextStyle(
                      color: textColor,
                      fontFamily: fontNormal,
                      fontSize: 24.0,
                    ),
                  ),
                  TextField(
                    autofocus: true,
                    cursorColor: textColor,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: fontNormal,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Event Name',
                      labelStyle: TextStyle(
                        color: textColor,
                        fontFamily: fontNormal,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        name = value;
                      });
                    },
                  ),
                  TextField(
                    cursorColor: textColor,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: fontNormal,
                    ),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      labelStyle: TextStyle(
                        color: textColor,
                        fontFamily: fontNormal,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        description = value;
                      });
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Deadline:  ${_formatDate(deadline)}',
                          style: TextStyle(
                            color: textColor,
                            fontFamily: fontNormal,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.calendar_month_rounded,
                            color: textColor),
                        onPressed: () async {
                          final selectedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 365)),
                          );
                          if (selectedDate != null) {
                            setState(() {
                              deadline = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                deadline.hour,
                                deadline.minute,
                              );
                            });
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.access_time_rounded, color: textColor),
                        onPressed: () async {
                          final selectedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(deadline),
                          );
                          if (selectedTime != null) {
                            setState(() {
                              deadline = DateTime(
                                deadline.year,
                                deadline.month,
                                deadline.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Show on Home Screen',
                        style: TextStyle(
                          color: textColor,
                          fontFamily: fontNormal,
                        ),
                      ),
                      Switch(
                        value: showOnHomeScreen,
                        onChanged: (value) {
                          setState(() {
                            showOnHomeScreen = value;
                          });
                        },
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final newEvent = Event(
                        name: name,
                        description: description,
                        deadline: deadline,
                        showOnHomeScreen: showOnHomeScreen,
                      );
                      _addEvent(newEvent);
                      Navigator.pop(context);
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(textColor),
                    ),
                    child: Text(
                      'Add Event',
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: showWallpaper ? Colors.transparent : selectedColor,
      body: Column(
        children: [
          SizedBox(height: 16.0),
          calendar(),
          _events.isEmpty
              ? Expanded(
                  child: Center(
                    child: Text(
                      'No events added yet.',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24.0,
                        fontFamily: fontNormal,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Text(
                      "Events",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18.0,
                        fontWeight: FontWeight.w500,
                        fontFamily: fontNormal,
                      ),
                    ),
                    SizedBox(height: 16.0),
                    ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.all(16.0),
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        return Container(
                          margin: EdgeInsets.symmetric(
                              vertical: 8.0), // Adds spacing between list items
                          decoration: BoxDecoration(
                            color: textColor.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  16.0), // Ensure the ListTile matches the container radius
                            ),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: showWallpaper
                                    ? Colors.transparent
                                    : selectedColor,
                                builder: (context) {
                                  return Container(
                                    color: showWallpaper
                                        ? Colors.transparent
                                        : selectedColor,
                                    child: Column(
                                      children: [
                                        SizedBox(height: 16.0),
                                        Text(
                                          "Task Description: ",
                                          style: TextStyle(
                                            color: textColor,
                                            fontFamily: fontNormal,
                                            fontSize: 26.0,
                                          ),
                                        ),
                                        ListTile(
                                          title: Text(
                                            event.description,
                                            style: TextStyle(
                                              color: textColor,
                                              fontFamily: fontNormal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                            title: Text(
                              event.name,
                              style: TextStyle(
                                color: textColor,
                                fontFamily: fontNormal,
                                fontSize: 18.0,
                                decoration: event.isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                            subtitle: Text(
                              _formatDate(event.deadline),
                              style: TextStyle(
                                color: textColor,
                                fontFamily: fontNormal,
                                fontSize: 12.0,
                                decoration:
                                    event.deadline.isBefore(DateTime.now())
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.delete, color: textColor),
                                  onPressed: () => _deleteEvent(event),
                                ),
                                IconButton(
                                  icon: Icon(
                                    event.isCompleted
                                        ? Icons.check_rounded
                                        : Icons.close_rounded,
                                    size: 28.0,
                                    color: event.isCompleted
                                        ? Colors.green[300]
                                        : Colors.red[300],
                                  ),
                                  onPressed: () => _toggleComplete(event),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
        ],
      ),
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width * 0.4,
        child: FloatingActionButton.extended(
          onPressed: () {
            showAddEventDialog(DateTime.now());
          },
          backgroundColor: textColor,
          icon: Icon(
            Icons.add_rounded,
            color: selectedColor,
          ),
          label: Text(
            'Add Event',
            style: TextStyle(
              color: selectedColor,
              fontFamily: fontNormal,
            ),
          ),
        ),
      ),
    );
  }

  Widget calendar() {
    return CustomCalendarView(
      initialDate: DateTime.now(),
      bgColor: showWallpaper ? Colors.transparent : selectedColor,
      textColor: textColor.withAlpha(204),
      fontFamily: fontNormal,
      events: _events,
    );
  }
}
