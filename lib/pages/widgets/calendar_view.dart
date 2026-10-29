import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:minimalauncher/pages/right_screen.dart';

class CustomCalendarView extends StatefulWidget {
  final DateTime initialDate;
  final Color bgColor;
  final Color textColor;
  final String fontFamily;
  final List<Event> events;

  CustomCalendarView({
    Key? key,
    required this.initialDate,
    required this.bgColor,
    required this.textColor,
    required this.events,
    required this.fontFamily,
  }) : super(key: key);

  @override
  _CustomCalendarViewState createState() => _CustomCalendarViewState();
}

class _CustomCalendarViewState extends State<CustomCalendarView> {
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
  }

  void _goToPreviousMonth() {
    setState(() {
      selectedDate = DateTime(selectedDate.year, selectedDate.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      selectedDate = DateTime(selectedDate.year, selectedDate.month + 1);
    });
  }

  void _showEventsBottomSheet(DateTime date) {
    final eventsOnThisDay = widget.events
        .where((event) =>
            event.deadline.year == date.year &&
            event.deadline.month == date.month &&
            event.deadline.day == date.day)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.bgColor,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Events on ${DateFormat('MMM dd, yyyy').format(date)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: widget.fontFamily,
                    color: widget.textColor,
                  ),
                ),
                const SizedBox(height: 10),
                ...eventsOnThisDay.map((event) => ListTile(
                      title: Text(
                        event.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: widget.fontFamily,
                          color: widget.textColor,
                        ),
                      ),
                      subtitle: Text(
                        "${event.description}\n${_formatDate(event.deadline)}",
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: widget.fontFamily,
                          color: widget.textColor.withOpacity(0.7),
                        ),
                      ),
                    )),
                if (eventsOnThisDay.isEmpty)
                  const Text("No events for this day"),
              ],
            ),
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateUtils.getDaysInMonth(selectedDate.year, selectedDate.month);
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final startWeekday = firstDayOfMonth.weekday % 7;
    final monthName =
        "${DateFormat.MMM().format(selectedDate).toUpperCase()} '${DateFormat('yy').format(selectedDate)}";

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: widget.textColor.withOpacity(0.5),
                  size: 24,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _goToPreviousMonth();
                },
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    selectedDate = DateTime.now();
                  });
                },
                child: Text(
                  monthName,
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: widget.fontFamily,
                    fontWeight: FontWeight.w400,
                    color: widget.textColor,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: widget.textColor.withOpacity(0.5),
                  size: 24,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _goToNextMonth();
                },
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Days of the Week Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: widget.fontFamily,
                          color: widget.textColor.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 5),

          // Calendar Days
          Table(
            columnWidths: const {
              0: FractionColumnWidth(1 / 7),
              1: FractionColumnWidth(1 / 7),
              2: FractionColumnWidth(1 / 7),
              3: FractionColumnWidth(1 / 7),
              4: FractionColumnWidth(1 / 7),
              5: FractionColumnWidth(1 / 7),
              6: FractionColumnWidth(1 / 7),
            },
            children: _buildCalendarDays(daysInMonth, startWeekday),
          ),
        ],
      ),
    );
  }

  List<TableRow> _buildCalendarDays(int daysInMonth, int startWeekday) {
    List<TableRow> rows = [];
    List<Widget> days = List.generate(startWeekday, (index) => Container());
    final today = DateTime.now();

    for (int day = 1; day <= daysInMonth; day++) {
      final currentDate = DateTime(selectedDate.year, selectedDate.month, day);
      final hasEvent = widget.events.any((event) =>
          event.deadline.year == currentDate.year &&
          event.deadline.month == currentDate.month &&
          event.deadline.day == currentDate.day);
      final isToday = currentDate.year == today.year &&
          currentDate.month == today.month &&
          currentDate.day == today.day;

      days.add(
        GestureDetector(
          onTap: hasEvent ? () => _showEventsBottomSheet(currentDate) : null,
          child: SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 2,
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isToday
                          ? Border.all(color: widget.textColor, width: 1.5)
                          : null,
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 17,
                        fontFamily: widget.fontFamily,
                        color: widget.textColor,
                      ),
                    ),
                  ),
                ),
                if (hasEvent)
                  Positioned(
                    bottom: 1,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: widget.textColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

      if (days.length == 7 || day == daysInMonth) {
        if (days.length < 7) {
          days.addAll(List.generate(7 - days.length, (index) => Container()));
        }
        rows.add(TableRow(children: days));
        days = [];
      }
    }

    return rows;
  }
}
