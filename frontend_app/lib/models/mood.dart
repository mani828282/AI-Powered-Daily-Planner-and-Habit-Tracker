import 'dart:convert';

class Mood {
  final int? logId;
  final int userId;
  final DateTime logDate;
  final DateTime? logTime;
  final int moodLevel;
  final int energyLevel;
  final String? notes;
  final List<String>? activities;

  Mood({
    this.logId,
    required this.userId,
    required this.logDate,
    this.logTime,
    required this.moodLevel,
    required this.energyLevel,
    this.notes,
    this.activities,
  });

  factory Mood.fromJson(Map<String, dynamic> json) {
    // Handle activities - can be string (JSON) or list
    List<String>? activitiesList;
    if (json['activities'] != null) {
      if (json['activities'] is String) {
        // Parse JSON string
        try {
          final decoded = jsonDecode(json['activities']);
          activitiesList = List<String>.from(decoded);
        } catch (e) {
          activitiesList = null;
        }
      } else if (json['activities'] is List) {
        activitiesList = List<String>.from(json['activities']);
      }
    }

    return Mood(
      logId: json['log_id'] ?? json['mood_id'],
      userId: json['user_id'],
      logDate: DateTime.parse(json['log_date']),
      logTime:
          json['log_time'] != null ? DateTime.parse(json['log_time']) : null,
      moodLevel: json['mood_level'],
      energyLevel: json['energy_level'],
      notes: json['notes'],
      activities: activitiesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (logId != null) 'log_id': logId,
      'user_id': userId,
      'log_date': logDate.toIso8601String().split('T')[0],
      if (logTime != null) 'log_time': logTime!.toIso8601String(),
      'mood_level': moodLevel,
      'energy_level': energyLevel,
      if (notes != null) 'notes': notes,
      if (activities != null) 'activities': activities,
    };
  }
}
