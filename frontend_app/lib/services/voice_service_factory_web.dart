import 'voice_service_interface.dart';
import 'voice_service_web.dart';

VoiceServiceInterface getVoiceService() {
  return VoiceServiceWeb();
}
