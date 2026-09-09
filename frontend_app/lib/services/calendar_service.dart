import 'api_service.dart';

class CalendarEvent {
  final String type; // 'task', 'habit', 'goal', 'mood'
  final DateTime date;
  final String? title;
  final String? status;
  final String? category;
  final String? priority;
  final String? moodLevel;
  final int? energyLevel;
  final String? notes;
  final int? id;

  CalendarEvent({
    required this.type,
    required this.date,
    this.title,
    this.status,
    this.category,
    this.priority,
    this.moodLevel,
    this.energyLevel,
    this.notes,
    this.id,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      type: json['type'],
      date: DateTime.parse(json['date']),
      title: json['title'],
      status: json['status'],
      category: json['category'],
      priority: json['priority'],
      moodLevel: json['mood_level'],
      energyLevel: json['energy_level'],
      notes: json['notes'],
      id: json['id'],
    );
  }
}

class CalendarService {
  final ApiService _apiService = ApiService();

  Future<List<CalendarEvent>> getCalendarEvents({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 365));
      final end = endDate ?? DateTime.now().add(const Duration(days: 365));

      final response = await _apiService.get(
        '/api/calendar/events?start_date=${start.toIso8601String().split('T')[0]}&end_date=${end.toIso8601String().split('T')[0]}',
      );

      final List<dynamic> eventsJson = response['events'];
      return eventsJson.map((json) => CalendarEvent.fromJson(json)).toList();
    } catch (e) {
      // print('Error fetching calendar events: $e');
      rethrow;
    }
  }
}
