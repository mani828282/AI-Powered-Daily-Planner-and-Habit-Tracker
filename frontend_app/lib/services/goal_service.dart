import 'api_service.dart';
import '../models/goal.dart';

class GoalService {
  final ApiService _apiService = ApiService();

  /// Get all goals
  Future<List<Goal>> getGoals() async {
    final response = await _apiService.get('/api/goals/list');
    if (response is List) {
      return (response).map((json) => Goal.fromJson(json)).toList();
    }
    return [];
  }

  /// Create a new goal with AI decomposition
  Future<Goal> createGoal({
    required String title,
    String? description,
    String? category,
    DateTime? targetDate, // For backwards compatibility
    DateTime? startDate,
    DateTime? endDate,
    bool aiDecompose = true,
  }) async {
    final response = await _apiService.post(
      '/api/goals/create',
      {
        'title': title,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (targetDate != null)
          'target_date': targetDate.toIso8601String().split('T')[0],
        if (startDate != null)
          'start_date': startDate.toIso8601String().split('T')[0],
        if (endDate != null)
          'end_date': endDate.toIso8601String().split('T')[0],
        'ai_decompose': aiDecompose,
      },
    );

    return Goal.fromJson(response);
  }

  /// Toggle subtask completion
  Future<Map<String, dynamic>> toggleSubtask(int subtaskId) async {
    try {
      final response = await _apiService.put(
        '/api/goals/subtask/$subtaskId/toggle',
        {},
      );
      return response;
    } catch (e) {
      throw Exception('Failed to toggle subtask: $e');
    }
  }

  /// Delete a goal
  Future<void> deleteGoal(int goalId) async {
    await _apiService.delete('/api/goals/$goalId');
  }

  /// Get AI-powered goal suggestions
  Future<Map<String, dynamic>> getGoalSuggestions() async {
    try {
      final response = await _apiService.get('/api/goals/suggestions');
      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to get goal suggestions: $e');
    }
  }
}
