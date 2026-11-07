import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/background_audio_service.dart';
import 'core/services/notification_service.dart';
import 'features/intercom/services/tts_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  try {
    // Keeps the app/process alive when the screen is locked, so WebRTC audio
    // continues to work in the background.
    await BackgroundAudioService.ensureStarted();
    await NotificationService().init();
    await TtsService().init();
  } catch (e) {
    debugPrint('Services init error: $e');
  }

  runApp(const ProviderScope(child: IntercomApp()));
}


