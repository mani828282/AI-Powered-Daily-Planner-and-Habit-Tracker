class Goal {
  final int? goalId;
  final int userId;
  final String title;
  final String? description;
  final String? category;
  final DateTime? targetDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final double progressPercentage;
  final bool aiDecomposed;
  final DateTime createdAt;
  final List<Subtask>? subtasks;
  // Progress tracking fields
  final int totalSubtasks;
  final int completedSubtasks;
  final String statusIndicator; // on_track, falling_behind, ahead
  final int? estimatedDaysRemaining;

  Goal({
    this.goalId,
    required this.userId,
    required this.title,
    this.description,
    this.category,
    this.targetDate,
    this.startDate,
    this.endDate,
    this.status = 'active',
    this.progressPercentage = 0.0,
    this.aiDecomposed = false,
    required this.createdAt,
    this.subtasks,
    this.totalSubtasks = 0,
    this.completedSubtasks = 0,
    this.statusIndicator = 'on_track',
    this.estimatedDaysRemaining,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      goalId: json['goal_id'],
      userId: json['user_id'] ?? 0,
      title: json['title'] ?? 'Untitled Goal',
      description: json['description'],
      category: json['category'],
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'])
          : null,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : null,
      status: json['status'] ?? 'active',
      progressPercentage: (json['progress_percentage'] ?? 0.0).toDouble(),
      aiDecomposed: json['ai_decomposed'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      subtasks: json['subtasks'] != null
          ? (json['subtasks'] as List).map((s) => Subtask.fromJson(s)).toList()
          : [],
      totalSubtasks: json['total_subtasks'] ?? 0,
      completedSubtasks: json['completed_subtasks'] ?? 0,
      statusIndicator: json['status_indicator'] ?? 'on_track',
      estimatedDaysRemaining: json['estimated_days_remaining'],
    );
  }
}

class Subtask {
  final int? subtaskId;
  final int goalId;
  final String title;
  final String? description;
  final int orderIndex;
  final bool completed;
  final DateTime? dueDate;

  Subtask({
    this.subtaskId,
    required this.goalId,
    required this.title,
    this.description,
    this.orderIndex = 0,
    this.completed = false,
    this.dueDate,
  });

  factory Subtask.fromJson(Map<String, dynamic> json) {
    return Subtask(
      subtaskId: json['subtask_id'],
      goalId: json['goal_id'] ?? 0,
      title: json['title'] ?? 'Untitled Subtask',
      description: json['description'],
      orderIndex: json['order_index'] ?? 0,
      completed: json['completed'] == 1 || json['completed'] == true,
      dueDate:
          json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
    );
  }
}
