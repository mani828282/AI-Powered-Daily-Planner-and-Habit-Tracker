// Conditionally exports the Android implementation on native,
// and the no-op stub on web/desktop.
// Consumers just import this file — they get the right class automatically.
export 'usage_monitor_service_io.dart'
    if (dart.library.html) 'usage_monitor_service_web.dart';
