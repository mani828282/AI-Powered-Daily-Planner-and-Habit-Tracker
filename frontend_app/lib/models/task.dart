class Task {
  final int taskId;
  final int userId;
  final String title;
  final String? description;
  final String priority;
  final String status;
  final String? category;
  final DateTime? dueDate;
  final String? dueTime;
  final DateTime? startDate;
  final String? startTime;
  final DateTime? endDate;
  final bool reminderEnabled;
  final int? reminderMinutesBefore;
  final bool aiGenerated;
  final double? aiPriorityScore;
  final DateTime createdAt;

  Task({
    required this.taskId,
    required this.userId,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    this.category,
    this.dueDate,
    this.dueTime,
    this.startDate,
    this.startTime,
    this.endDate,
    this.reminderEnabled = false,
    this.reminderMinutesBefore,
    required this.aiGenerated,
    this.aiPriorityScore,
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert to string
    String? safeString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is List) {
        return value.isNotEmpty ? value.first.toString() : null;
      }
      return value.toString();
    }

    return Task(
      taskId: json['task_id'],
      userId: json['user_id'],
      title: safeString(json['title']) ?? '',
      description: safeString(json['description']),
      priority: safeString(json['priority']) ?? 'medium',
      status: safeString(json['status']) ?? 'pending',
      category: safeString(json['category']),
      dueDate:
          json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      dueTime: safeString(json['due_time']),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      startTime: safeString(json['start_time']),
      endDate:
          json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      reminderEnabled:
          json['reminder_enabled'] == true || json['reminder_enabled'] == 1,
      reminderMinutesBefore: json['reminder_minutes_before'] is int
          ? json['reminder_minutes_before']
          : (json['reminder_minutes_before'] != null
              ? int.tryParse(json['reminder_minutes_before'].toString())
              : null),
      aiGenerated: json['ai_generated'] == true || json['ai_generated'] == 1,
      aiPriorityScore: json['ai_priority_score']?.toDouble(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'user_id': userId,
      'title': title,
      'description': description,
      'priority': priority,
      'status': status,
      'category': category,
      'due_date': dueDate?.toIso8601String(),
      'due_time': dueTime,
      'start_date': startDate?.toIso8601String(),
      'start_time': startTime,
      'end_date': endDate?.toIso8601String(),
      'reminder_enabled': reminderEnabled,
      'reminder_minutes_before': reminderMinutesBefore,
      'ai_generated': aiGenerated,
      'ai_priority_score': aiPriorityScore,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
