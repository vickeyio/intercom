import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);

  bool _isInit = false;

  Future<void> init() async {
    if (_isInit) return;
    
    await _flutterTts.setSharedInstance(true);
    await _flutterTts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      ],
      IosTextToSpeechAudioMode.voicePrompt,
    );

    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      isSpeaking.value = true;
    });

    _flutterTts.setCompletionHandler(() {
      isSpeaking.value = false;
    });

    _flutterTts.setCancelHandler(() {
      isSpeaking.value = false;
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('[TtsService] Error: $msg');
      isSpeaking.value = false;
    });

    _isInit = true;
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!_isInit) await init();
    
    await stop(); // Stop any currently speaking TTS
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    if (isSpeaking.value) {
      await _flutterTts.stop();
    }
  }

  Future<void> setLanguage(String lang) async {
    if (!_isInit) await init();
    await _flutterTts.setLanguage(lang);
  }
}
