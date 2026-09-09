import 'environment.dart';

class ApiConfig {
  // Base URL for the backend API - uses environment configuration
  static String get baseUrl => EnvironmentConfig.apiBaseUrl;

  // API Endpoints
  static const String apiPrefix = '/api';

  // Auth Endpoints
  static const String register = '$apiPrefix/auth/register';
  static const String verifyPhone = '$apiPrefix/auth/verify-phone';
  static const String login = '$apiPrefix/auth/login';
  static const String refresh = '$apiPrefix/auth/refresh';

  // Task Endpoints
  static const String createTask = '$apiPrefix/tasks/create';
  static const String listTasks = '$apiPrefix/tasks/list';
  static String updateTask(int taskId) => '$apiPrefix/tasks/$taskId';
  static String deleteTask(int taskId) => '$apiPrefix/tasks/$taskId';
  static const String aiOrganizeTasks = '$apiPrefix/tasks/ai-organize';

  // Habit Endpoints
  static const String createHabit = '$apiPrefix/habits/create';
  static const String listHabits = '$apiPrefix/habits/list';
  static const String completeHabit = '$apiPrefix/habits/complete';
  static const String habitStreaks = '$apiPrefix/habits/streaks';

  // Mood Endpoints
  static const String logMood = '$apiPrefix/mood/log';
  static const String moodInsights = '$apiPrefix/mood/insights';

  // Goals Endpoints
  static const String createGoal = '$apiPrefix/goals/create';
  static const String listGoals = '$apiPrefix/goals/list';

  // AI Endpoints
  static const String aiSuggestHabits = '$apiPrefix/ai/suggest-habits';
  static const String aiPredictions = '$apiPrefix/ai/predictions';

  // Analytics Endpoints
  static const String dailyReport = '$apiPrefix/analytics/daily';
  static const String weeklyReport = '$apiPrefix/analytics/weekly';
  static const String monthlyReport = '$apiPrefix/analytics/monthly';
  static const String dashboard = '$apiPrefix/analytics/dashboard';

  // Timeout durations (increased for AI processing)
  static const Duration connectionTimeout = Duration(seconds: 90);
  static const Duration receiveTimeout = Duration(seconds: 90);
}
