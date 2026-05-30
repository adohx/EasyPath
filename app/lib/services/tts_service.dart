import 'dart:async';
import 'package:flutter/semantics.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _nativeTtsAvailable = false;

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      // Prefer Google TTS to bypass MIUI's non-standard default engine
      final engines = await _tts.getEngines;
      if (engines is List) {
        const preferred = ['com.google.android.tts', 'com.samsung.SMT'];
        for (final e in preferred) {
          if (engines.any((eng) => eng.toString() == e)) {
            await _tts.setEngine(e);
            break;
          }
        }
      }
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _nativeTtsAvailable = true;
    } catch (_) {
      _nativeTtsAvailable = false;
    }
  }

  /// Announce text via the platform accessibility framework (TalkBack-compatible).
  void _announce(String text) {
    // ignore: deprecated_member_use
    SemanticsService.announce(text, TextDirection.ltr);
  }

  Future<void> speak(String text) async {
    await _init();
    if (_nativeTtsAvailable) {
      await _tts.stop();
      await _tts.speak(text);
    } else {
      _announce(text);
    }
  }

  Future<void> stop() async {
    if (_nativeTtsAvailable) {
      await _tts.stop();
    }
  }

  Future<void> speakInterrupt(String text) async {
    await _init();
    if (_nativeTtsAvailable) {
      await _tts.stop();
      await _tts.speak(text);
    } else {
      _announce(text);
    }
  }

  /// Speaks [text] and then calls [action] after speech completes.
  /// Uses native TTS with completion callback, or accessibility announce + 300 ms delay.
  void speakThenRun(String text, void Function() action) {
    unawaited(_doSpeakThenRun(text, action));
  }

  Future<void> _doSpeakThenRun(String text, void Function() action) async {
    await _init();
    if (_nativeTtsAvailable) {
      try {
        await _tts.stop();
        await _tts.awaitSpeakCompletion(true);
        await _tts.speak(text).timeout(const Duration(seconds: 3));
      } catch (_) {
        // Timed out or failed — fall through to action
      } finally {
        await _tts.awaitSpeakCompletion(false);
      }
    } else {
      _announce(text);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    action();
  }
}
