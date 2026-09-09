// Export the interface for use in other files
export 'voice_service_interface.dart';

import 'voice_service_interface.dart';
import 'voice_service_stub.dart'
    if (dart.library.io) 'voice_service_mobile.dart'
    if (dart.library.html) 'voice_service_web.dart';

VoiceServiceInterface getVoiceService() {
  return createVoiceService();
}
