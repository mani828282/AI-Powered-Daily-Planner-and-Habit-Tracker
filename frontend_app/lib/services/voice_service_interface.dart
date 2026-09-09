/// Interface for voice service to support both web and mobile
abstract class VoiceServiceInterface {
  /// Transcribe audio to text
  Future<Map<String, dynamic>> transcribeAudio(
    dynamic audioData, {
    String? language,
  });

  /// Classify intent from transcription
  Future<Map<String, dynamic>> classifyIntent(
    String transcription, {
    String? context,
  });

  /// Complete voice processing pipeline
  Future<Map<String, dynamic>> processVoiceCommand(
    dynamic audioData, {
    String? context,
    String? language,
    bool previewOnly = false,
  });

  /// Get temporary path or data for audio
  Future<dynamic> getTempAudioPath();

  /// Clean up temporary audio file
  Future<void> deleteAudioFile(dynamic path);
}
