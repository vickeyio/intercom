import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../core/errors/intercom_error.dart';
import 'signaling_service.dart';

/// WebRTC audio-only mesh with Firebase RTDB signaling.
///
/// MVP strategy:
/// - Full mesh (<= 3-5 users) using one RTCPeerConnection per peer.
/// - Deterministic offerer: the peer with the "lower" userId creates the offer.
/// - Push-to-talk uses mic track enable/disable; signaling carries SDP/ICE only.
class WebRtcService {
  WebRtcService({SignalingService? signaling})
      : _signaling = signaling ?? SignalingService();

  final SignalingService _signaling;

  MediaStream? _localStream;
  MediaStreamTrack? _localAudioTrack;
  bool _localAudioEnabled = false;

  final Map<String, RTCPeerConnection> _peers = {};
  final Map<String, List<StreamSubscription>> _peerSubscriptions = {};

  /// Ensures the local microphone stream exists and the track is in [enabled]
  /// state.  Must be called before [attachPeer] so the track is ready to add
  /// to the offer.
  ///
  /// Also routes audio to the loudspeaker on Android — without this, WebRTC
  /// defaults to the tiny earpiece used for phone calls.
  Future<void> ensureLocalAudioEnabled({required bool enabled}) async {
    if (_localStream == null) {
      // Request mic with constraints that suit a PTT / walkie-talkie use-case.
      final stream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          // Legacy Chrome / Android Chrome constraint names for WebRTC.
          'mandatory': {
            'googEchoCancellation': 'true',
            'googAutoGainControl':   'true',
            'googNoiseSuppression':  'true',
            'googHighpassFilter':    'true',
          },
        },
        'video': false,
      });

      _localStream = stream;
      final audioTracks = stream.getAudioTracks();
      if (audioTracks.isEmpty) {
        throw IntercomError('No microphone audio track available');
      }
      _localAudioTrack = audioTracks.first;

      // Route incoming WebRTC audio to the loudspeaker, not the earpiece.
      // This is Android-specific; on iOS the audio session handles routing.
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await Helper.setSpeakerphoneOn(true);
        } catch (e) {
          debugPrint('setSpeakerphoneOn failed: $e');
        }
      }
    }

    _localAudioEnabled = enabled;
    _localAudioTrack?.enabled = enabled;
  }

  /// Adds/negotiates a peer connection with [peerId].
  Future<void> attachPeer({
    required String roomId,
    required String myUserId,
    required String peerId,
    required bool isOfferer,
  }) async {
    if (_peers.containsKey(peerId)) return;

    final configuration = <String, dynamic>{
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
        {'url': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    final peerConnection = await createPeerConnection(configuration);
    _peers[peerId] = peerConnection;
    _peerSubscriptions[peerId] = [];

    // Ensure the local audio track is ready (may have been pre-acquired in
    // joinRoom; this is a no-op if the stream already exists).
    await ensureLocalAudioEnabled(enabled: _localAudioEnabled);

    if (_localAudioTrack != null && _localStream != null) {
      await peerConnection.addTrack(_localAudioTrack!, _localStream!);
    }

    // Remote audio plays automatically once the track arrives and is attached
    // to a stream.  Re-confirm speaker routing here because some Android
    // devices reset the audio route when a new connection starts.
    peerConnection.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] Peer $peerId connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          Helper.setSpeakerphoneOn(true).catchError((_) {});
        }
      }
    };

    peerConnection.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[WebRTC] Peer $peerId ICE state: $state');
    };

    peerConnection.onTrack = (RTCTrackEvent event) {
      debugPrint('[WebRTC] onTrack from $peerId: kind=${event.track.kind}, '
          'enabled=${event.track.enabled}, streams=${event.streams.length}');
      if (event.track.kind != 'audio') return;
      // Track is auto-played — just ensure it's attached to a stream.
      if (event.streams.isNotEmpty) {
        final stream = event.streams.first;
        stream.addTrack(event.track);
      }
    };

    // Send local ICE candidates.
    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      final candidateStr = candidate.candidate;
      if (candidateStr == null || candidateStr.isEmpty) return;
      _signaling.sendIceCandidate(
        roomId: roomId,
        fromId: myUserId,
        toId: peerId,
        candidate: candidate,
      );
    };

    // Buffer remote ICE candidates until we set the remote description.
    var remoteDescriptionSet = false;
    final pendingIceCandidates = <RTCIceCandidate>[];

    final iceSub = _signaling
        .watchIceCandidates(
          roomId: roomId,
          fromId: peerId,
          toId: myUserId,
        )
        .listen(
          (candidate) async {
            if (!remoteDescriptionSet) {
              pendingIceCandidates.add(candidate);
              return;
            }
            await peerConnection.addCandidate(candidate);
          },
          onError: (_) {},
        );
    _peerSubscriptions[peerId]!.add(iceSub);

    if (isOfferer) {
      final offer = await peerConnection.createOffer(<String, dynamic>{
        'offerToReceiveAudio': 1,
      });
      await peerConnection.setLocalDescription(offer);

      await _signaling.sendOffer(
        roomId: roomId,
        fromId: myUserId,
        toId: peerId,
        offer: offer,
      );

      final answerSub = _signaling
          .watchAnswer(
            roomId: roomId,
            fromId: peerId,
            toId: myUserId,
          )
          .listen((answer) async {
        await peerConnection.setRemoteDescription(answer);
        remoteDescriptionSet = true;
        for (final c in pendingIceCandidates) {
          await peerConnection.addCandidate(c);
        }
        pendingIceCandidates.clear();
      });
      _peerSubscriptions[peerId]!.add(answerSub);
    } else {
      final offerSub = _signaling
          .watchOffer(
            roomId: roomId,
            fromId: peerId,
            toId: myUserId,
          )
          .listen((offer) async {
        await peerConnection.setRemoteDescription(offer);
        remoteDescriptionSet = true;
        for (final c in pendingIceCandidates) {
          await peerConnection.addCandidate(c);
        }
        pendingIceCandidates.clear();

        final answer = await peerConnection.createAnswer(<String, dynamic>{
          'offerToReceiveAudio': 1,
        });
        await peerConnection.setLocalDescription(answer);

        await _signaling.sendAnswer(
          roomId: roomId,
          fromId: myUserId,
          toId: peerId,
          answer: answer,
        );
      });
      _peerSubscriptions[peerId]!.add(offerSub);
    }
  }

  Future<void> setTalkingEnabled(bool enabled) async {
    _localAudioEnabled = enabled;
    if (_localAudioTrack != null) {
      _localAudioTrack!.enabled = enabled;
    }
  }

  Future<void> detachPeer(String peerId) async {
    final subs = _peerSubscriptions.remove(peerId);
    if (subs != null) {
      for (final s in subs) {
        await s.cancel();
      }
    }

    final peerConnection = _peers.remove(peerId);
    await peerConnection?.close();
  }

  /// Tears down all peer connections and releases the local mic stream.
  ///
  /// After [dispose], [ensureLocalAudioEnabled] will re-acquire the mic on the
  /// next [joinRoom] call — because [_localStream] is reset to null here.
  Future<void> dispose() async {
    final peerIds = _peers.keys.toList();
    for (final id in peerIds) {
      await detachPeer(id);
    }
    _peers.clear();
    _peerSubscriptions.clear();

    try {
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;
    _localAudioTrack = null;
    // Keep _localAudioEnabled = false so re-entry starts muted.
    _localAudioEnabled = false;
  }
}
