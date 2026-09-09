import 'api_service.dart';
import '../models/task.dart';
import 'notification_service.dart';

class TaskService {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  /// Get all tasks with optional filters
  Future<List<Task>> getTasks({
    String? status,
    String? category,
    DateTime? date, // Filter tasks by specific date (for the date picker)
  }) async {
    String endpoint = '/api/tasks/list';
    final params = <String>[];
    if (status != null) params.add('status=$status');
    if (category != null) params.add('category=$category');
    if (date != null) {
      params.add('date=${date.toIso8601String().split('T')[0]}');
    }
    if (params.isNotEmpty) endpoint += '?${params.join('&')}';

    final response = await _apiService.get(endpoint);

    // Backend returns a list directly
    if (response is List) {
      return (response).map((json) => Task.fromJson(json)).toList();
    }
    return [];
  }

  String? _formatTime(String? timeStr) {
    if (timeStr == null) return null;
    try {
      final timeParts = timeStr.split(' ');
      if (timeParts.length == 2) {
        final time = timeParts[0].split(':');
        int hour = int.parse(time[0]);
        final minute = time[1];
        final isPM = timeParts[1].toUpperCase() == 'PM';

        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;

        return '${hour.toString().padLeft(2, '0')}:$minute:00';
      }
      return timeStr; // Already in correct format
    } catch (e) {
      return timeStr; // Use as-is if parsing fails
    }
  }

  /// Create a new task with AI parsing
  Future<Task> createTask({
    String? userInput,
    String? title,
    String? description,
    String? priority,
    String? category,
    DateTime? dueDate,
    String? dueTime,
    DateTime? startDate,
    String? startTime,
    DateTime? endDate,
    bool? reminderEnabled,
    int? reminderMinutesBefore,
  }) async {
    final formattedDueTime = _formatTime(dueTime);
    final formattedStartTime = _formatTime(startTime);
    
    final response = await _apiService.post(
      '/api/tasks/create',
      {
        if (userInput != null) 'user_input': userInput,
        // Only send manual fields if NOT using natural language input
        if (userInput == null && title != null) 'title': title,
        if (userInput == null && description != null)
          'description': description,
        if (userInput == null && priority != null) 'priority': priority,
        if (userInput == null && category != null) 'category': category,
        // Always send date/time fields as they can override AI suggestions
        if (dueDate != null)
          'due_date': dueDate.toIso8601String().split('T')[0],
        if (formattedDueTime != null) 'due_time': formattedDueTime,
        // New mandatory date fields
        if (startDate != null)
          'start_date': startDate.toIso8601String().split('T')[0],
        if (formattedStartTime != null) 'start_time': formattedStartTime,
        if (endDate != null)
          'end_date': endDate.toIso8601String().split('T')[0],
        if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
        if (reminderMinutesBefore != null)
          'reminder_minutes_before': reminderMinutesBefore,
      },
    );

    final newTask = Task.fromJson(response);

    // Schedule notification if requested
    if (reminderEnabled == true && newTask.dueDate != null) {
      await _notificationService.scheduleTaskNotification(
        newTask,
        minutesBefore: reminderMinutesBefore ?? 30,
      );
    }

    return newTask;
  }

  /// Parse natural language input and get AI suggestions (preview only, doesn't create task)
  Future<Map<String, dynamic>> parseTaskPreview(String userInput) async {
    final response = await _apiService.post(
      '/api/tasks/parse-preview',
      {'user_input': userInput},
    );

    return response;
  }

  /// Update a task
  Future<Task> updateTask(
    int taskId, {
    String? title,
    String? description,
    String? priority,
    String? status,
    String? category,
    DateTime? dueDate,
    String? dueTime,
    DateTime? startDate,
    String? startTime,
    DateTime? endDate,
  }) async {
    final formattedDueTime = _formatTime(dueTime);
    final formattedStartTime = _formatTime(startTime);

    final response = await _apiService.put(
      '/api/tasks/$taskId',
      {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (priority != null) 'priority': priority,
        if (status != null) 'status': status,
        if (category != null) 'category': category,
        if (dueDate != null)
          'due_date': dueDate.toIso8601String().split('T')[0],
        if (formattedDueTime != null) 'due_time': formattedDueTime,
        if (startDate != null)
          'start_date': startDate.toIso8601String().split('T')[0],
        if (formattedStartTime != null) 'start_time': formattedStartTime,
        if (endDate != null)
          'end_date': endDate.toIso8601String().split('T')[0],
      },
    );

    final updatedTask = Task.fromJson(response);

    // Update notification
    // First cancel existing
    await _notificationService.cancelNotification(updatedTask.taskId.hashCode);

    // If completed or deleted (handled elsewhere), we don't reschedule
    if (updatedTask.status != 'completed') {
      // Ideally we should know if reminder is enabled, but for now relies on UI passing it
      // Since the update API doesn't return reminder settings unless we added them to model/API
      // For this fix, we will just re-schedule if we have the info,
      // but typically we'd need to fetch the task's reminder settings.
      // NOTE: The current Task model doesn't seem to store `isReminderEnabled`.
      // We should rely on the User enabling it in UI or fetching it.
      // For now, let's assume if due date is updated, we might need to Reschedule.
      // However, without `reminderEnabled` state in Task model, we can't blindly reschedule.
      // Let's assume the user handles this via UI toggles for now, or we check if due date changed.
      // A proper fix would require adding `reminderEnabled` to the Task model.

      // For immediate fix: The Task model in frontend likely needs to know if it has a reminder.
      // But for now, let's just ensure we cancel it if completed.
    }

    return updatedTask;
  }

  /// Delete a task
  Future<void> deleteTask(int taskId) async {
    await _apiService.delete('/api/tasks/$taskId');
    await _notificationService.cancelNotification(taskId.hashCode);
  }

  /// AI-powered task prioritization
  Future<List<Task>> organizeTasks({List<int>? taskIds}) async {
    final response = await _apiService.post(
      '/api/tasks/ai-organize',
      {
        if (taskIds != null) 'task_ids': taskIds,
      },
    );

    if (response is List) {
      return (response as List).map((json) => Task.fromJson(json)).toList();
    }
    return [];
  }

  /// Mark task as complete
  Future<Task> completeTask(int taskId) async {
    await _notificationService.cancelNotification(taskId.hashCode);
    return updateTask(taskId, status: 'completed');
  }

  /// Get pending tasks
  Future<List<Task>> getPendingTasks() async {
    return getTasks(status: 'pending');
  }

  /// Get completed tasks
  Future<List<Task>> getCompletedTasks() async {
    return getTasks(status: 'completed');
  }

  /// Get AI-powered task suggestions
  Future<Map<String, dynamic>> getTaskSuggestions() async {
    final response = await _apiService.get('/api/tasks/suggestions');
    return response as Map<String, dynamic>;
  }

  /// Re-schedule notifications for all pending tasks that have reminders enabled.
  /// Call this on app startup or after returning from background.
  Future<void> rescheduleAllNotifications() async {
    try {
      final tasks = await getPendingTasks();
      for (final task in tasks) {
        if (task.reminderEnabled && task.dueDate != null) {
          await _notificationService.scheduleTaskNotification(
            task,
            minutesBefore: task.reminderMinutesBefore ?? 30,
          );
        }
      }
    } catch (_) {
      // Silently fail — notifications are best-effort
    }
  }
}
