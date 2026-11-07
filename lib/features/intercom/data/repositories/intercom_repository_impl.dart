import 'dart:async';

import '../../domain/entities/communication_mode.dart';
import '../../domain/entities/intercom_connection_status.dart';
import '../../domain/entities/intercom_event.dart';
import '../../domain/entities/intercom_role.dart';
import '../../domain/entities/tts_message.dart';
import '../datasources/signaling_service.dart';
import 'intercom_repository.dart';
import '../datasources/webrtc_service.dart';

class IntercomRepositoryImpl implements IntercomRepository {
  IntercomRepositoryImpl({
    SignalingService? signalingService,
    WebRtcService? webRtcService,
  })  : _signalingService = signalingService ?? SignalingService(),
        _webRtcService = webRtcService ?? WebRtcService();

  final SignalingService _signalingService;
  final WebRtcService _webRtcService;

  // Never closed — kept open for the app lifetime so re-joining works.
  // Closing a broadcast StreamController makes it permanently unusable.
  final _eventsController = StreamController<IntercomEvent>.broadcast();

  StreamSubscription<Set<String>>? _membersSub;
  StreamSubscription<Set<String>>? _activeSpeakersSub;
  StreamSubscription<CommunicationMode>? _modeSub;
  Timer? _talkRefreshTimer;

  String? _roomId;
  String? _myUserId;
  IntercomRole? _myRole;
  CommunicationMode _currentMode = CommunicationMode.intercom;

  @override
  Stream<IntercomEvent> get events => _eventsController.stream;

  final Duration _lockTtl = const Duration(seconds: 45);

  @override
  Future<void> joinRoom({
    required String roomId,
    required String myUserId,
    required IntercomRole myRole,
  }) async {
    _roomId = roomId;
    _myUserId = myUserId;
    _myRole = myRole;

    // Mute mic immediately (unmuted only when speaker lock is held).
    await _webRtcService.setTalkingEnabled(false);

    _eventsController.add(
      IntercomConnectionStatusUpdated(IntercomConnectionStatus.connecting),
    );

    await _signalingService.joinRoom(
      roomId: roomId,
      myUserId: myUserId,
      myRole: myRole,
    );

    // Clean stale signaling data from any previous session in this room.
    // Without this, old offers/answers are picked up immediately by onValue
    // and cause failed or duplicate WebRTC connections.
    await _signalingService.cleanSignals(roomId: roomId, myUserId: myUserId);

    // Pre-acquire the microphone now, not lazily on the first peer connection.
    // This (a) shows the Android mic indicator immediately, and (b) ensures the
    // track is ready before any peer arrives so the offer/answer includes audio.
    await _webRtcService.ensureLocalAudioEnabled(enabled: false);

    // Members watcher (connect/disconnect peers).
    final currentMembers = <String>{};
    _membersSub?.cancel();
    _membersSub = _signalingService.watchMembers(roomId).listen((members) async {
      final next = members.where((id) => id != myUserId).toSet();

      final added   = next.difference(currentMembers);
      final removed = currentMembers.difference(next);

      currentMembers
        ..clear()
        ..addAll(next);

      _eventsController.add(IntercomMembersUpdated(next));

      for (final peerId in added) {
        final isOfferer = myUserId.compareTo(peerId) < 0;
        await _webRtcService.attachPeer(
          roomId: roomId,
          myUserId: myUserId,
          peerId: peerId,
          isOfferer: isOfferer,
        );
      }

      for (final peerId in removed) {
        await _webRtcService.detachPeer(peerId);
      }
    }, onError: (e) {
      _eventsController.add(IntercomErrorEvent(e.toString()));
      _eventsController.add(
        const IntercomConnectionStatusUpdated(
          IntercomConnectionStatus.error,
          errorMessage: null,
        ),
      );
    });

    // Mode watcher.
    _modeSub?.cancel();
    _modeSub = _signalingService.watchMode(roomId).listen((mode) {
      _currentMode = mode;
      _eventsController.add(IntercomModeUpdated(mode));
    }, onError: (e) {
      _eventsController.add(IntercomErrorEvent(e.toString()));
    });

    // Active speaker watcher (mic enable/disable based on lock owner/open mic).
    _activeSpeakersSub?.cancel();
    _activeSpeakersSub =
        _signalingService.watchActiveSpeakers(roomId).listen((speakers) {
      final amActive = speakers.contains(myUserId);
      // Fire-and-forget; WebRTC track enabling must respond quickly.
      _webRtcService.setTalkingEnabled(amActive);
      // Notify the controller so the UI updates with the active speaker.
      _eventsController.add(IntercomActiveSpeakersUpdated(speakers));
    }, onError: (e) {
      _eventsController.add(IntercomErrorEvent(e.toString()));
    });

    _eventsController.add(
      IntercomConnectionStatusUpdated(IntercomConnectionStatus.connected),
    );
  }

  @override
  Future<bool> tryStartTalking() async {
    final roomId    = _roomId;
    final myUserId  = _myUserId;
    if (roomId == null || myUserId == null) {
      throw StateError('Repository not connected to a room');
    }

    final myRole = _myRole;
    if (_currentMode == CommunicationMode.intercom && myRole != IntercomRole.director) {
      return false;
    }

    final acquired = await _signalingService.tryAcquireSpeakerLock(
      roomId: roomId,
      myUserId: myUserId,
      lockTtl: _lockTtl,
      mode: _currentMode,
    );

    if (acquired) {
      _talkRefreshTimer?.cancel();
      _talkRefreshTimer = Timer.periodic(_lockTtl ~/ 2, (_) async {
        // Refreshes ownership only if we still hold the lock.
        await _signalingService.tryAcquireSpeakerLock(
          roomId: roomId,
          myUserId: myUserId,
          lockTtl: _lockTtl,
          mode: _currentMode,
        );
      });
      await _webRtcService.setTalkingEnabled(true);
    }

    return acquired;
  }

  @override
  Future<void> stopTalking() async {
    final roomId   = _roomId;
    final myUserId = _myUserId;
    if (roomId == null || myUserId == null) return;

    _talkRefreshTimer?.cancel();
    _talkRefreshTimer = null;

    await _signalingService.releaseSpeakerLock(
      roomId: roomId,
      myUserId: myUserId,
    );
    await _webRtcService.setTalkingEnabled(false);
  }

  @override
  Future<void> leaveRoom() async {
    final roomId   = _roomId;
    final myUserId = _myUserId;
    if (roomId == null || myUserId == null) return;

    _membersSub?.cancel();
    _activeSpeakersSub?.cancel();
    _modeSub?.cancel();
    _talkRefreshTimer?.cancel();

    _membersSub    = null;
    _activeSpeakersSub = null;
    _modeSub = null;
    _roomId    = null;
    _myUserId  = null;
    _myRole    = null;
    _currentMode = CommunicationMode.intercom;

    try {
      await stopTalking();
    } catch (_) {}

    // Dispose all peer connections and the local media stream (mic).
    // WebRtcService.dispose() resets _localStream so ensureLocalAudioEnabled()
    // will re-acquire the mic fresh on the next joinRoom() call.
    await _webRtcService.dispose();

    await _signalingService.leaveRoom(
      roomId: roomId,
      myUserId: myUserId,
    );

    // ⚠️  DO NOT close _eventsController here.
    // Closing a broadcast StreamController is permanent — any subsequent
    // joinRoom() calls would crash with "Bad state: cannot add new events
    // DO NOT close _eventsController here.
  }

  @override
  Future<void> setCommunicationMode({
    required String roomId,
    required CommunicationMode mode,
  }) async {
    await _signalingService.setMode(roomId: roomId, mode: mode);
  }

  @override
  Future<void> broadcastTtsMessage(TtsMessage message) async {
    final roomId = _roomId;
    if (roomId == null) return;
    await _signalingService.broadcastTtsMessage(
      roomId: roomId,
      message: message,
    );
  }

  @override
  Stream<TtsMessage> watchTtsMessages(String roomId) {
    return _signalingService.watchTtsMessages(roomId);
  }
}
