import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'api_service.dart';
import '../config/api_config.dart';
import 'voice_service_interface.dart';

class VoiceServiceWeb implements VoiceServiceInterface {
  final ApiService _apiService = ApiService();

  @override
  Future<Map<String, dynamic>> transcribeAudio(
    dynamic audioData, {
    String? language,
  }) async {
    final audioBytes = audioData as Uint8List;
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/voice/transcribe');
      final request = http.MultipartRequest('POST', url);

      // Add auth header
      final token = await _apiService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add audio file from bytes
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: 'audio.wav',
        ),
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
    final audioBytes = audioData as Uint8List;
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/voice/process');
      final request = http.MultipartRequest('POST', url);

      // Add auth header
      final token = await _apiService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add audio file from bytes
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: 'audio.wav',
        ),
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
  Future<Uint8List> getTempAudioPath() async {
    // For web, we'll return an empty Uint8List as a placeholder
    // The actual recording will be handled by the recorder widget
    return Uint8List(0);
  }

  @override
  Future<void> deleteAudioFile(dynamic path) async {
    // No-op for web since we're using in-memory bytes
    return;
  }
}

VoiceServiceInterface createVoiceService() {
  return VoiceServiceWeb();
}
