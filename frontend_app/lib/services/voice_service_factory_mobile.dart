import 'voice_service_interface.dart';
import 'voice_service_mobile.dart';

VoiceServiceInterface getVoiceService() {
  return VoiceServiceMobile();
}
