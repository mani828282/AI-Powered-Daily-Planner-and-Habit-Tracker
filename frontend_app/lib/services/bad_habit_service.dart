import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class BadHabitService {
  static const String _tokenKey = 'auth_token';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Add a tracked app ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> addTrackedApp({
    required String appName,
    required String packageName,
    required int dailyLimitMinutes,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/bad-habits/apps'),
      headers: await _headers(),
      body: jsonEncode({
        'app_name': appName,
        'package_name': packageName,
        'daily_limit_minutes': dailyLimitMinutes,
      }),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to add app');
  }

  // ── List tracked apps ──────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getTrackedApps() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/bad-habits/apps'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to fetch tracked apps');
  }

  // ── Update limit ───────────────────────────────────────────────────────────
  Future<void> updateLimit(int appId, int newLimitMinutes) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/bad-habits/apps/$appId'),
      headers: await _headers(),
      body: jsonEncode({'daily_limit_minutes': newLimitMinutes}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update limit');
    }
  }

  // ── Delete tracked app ─────────────────────────────────────────────────────
  Future<void> deleteTrackedApp(int appId) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/bad-habits/apps/$appId'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to remove app');
    }
  }

  // ── Log usage (called by background monitor) ───────────────────────────────
  Future<Map<String, dynamic>> logUsage({
    required String packageName,
    required int minutesUsed,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/bad-habits/log-usage'),
      headers: await _headers(),
      body: jsonEncode({
        'package_name': packageName,
        'minutes_used': minutesUsed,
      }),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to log usage');
  }

  // ── Get today's usage ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getTodayUsage() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/bad-habits/usage-today'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to fetch today\'s usage');
  }

  // ── Get clean streak ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getStreak() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/bad-habits/streak'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to fetch streak');
  }
}
