import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../config/theme.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(dynamic audioData) onRecordingComplete;
  final String? context; // 'tasks', 'goals', 'habits'
  final int maxDuration; // Maximum recording duration in seconds

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    this.context,
    this.maxDuration = 60,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _timer;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _checkPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  /// Called on first tap → starts recording
  Future<void> _startRecording() async {
    if (kIsWeb) {
      _showWebNotSupportedDialog();
      return;
    }

    try {
      if (await _checkPermission()) {
        final path = await _getTempPath();

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            bitRate: 128000,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        // Start timer, auto-stop at max duration
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _recordDuration++);
          if (_recordDuration >= widget.maxDuration) {
            _stopRecording();
          }
        });
      } else {
        _showPermissionDialog();
      }
    } catch (e) {
      _showErrorDialog('Failed to start recording: $e');
    }
  }

  /// Called on second tap → stops recording and sends audio for processing
  Future<void> _stopRecording() async {
    try {
      _timer?.cancel();
      final path = await _audioRecorder.stop();

      setState(() => _isRecording = false);

      if (path != null && _recordDuration >= 1) {
        widget.onRecordingComplete(path);
      } else if (_recordDuration < 1) {
        _showErrorDialog(
            'Recording too short. Please record for at least 1 second.');
      }
    } catch (e) {
      _showErrorDialog('Failed to stop recording: $e');
    }
  }

  /// Toggle: start if idle, stop if recording
  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  Future<String> _getTempPath() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (kIsWeb) return 'voice_$timestamp.wav';
    return '/data/user/0/com.example.frontend_app/cache/voice_$timestamp.wav';
  }

  void _showWebNotSupportedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Feature Not Available'),
        content: const Text(
          'Voice recording is currently not supported on web browsers. Please use the mobile app for this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
          'Please grant microphone permission to use voice recording.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleRecording, // Single tap to start/stop
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient:
              _isRecording ? AppTheme.sunsetGradient : AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _isRecording
                  ? Colors.orange.withValues(alpha: 0.4)
                  : AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: _isRecording ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated pulse ring when recording
            if (_isRecording)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
                    width: 52 + (_animationController.value * 14),
                    height: 52 + (_animationController.value * 14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            // Icon: mic when idle, stop when recording
            Icon(
              _isRecording ? Icons.stop_rounded : Icons.mic,
              color: Colors.white,
              size: 22,
            ),
            // Timer badge when recording
            if (_isRecording)
              Positioned(
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_recordDuration}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
