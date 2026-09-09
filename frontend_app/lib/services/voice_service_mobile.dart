import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';
import '../config/api_config.dart';
import 'voice_service_interface.dart';

class VoiceServiceMobile implements VoiceServiceInterface {
  final ApiService _apiService = ApiService();

  @override
  Future<Map<String, dynamic>> transcribeAudio(
    dynamic audioData, {
    String? language,
  }) async {
    final audioPath = audioData as String;
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/voice/transcribe');
      final request = http.MultipartRequest('POST', url);

      // Add auth header
      final token = await _apiService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add audio file
      request.files.add(
        await http.MultipartFile.fromPath('file', audioPath),
      );

      // Add language if provided
      if (language != null) {
        request.fields['language'] = language;
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonData;
      } else {
        throw Exception(jsonData['detail'] ?? 'Transcription failed');
      }
    } catch (e) {
      throw Exception('Failed to transcribe audio: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> classifyIntent(
    String transcription, {
    String? context,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/voice/classify',
        {
          'transcription': transcription,
          'context': context,
        },
      );

      return response;
    } catch (e) {
      throw Exception('Failed to classify intent: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> processVoiceCommand(
    dynamic audioData, {
    String? context,
    String? language,
    bool previewOnly = false,
  }) async {
    final audioPath = audioData as String;
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/voice/process');
      final request = http.MultipartRequest('POST', url);

      // Add auth header
      final token = await _apiService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add audio file
      request.files.add(
        await http.MultipartFile.fromPath('file', audioPath),
      );

      // Add optional fields
      if (context != null) {
        request.fields['context'] = context;
      }
      if (language != null) {
        request.fields['language'] = language;
      }
      if (previewOnly) {
        request.fields['preview_only'] = 'true';
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonData;
      } else {
        throw Exception(jsonData['detail'] ?? 'Voice processing failed');
      }
    } catch (e) {
      throw Exception('Failed to process voice command: $e');
    }
  }

  @override
  Future<String> getTempAudioPath() async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/voice_$timestamp.wav';
  }

  @override
  Future<void> deleteAudioFile(dynamic path) async {
    try {
      final file = File(path as String);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // print('Error deleting audio file: $e');
    }
  }
}

VoiceServiceInterface createVoiceService() {
  return VoiceServiceMobile();
}
