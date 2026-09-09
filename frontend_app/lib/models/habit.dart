class Habit {
  final int habitId;
  final int userId;
  final String name;
  final String? description;
  final String? category;
  final String frequency;
  final Map<String, dynamic>? frequencyDetails;
  final int currentStreak;
  final int longestStreak;
  final int totalCompletions;
  final bool reminderEnabled;
  final String? reminderTime;
  final int targetCount;
  final bool aiSuggested;
  final String? icon;
  final String? color;
  final DateTime createdAt;
  final bool completedToday;

  Habit({
    required this.habitId,
    required this.userId,
    required this.name,
    this.description,
    this.category,
    required this.frequency,
    this.frequencyDetails,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalCompletions,
    this.reminderEnabled = false,
    this.reminderTime,
    this.targetCount = 1,
    required this.aiSuggested,
    this.icon,
    this.color,
    required this.createdAt,
    this.completedToday = false,
  });

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      habitId: json['habit_id'],
      userId: json['user_id'],
      name: json['name'],
      description: json['description'],
      category: json['category'],
      frequency: json['frequency'],
      frequencyDetails: json['frequency_details'],
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] ?? 0,
      totalCompletions: json['total_completions'] ?? 0,
      reminderEnabled: json['reminder_enabled'] ?? false,
      reminderTime: json['reminder_time'],
      targetCount: json['target_count'] ?? 1,
      aiSuggested: json['ai_suggested'] ?? false,
      icon: json['icon'],
      color: json['color'],
      createdAt: DateTime.parse(json['created_at']),
      completedToday:
          json['completed_today'] == 1 || json['completed_today'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'habit_id': habitId,
      'user_id': userId,
      'name': name,
      'description': description,
      'category': category,
      'frequency': frequency,
      'frequency_details': frequencyDetails,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'total_completions': totalCompletions,
      'reminder_enabled': reminderEnabled,
      'reminder_time': reminderTime,
      'target_count': targetCount,
      'ai_suggested': aiSuggested,
      'created_at': createdAt.toIso8601String(),
      'completed_today': completedToday,
    };
  }
}
