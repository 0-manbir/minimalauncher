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
        showOnHomeScreen: json['showOnHomeScreen'] as bool? ?? false,
        isCompleted: json['isCompleted'] as bool? ?? false,
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
  bool showEventsOnHomeScreen = true;
  bool is24HourFormat = false;

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
      showEventsOnHomeScreen =
          prefs.getBool(prefsShowEventsOnHomeScreen) ?? true;
      is24HourFormat = prefs.getBool(prefsIs24HourFormat) ?? false;
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
    await prefs.setStringList('events', eventList);
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

  Future<void> _addEvent(Event event) async {
    setState(() {
      _events.add(event);
    });
    if (event.deadline.isAfter(DateTime.now())) {
      _scheduleAlarm(event);
    }
    await _saveEvents();
  }

  Future<void> _deleteEvent(Event event) async {
    setState(() {
      _events.remove(event);
    });
    _cancelAlarm(event);
    await _saveEvents();
  }

  Future<void> _toggleComplete(Event event) async {
    setState(() {
      event.isCompleted = !event.isCompleted;
    });
    await _saveEvents();
  }

  String _formatDate(DateTime dateTime) {
    final time = is24HourFormat
        ? DateFormat.Hm().format(dateTime)
        : DateFormat.jm().format(dateTime);

    String date;
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    if (DateUtils.isSameDay(dateTime, today)) {
      date = 'Today';
    } else if (DateUtils.isSameDay(dateTime, tomorrow)) {
      date = 'Tomorrow';
    } else {
      date = DateFormat('EEE, MMM d').format(dateTime);
    }

    return '$date • $time';
  }

  void showAddEventDialog(DateTime deadline) {
    String name = '';
    String description = '';
    bool showOnHomeScreen = showEventsOnHomeScreen;

    showModalBottomSheet(
      context: context,
      backgroundColor: showWallpaper ? Colors.transparent : selectedColor,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final dialogTextColor = textColor;
            final dialogBackground =
                showWallpaper ? Colors.transparent : selectedColor;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                top: 12,
                right: 20,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: dialogTextColor.withAlpha(100),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Text(
                      'New event',
                      style: TextStyle(
                        color: dialogTextColor,
                        fontFamily: fontNormal,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      autofocus: true,
                      cursorColor: dialogTextColor,
                      style: TextStyle(
                        color: dialogTextColor,
                        fontFamily: fontNormal,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Event name',
                        labelStyle: TextStyle(color: dialogTextColor),
                        prefixIcon: Icon(
                          Icons.event_note_rounded,
                          color: dialogTextColor,
                        ),
                      ),
                      onChanged: (value) => setState(() => name = value),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      cursorColor: dialogTextColor,
                      style: TextStyle(
                        color: dialogTextColor,
                        fontFamily: fontNormal,
                      ),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Notes (optional)',
                        alignLabelWithHint: true,
                        labelStyle: TextStyle(color: dialogTextColor),
                        prefixIcon: Icon(
                          Icons.notes_rounded,
                          color: dialogTextColor,
                        ),
                      ),
                      onChanged: (value) => setState(() => description = value),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: dialogTextColor.withAlpha(15),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.calendar_month_rounded,
                              color: dialogTextColor,
                            ),
                            title: Text(
                              'Date',
                              style: TextStyle(
                                color: dialogTextColor.withAlpha(160),
                                fontFamily: fontNormal,
                                fontSize: 12,
                              ),
                            ),
                            subtitle: Text(
                              DateFormat('EEEE, MMM d, y').format(deadline),
                              style: TextStyle(
                                color: dialogTextColor,
                                fontFamily: fontNormal,
                              ),
                            ),
                            trailing: const Icon(Icons.edit_calendar_rounded),
                            onTap: () async {
                              final selectedDate = await showDatePicker(
                                context: context,
                                initialDate: deadline,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 3650)),
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
                          const Divider(height: 1, indent: 64),
                          ListTile(
                            leading: Icon(
                              Icons.access_time_rounded,
                              color: dialogTextColor,
                            ),
                            title: Text(
                              'Time',
                              style: TextStyle(
                                color: dialogTextColor.withAlpha(160),
                                fontFamily: fontNormal,
                                fontSize: 12,
                              ),
                            ),
                            subtitle: Text(
                              TimeOfDay.fromDateTime(deadline).format(context),
                              style: TextStyle(
                                color: dialogTextColor,
                                fontFamily: fontNormal,
                              ),
                            ),
                            trailing: const Icon(Icons.edit_rounded),
                            onTap: () async {
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
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Show on home screen',
                        style: TextStyle(
                          color: dialogTextColor,
                          fontFamily: fontNormal,
                        ),
                      ),
                      subtitle: Text(
                        'Also show this event below the clock.',
                        style: TextStyle(
                          color: dialogTextColor.withAlpha(160),
                          fontFamily: fontNormal,
                          fontSize: 12,
                        ),
                      ),
                      value: showOnHomeScreen,
                      activeThumbColor: dialogTextColor,
                      onChanged: (value) =>
                          setState(() => showOnHomeScreen = value),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: name.trim().isEmpty
                            ? null
                            : () async {
                                await _addEvent(
                                  Event(
                                    name: name.trim(),
                                    description: description.trim(),
                                    deadline: deadline,
                                    showOnHomeScreen: showOnHomeScreen,
                                  ),
                                );
                                if (context.mounted) Navigator.pop(context);
                              },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Save event'),
                        style: FilledButton.styleFrom(
                          foregroundColor:
                              dialogBackground == Colors.transparent
                                  ? selectedColor
                                  : dialogBackground,
                          backgroundColor: dialogTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEventDetails(Event event) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: showWallpaper ? Colors.transparent : selectedColor,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: textColor.withAlpha(100),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                event.name,
                style: TextStyle(
                  color: textColor,
                  fontFamily: fontNormal,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(event.deadline),
                style: TextStyle(
                  color: textColor.withAlpha(180),
                  fontFamily: fontNormal,
                ),
              ),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  event.description,
                  style: TextStyle(color: textColor, fontFamily: fontNormal),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await _toggleComplete(event);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: Icon(
                  event.isCompleted
                      ? Icons.undo_rounded
                      : Icons.check_circle_outline_rounded,
                ),
                label: Text(
                  event.isCompleted ? 'Mark as open' : 'Mark as completed',
                ),
                style: FilledButton.styleFrom(
                  foregroundColor: selectedColor,
                  backgroundColor: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventSectionTitle(String title, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontFamily: fontNormal,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: TextStyle(
                color: textColor.withAlpha(150),
                fontFamily: fontNormal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );

  Widget _eventCard(Event event) {
    final cardColor = showWallpaper
        ? textColor.withAlpha(18)
        : Color.alphaBlend(textColor.withAlpha(12), selectedColor);
    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: () => _showEventDetails(event),
        leading: IconButton(
          tooltip: event.isCompleted ? 'Mark as open' : 'Mark as completed',
          onPressed: () => _toggleComplete(event),
          icon: Icon(
            event.isCompleted
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: event.isCompleted ? Colors.green : textColor,
          ),
        ),
        title: Text(
          event.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontFamily: fontNormal,
            decoration: event.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(event.deadline),
                style: TextStyle(
                  color: textColor.withAlpha(180),
                  fontFamily: fontNormal,
                  fontSize: 12,
                ),
              ),
              if (event.description.isNotEmpty)
                Text(
                  event.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withAlpha(150),
                    fontFamily: fontNormal,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          iconColor: textColor,
          onSelected: (action) {
            if (action == 'delete') _deleteEvent(event);
            if (action == 'toggle') _toggleComplete(event);
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(
                event.isCompleted ? 'Reopen event' : 'Complete event',
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete event'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openEvents = _events.where((event) => !event.isCompleted).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    final completedEvents = _events.where((event) => event.isCompleted).toList()
      ..sort((a, b) => b.deadline.compareTo(a.deadline));

    return Scaffold(
      backgroundColor: showWallpaper ? Colors.transparent : selectedColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            calendar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your events',
                      style: TextStyle(
                        color: textColor,
                        fontFamily: fontNormal,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${_events.length}',
                    style: TextStyle(
                      color: textColor.withAlpha(160),
                      fontFamily: fontNormal,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _events.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_available_rounded,
                              color: textColor.withAlpha(150),
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your calendar is clear',
                              style: TextStyle(
                                color: textColor,
                                fontFamily: fontNormal,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add an event to keep track of what’s next.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor.withAlpha(160),
                                fontFamily: fontNormal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                      children: [
                        if (openEvents.isNotEmpty) ...[
                          _eventSectionTitle('To do', openEvents.length),
                          ...openEvents.map(_eventCard),
                        ],
                        if (completedEvents.isNotEmpty) ...[
                          _eventSectionTitle(
                            'Completed',
                            completedEvents.length,
                          ),
                          ...completedEvents.map(_eventCard),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddEventDialog(DateTime.now()),
        backgroundColor: textColor,
        foregroundColor: selectedColor,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'New event',
          style: TextStyle(fontFamily: fontNormal),
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
