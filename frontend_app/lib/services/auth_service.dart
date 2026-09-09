import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import '../models/user.dart';

class AuthService {
  final ApiService _api = ApiService();

  User? _currentUser;
  User? get currentUser => _currentUser;

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _api.getToken();
    if (token == null) return false;

    // Try to load user data
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final phoneNumber = prefs.getString('phone_number');
    final fullName = prefs.getString('full_name');

    if (userId != null && phoneNumber != null && fullName != null) {
      _currentUser = User(
        userId: userId,
        phoneNumber: phoneNumber,
        fullName: fullName,
        email: prefs.getString('email'),
        profilePicture: prefs.getString('profile_picture'),
      );
      return true;
    }

    return false;
  }

  // Register new user
  Future<void> register({
    required String phoneNumber,
    required String fullName,
    required String password,
    String? email,
  }) async {
    try {
      final response = await _api.post(
          ApiConfig.register,
          {
            'phone_number': phoneNumber,
            'full_name': fullName,
            'password': password,
            if (email != null) 'email': email,
          },
          requiresAuth: false);

      // Auto-login: Save token and user data
      await _api.saveToken(response['access_token']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', response['user_id']);
      await prefs.setString('phone_number', response['phone_number']);
      await prefs.setString('full_name', response['full_name']);
      if (email != null) {
        await prefs.setString('email', email);
      }
      if (response['profile_picture'] != null) {
        await prefs.setString('profile_picture', response['profile_picture']);
      }

      _currentUser = User(
        userId: response['user_id'],
        phoneNumber: response['phone_number'],
        fullName: response['full_name'],
        email: email,
        profilePicture: response['profile_picture'],
      );
    } catch (e) {
      rethrow;
    }
  }

  // Verify phone number
  Future<void> verifyPhone({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    try {
      final response = await _api.post(
          ApiConfig.verifyPhone,
          {
            'phone_number': phoneNumber,
            'verification_code': verificationCode,
          },
          requiresAuth: false);

      // Save token and user data
      await _api.saveToken(response['access_token']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', response['user_id']);
      await prefs.setString('phone_number', response['phone_number']);
      await prefs.setString('full_name', response['full_name']);
      if (response['profile_picture'] != null) {
        await prefs.setString('profile_picture', response['profile_picture']);
      }

      _currentUser = User(
        userId: response['user_id'],
        phoneNumber: response['phone_number'],
        fullName: response['full_name'],
        profilePicture: response['profile_picture'],
      );
    } catch (e) {
      rethrow;
    }
  }

  // Login
  Future<void> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await _api.post(
          ApiConfig.login,
          {
            'phone_number': phoneNumber,
            'password': password,
          },
          requiresAuth: false);

      // Save token and user data
      await _api.saveToken(response['access_token']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', response['user_id']);
      await prefs.setString('phone_number', response['phone_number']);
      await prefs.setString('full_name', response['full_name']);
      if (response['profile_picture'] != null) {
        await prefs.setString('profile_picture', response['profile_picture']);
      }

      _currentUser = User(
        userId: response['user_id'],
        phoneNumber: response['phone_number'],
        fullName: response['full_name'],
        profilePicture: response['profile_picture'],
      );
    } catch (e) {
      rethrow;
    }
  }

  // Update Profile
  Future<void> updateProfile({
    String? fullName,
    String? email,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (fullName != null && fullName.isNotEmpty) body['full_name'] = fullName;
      if (email != null && email.isNotEmpty) body['email'] = email;

      await _api.put('/api/auth/profile', body);

      // Update local storage and current user
      final prefs = await SharedPreferences.getInstance();

      String? newFullName = _currentUser?.fullName;
      String? newEmail = _currentUser?.email;

      if (fullName != null && fullName.isNotEmpty) {
        await prefs.setString('full_name', fullName);
        newFullName = fullName;
      }

      if (email != null && email.isNotEmpty) {
        await prefs.setString('email', email);
        newEmail = email;
      }

      if (_currentUser != null) {
        _currentUser = User(
          userId: _currentUser!.userId,
          phoneNumber: _currentUser!.phoneNumber,
          fullName: newFullName!,
          email: newEmail,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> uploadProfilePicture(XFile imageFile) async {
    try {
      final token = await _api.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/profile-picture');

      final request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final bytes = await imageFile.readAsBytes();

      // Determine content type
      MediaType? mediaType;
      final extension = imageFile.name.split('.').last.toLowerCase();
      if (extension == 'png') {
        mediaType = MediaType('image', 'png');
      } else if (extension == 'jpg' || extension == 'jpeg') {
        mediaType = MediaType('image', 'jpeg');
      } else {
        mediaType = MediaType('image', 'jpeg'); // Default fallback
      }

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name,
        contentType: mediaType,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final imageUrl = data['data']['profile_picture'];

        // Update local storage and current user
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_picture', imageUrl);

        if (_currentUser != null) {
          _currentUser = User(
            userId: _currentUser!.userId,
            phoneNumber: _currentUser!.phoneNumber,
            fullName: _currentUser!.fullName,
            email: _currentUser!.email,
            profilePicture: imageUrl,
          );
        }
      } else {
        throw ApiException('Failed to upload image');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Change Password
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _api.post('/api/auth/change-password', {
        'old_password': oldPassword,
        'new_password': newPassword,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Delete Account
  Future<void> deleteAccount() async {
    try {
      await _api.delete('/api/auth/account');
      await logout();
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    await _api.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _currentUser = null;
  }
}
