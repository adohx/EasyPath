import 'package:flutter/services.dart';

class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  static const _channel = MethodChannel('com.ana.accessibility_nav_assistant/voice');

  /// Opens the system speech recogniser dialog and returns the recognised text,
  /// or an empty string if cancelled / unavailable.
  Future<String> listen() async {
    try {
      final result = await _channel.invokeMethod<String>('startVoiceInput');
      return result ?? '';
    } on PlatformException {
      return '';
    }
  }
}
