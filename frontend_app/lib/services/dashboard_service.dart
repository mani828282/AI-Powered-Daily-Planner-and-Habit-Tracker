import 'api_service.dart';

class DashboardService {
  final ApiService _apiService = ApiService();

  /// Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardData() async {
    final response = await _apiService.get('/api/dashboard');
    return response;
  }
}
