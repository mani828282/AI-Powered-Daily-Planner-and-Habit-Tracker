import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../config/theme.dart';
import '../../services/calendar_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarService _calendarService = CalendarService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<CalendarEvent> _allEvents = [];

  final Map<DateTime, List<CalendarEvent>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    if (!mounted) return;
    try {
      // Fetch all events from the new API
      final events = await _calendarService.getCalendarEvents();

      if (!mounted) return;
      setState(() {
        _allEvents = events;
        _buildEventMap();
      });
    } catch (e) {
      if (!mounted) return;
      // print('Error loading calendar data: $e');
    }
  }

  void _buildEventMap() {
    _events.clear();

    // Group all events by date
    for (var event in _allEvents) {
      final date = DateTime(event.date.year, event.date.month, event.date.day);
      _events[date] ??= [];
      _events[date]!.add(event);
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _events[normalized] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.backgroundLight, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Calendar',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            Text('Your schedule',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.today,
                            color: AppTheme.primaryColor),
                        onPressed: () {
                          if (!mounted) return;
                          setState(() {
                            _focusedDay = DateTime.now();
                            _selectedDay = DateTime.now();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE91E63).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: _getEventsForDay,
                    onDaySelected: (selectedDay, focusedDay) {
                      if (!mounted) return;
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle),
                      selectedDecoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Color(0xFF00BCD4), Color(0xFF00ACC1)]),
                        shape: BoxShape.circle,
                      ),
                      outsideDaysVisible: false,
                      cellMargin: EdgeInsets.all(4),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      headerPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    daysOfWeekHeight: 28,
                    rowHeight: 44,
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isEmpty) return null;
                        return Positioned(
                          bottom: 2,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: events.take(4).map((event) {
                              Color color = AppTheme.primaryColor;
                              if (event is CalendarEvent) {
                                switch (event.type) {
                                  case 'task':
                                    color = const Color(0xFFFF1744); // Red
                                    break;
                                  case 'habit':
                                    color = const Color(0xFF66BB6A); // Green
                                    break;
                                  case 'goal':
                                    color = const Color(0xFFFFB300); // Orange
                                    break;
                                  case 'mood':
                                    color = const Color(0xFF9C27B0); // Purple
                                    break;
                                }
                              }
                              return Container(
                                width: 5,
                                height: 5,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 0.5),
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegend('Tasks', const Color(0xFFFF1744)),
                    const SizedBox(width: 8),
                    _buildLegend('Habits', const Color(0xFF66BB6A)),
                    const SizedBox(width: 8),
                    _buildLegend('Goals', const Color(0xFFFFB300)),
                    const SizedBox(width: 8),
                    _buildLegend('Moods', const Color(0xFF9C27B0)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_selectedDay != null) _buildDayDetails(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDayDetails() {
    final events = _getEventsForDay(_selectedDay!);
    final tasks = events.where((e) => e.type == 'task').toList();
    final habits = events.where((e) => e.type == 'habit').toList();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFFF6F00)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selectedDay!.day} ${_getMonth(_selectedDay!.month)}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty && habits.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                  child: Text('No items for this day',
                      style: TextStyle(color: Colors.grey, fontSize: 13))),
            )
          else ...[
            if (tasks.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xFFFF1744), Color(0xFFD50000)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.task_alt,
                        color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Text('Tasks (${tasks.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              ...tasks.map((t) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF1744).withValues(alpha: 0.15),
                          const Color(0xFFFF5252).withValues(alpha: 0.1)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              const Color(0xFFFF1744).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: Color(0xFFFF1744), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(t.title ?? 'Task',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500))),
                      ],
                    ),
                  )),
            ],
            if (habits.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xFF66BB6A), Color(0xFF43A047)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.fitness_center,
                        color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Text('Habits (${habits.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              ...habits.map((h) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF66BB6A).withValues(alpha: 0.15),
                          const Color(0xFF81C784).withValues(alpha: 0.1)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              const Color(0xFF66BB6A).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: Color(0xFF66BB6A), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(h.title ?? 'Habit',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500))),
                      ],
                    ),
                  )),
            ],
          ],
        ],
      ),
    );
  }

  String _getMonth(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[m - 1];
  }
}
