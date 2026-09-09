import 'dart:async';
import 'api_service.dart';

class Insight {
  final String type;
  final String? habitName;
  final String title;
  final String message;
  final String recommendation;
  final String icon;
  final String strength;

  Insight({
    required this.type,
    this.habitName,
    required this.title,
    required this.message,
    required this.recommendation,
    required this.icon,
    required this.strength,
  });

  factory Insight.fromJson(Map<String, dynamic> json) {
    return Insight(
      type: json['type'] ?? 'general',
      habitName: json['habit_name'],
      title: json['title'] ?? 'Insight',
      message: json['message'] ?? '',
      recommendation: json['recommendation'] ?? '',
      icon: json['icon'] ?? '💡',
      strength: json['strength'] ?? 'moderate',
    );
  }
}

class SmartInsightsData {
  final List<Map<String, dynamic>> habitCorrelations;
  final Map<String, dynamic> weekdayPatterns;
  final Map<String, dynamic> statistics;
  final List<Insight> insights;
  final String summary;
  final String? motivation;
  final int daysAnalyzed;
  final int moodLogsCount;
  final int totalHabitCompletions;

  SmartInsightsData({
    required this.habitCorrelations,
    required this.weekdayPatterns,
    required this.statistics,
    required this.insights,
    required this.summary,
    this.motivation,
    required this.daysAnalyzed,
    required this.moodLogsCount,
    required this.totalHabitCompletions,
  });

  factory SmartInsightsData.fromJson(Map<String, dynamic> json) {
    List<Insight> insightsList = [];
    if (json['ai_insights'] != null &&
        json['ai_insights']['insights'] != null) {
      insightsList = (json['ai_insights']['insights'] as List)
          .map((i) => Insight.fromJson(i))
          .toList();
    }

    return SmartInsightsData(
      habitCorrelations: List<Map<String, dynamic>>.from(
        json['habit_correlations'] ?? [],
      ),
      weekdayPatterns: Map<String, dynamic>.from(
        json['weekday_patterns'] ?? {},
      ),
      statistics: Map<String, dynamic>.from(json['statistics'] ?? {}),
      insights: insightsList,
      summary: json['ai_insights']?['summary'] ?? 'No insights available yet.',
      motivation: json['ai_insights']?['motivation'],
      daysAnalyzed: json['days_analyzed'] ?? 30,
      moodLogsCount: json['mood_logs_count'] ?? 0,
      totalHabitCompletions: json['total_habit_completions'] ?? 0,
    );
  }
}

class CorrelationService {
  final ApiService _apiService = ApiService();

  /// Get mood-habit correlation data
  Future<Map<String, dynamic>> getMoodHabitCorrelation({int days = 30}) async {
    try {
      final response = await _apiService.get(
        '/api/analytics/mood-habit-correlation?days=$days',
      );

      return response; // ApiService.get already returns the decoded JSON
    } catch (_) {
      // print('Error fetching correlation data: $e');
      rethrow;
    }
  }

  /// Get smart insights with AI-generated recommendations
  Future<SmartInsightsData> getSmartInsights({int days = 30}) async {
    try {
      final data = await _apiService
          .get('/api/analytics/smart-insights?days=$days')
          .timeout(
        const Duration(seconds: 35), // Slightly longer than backend timeout
        onTimeout: () {
          throw TimeoutException(
            'Insights are taking longer than usual to generate. '
            'This might be due to processing a large amount of data. '
            'Please try again in a moment.',
          );
        },
      );

      return SmartInsightsData.fromJson(data);
    } on TimeoutException catch (_) {
      // print('Timeout fetching smart insights: $e');
      // Return a basic insights structure on timeout
      return SmartInsightsData(
        habitCorrelations: [],
        weekdayPatterns: {},
        statistics: {},
        insights: [],
        summary: 'Insights are being generated. Please refresh in a moment.',
        motivation: 'Your data is being analyzed! 🔄',
        daysAnalyzed: days,
        moodLogsCount: 0,
        totalHabitCompletions: 0,
      );
    } catch (e) {
      // print('Error fetching smart insights: $e');
      rethrow;
    }
  }

  /// Manually refresh correlations
  Future<Map<String, dynamic>> refreshCorrelations() async {
    try {
      final response = await _apiService.post(
        '/api/analytics/refresh-correlations',
        {},
      );

      return response; // ApiService.post already returns the decoded JSON
    } catch (e) {
      // print('Error refreshing correlations: $e');
      rethrow;
    }
  }
}
