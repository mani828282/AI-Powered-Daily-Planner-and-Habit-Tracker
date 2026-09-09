import 'api_service.dart';
import '../models/mood.dart';

class MoodService {
  final ApiService _apiService = ApiService();

  /// Log mood and energy
  Future<Mood> logMood({
    required int moodLevel,
    required int energyLevel,
    String? notes,
    List<String>? activities,
  }) async {
    final response = await _apiService.post(
      '/api/mood/log',
      {
        'mood_level': moodLevel,
        'energy_level': energyLevel,
        if (notes != null) 'notes': notes,
        if (activities != null) 'activities': activities,
      },
    );

    return Mood.fromJson(response);
  }

  /// Get AI-powered mood insights
  Future<Map<String, dynamic>> getMoodInsights() async {
    final response = await _apiService.get('/api/mood/insights');
    return response;
  }

  /// Get mood log history
  Future<List<Map<String, dynamic>>> getMoodLogs() async {
    final response = await _apiService.get('/api/mood/list');
    if (response is List) {
      return (response)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }
    return [];
  }

  /// Delete a mood log
  Future<void> deleteMoodLog(int moodId) async {
    await _apiService.delete('/api/mood/$moodId');
  }
}
