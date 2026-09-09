import 'package:flutter/material.dart';
import 'api_service.dart';
import '../models/habit.dart';
import 'notification_service.dart';

class HabitService {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  /// Get all habits
  Future<List<Habit>> getHabits() async {
    final response = await _apiService.get('/api/habits/list');
    if (response is List) {
      return (response).map((json) => Habit.fromJson(json)).toList();
    }
    return [];
  }

  /// Create a new habit with AI structuring
  Future<Habit> createHabit({
    required String name,
    String? description,
    String? category,
    String frequency = 'daily',
    Map<String, dynamic>? frequencyDetails,
    int targetCount = 1,
    bool? reminderEnabled,
    TimeOfDay? reminderTime,
  }) async {
    // Convert TimeOfDay to HH:MM:SS format
    String? formattedTime;
    if (reminderTime != null) {
      final hour = reminderTime.hour.toString().padLeft(2, '0');
      final minute = reminderTime.minute.toString().padLeft(2, '0');
      formattedTime = '$hour:$minute:00';
    }
    final response = await _apiService.post(
      '/api/habits/create',
      {
        'name': name,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        'frequency': frequency,
        if (frequencyDetails != null) 'frequency_details': frequencyDetails,
        'target_count': targetCount,
        if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
        if (formattedTime != null) 'reminder_time': formattedTime,
      },
    );

    final newHabit = Habit.fromJson(response);

    // Schedule notification if requested
    if (reminderEnabled == true && reminderTime != null) {
      // Need to convert TimeOfDay to DateTime for the service
      final now = DateTime.now();
      final dt = DateTime(
          now.year, now.month, now.day, reminderTime.hour, reminderTime.minute);

      // Convert stored frequency details (json map) back to List<String> if it exists
      List<String>? customDays;
      if (newHabit.frequency == 'custom' && response['frequency_details'] != null) {
         try {
           final details = response['frequency_details'] as Map<String, dynamic>;
           if (details['days'] is List) {
             customDays = List<String>.from(details['days']);
           }
         } catch (_) {}
      }

      await _notificationService.scheduleHabitReminder(newHabit, dt, customDays: customDays);
    }

    return newHabit;
  }

  /// Mark habit as completed
  Future<Map<String, dynamic>> completeHabit({
    required int habitId,
    DateTime? completionDate,
    String? notes,
    int? moodAtCompletion,
  }) async {
    final response = await _apiService.post(
      '/api/habits/complete',
      {
        'habit_id': habitId,
        if (completionDate != null)
          'completion_date': completionDate.toIso8601String().split('T')[0],
        if (notes != null) 'notes': notes,
        if (moodAtCompletion != null) 'mood_at_completion': moodAtCompletion,
      },
    );

    return response;
  }

  /// Get habit streaks
  Future<List<Map<String, dynamic>>> getStreaks() async {
    final response = await _apiService.get('/api/habits/streaks');
    // Response is a Map, extract the streaks list if it exists
    if (response['streaks'] is List) {
      return (response['streaks'] as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }
    return [];
  }

  /// Get AI habit suggestions
  Future<List<dynamic>> getSuggestedHabits() async {
    final response = await _apiService.post('/api/ai/suggest-habits', {});
    return response['suggestions'] ?? [];
  }

  /// Update an existing habit
  Future<Habit> updateHabit(
    int habitId, {
    String? name,
    String? description,
    String? category,
    String? frequency,
    Map<String, dynamic>? frequencyDetails,
    int? targetCount,
    bool? reminderEnabled,
    TimeOfDay? reminderTime,
  }) async {
    String? formattedTime;
    if (reminderTime != null) {
      final hour = reminderTime.hour.toString().padLeft(2, '0');
      final minute = reminderTime.minute.toString().padLeft(2, '0');
      formattedTime = '$hour:$minute:00';
    }
    final response = await _apiService.put(
      '/api/habits/$habitId',
      {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (frequency != null) 'frequency': frequency,
        if (frequencyDetails != null) 'frequency_details': frequencyDetails,
        if (targetCount != null) 'target_count': targetCount,
        if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
        if (formattedTime != null) 'reminder_time': formattedTime,
      },
    );

    final updatedHabit = Habit.fromJson(response);

    // Update notifications if needed
    await _notificationService.cancelNotification(habitId.hashCode);
    if (updatedHabit.reminderEnabled && updatedHabit.reminderTime != null) {
      try {
        final timeParts = updatedHabit.reminderTime!.split(':');
        if (timeParts.length >= 2) {
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          final now = DateTime.now();
          final dt = DateTime(now.year, now.month, now.day, hour, minute);
          
          List<String>? customDays;
          if (updatedHabit.frequency == 'custom' && updatedHabit.frequencyDetails != null) {
             final details = updatedHabit.frequencyDetails!;
             if (details['days'] is List) {
               customDays = List<String>.from(details['days']);
             }
          }
          await _notificationService.scheduleHabitReminder(updatedHabit, dt, customDays: customDays);
        }
      } catch (_) {}
    }

    return updatedHabit;
  }

  /// Delete a habit
  Future<void> deleteHabit(int habitId) async {
    await _apiService.delete('/api/habits/$habitId');
    await _notificationService.cancelNotification(habitId.hashCode);
  }
}
