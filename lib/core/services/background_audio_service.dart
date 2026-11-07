import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// Keeps the app/process alive when the screen is off.
///
/// For MVP we play a short looping silent audio file. WebRTC remote audio
/// should also keep the audio session active, but on some devices the process
/// can still be suspended without any playback.
class BackgroundAudioService {
  static bool _started = false;
  static AudioHandler? _handler;

  static Future<void> ensureStarted() async {
    if (_started) return;

    final session = await AudioSession.instance;
    // Use playback mode — NOT speech mode.
    //
    // AudioSessionConfiguration.speech() sets the Android audio mode to
    // MODE_IN_COMMUNICATION which forces output to the earpiece (very low
    // volume).  Playback mode uses MODE_NORMAL which defaults to the
    // loudspeaker and lets Helper.setSpeakerphoneOn() work correctly.
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.media,            // ← media, not voiceCommunication
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    ));

    _handler = await AudioService.init(
      builder: () => _IntercomAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'intercom_audio',
        androidNotificationChannelName: 'Intercom audio',
        androidNotificationOngoing: true,
      ),
    );

    // Start silent looping playback immediately.
    await _handler!.play();
    _started = true;
  }
}

class _IntercomAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  bool _assetLoaded = false;

  Future<void> _ensureLoaded() async {
    if (_assetLoaded) return;

    // Asset must exist at `assets/audio/silence.wav`.
    await _player.setAsset('assets/audio/silence.wav');
    await _player.setLoopMode(LoopMode.one);

    mediaItem.add(
      MediaItem(
        id: 'silence',
        title: 'Intercom',
        album: 'Intercom background',
        duration: null,
      ),
    );

    _assetLoaded = true;
  }

  @override
  Future<void> play() async {
    await _ensureLoaded();
    await _player.play();

    playbackState.add(
      playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ),
    );
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await super.onTaskRemoved();
  }
}
