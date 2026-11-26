import 'package:flutter_tts/flutter_tts.dart';

/// Speaks rep counts and form cues during a workout ("Voice coaching").
class VoiceCoach {
  VoiceCoach({required this.enabled});

  bool enabled;
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  DateTime _lastCue = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> init() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(false);
      _ready = true;
    } catch (_) {
      _ready = false; // TTS engine not available — stay silent
    }
  }

  Future<void> say(String text, {bool interrupt = true}) async {
    if (!enabled || !_ready) return;
    if (interrupt) await _tts.stop();
    await _tts.speak(text);
  }

  void rep(int count) => say('$count');

  /// Form cues are throttled so the coach doesn't talk over every frame.
  void cue(String text) {
    final now = DateTime.now();
    if (now.difference(_lastCue) < const Duration(seconds: 4)) return;
    _lastCue = now;
    say(text);
  }

  Future<void> dispose() => _tts.stop();
}
