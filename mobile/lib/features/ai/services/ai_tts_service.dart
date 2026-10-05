import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Wraps [FlutterTts] for the AI practice flow.
///
/// Contract:
///  * [init] must complete before the first [speak].
///  * [speak] only resolves once playback actually finished, so callers can
///    drive animations from real TTS progress.
///  * Failures never throw: [onError] is invoked and the future completes, so
///    a TTS problem can never crash the Practice screen.
class AITtsService {
  AITtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  bool _ready = false;
  bool _speaking = false;
  int _generation = 0;

  /// Invoked when TTS fails. The UI stays usable, the text stays visible.
  void Function(Object error)? onError;

  bool get isReady => _ready;
  bool get isSpeaking => _speaking;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _tts.setCancelHandler(() {
        _speaking = false;
      });
      _tts.setErrorHandler((dynamic message) {
        _speaking = false;
        onError?.call(message ?? 'Speech synthesis failed');
      });
      _ready = true;
    } catch (e) {
      _ready = false;
      onError?.call(e);
    }
  }

  /// Speaks [text] and completes when playback ends (or is cancelled/failed).
  Future<void> speak(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final token = ++_generation;

    await init();
    if (!_ready) return;

    try {
      await _tts.stop();
      if (token != _generation) return;

      _speaking = true;
      // Resolves when the utterance finishes because awaitSpeakCompletion is on.
      await _tts.speak(clean);
    } catch (e) {
      onError?.call(e);
    } finally {
      if (token == _generation) _speaking = false;
    }
  }

  Future<void> stop() async {
    _generation++;
    _speaking = false;
    try {
      await _tts.stop();
    } catch (_) {
      // Stopping is best effort.
    }
  }
}
