import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../core/errors/intercom_error.dart';
import '../../domain/entities/communication_mode.dart';
import '../../domain/entities/intercom_role.dart';
import '../../domain/entities/tts_message.dart';

class SignalingService {
  SignalingService({FirebaseDatabase? database})
      : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  DatabaseReference _roomsRef(String roomId) =>
      _database.ref('rooms/$roomId');

  DatabaseReference _membersRef(String roomId) =>
      _roomsRef(roomId).child('members');

  DatabaseReference _activeSpeakersRef(String roomId) =>
      _roomsRef(roomId).child('activeSpeakers');

  DatabaseReference _ttsMessagesRef(String roomId) =>
      _roomsRef(roomId).child('ttsMessages');

  DatabaseReference _modeRef(String roomId) =>
      _roomsRef(roomId).child('mode');

  DatabaseReference _signalsRef(String roomId, String fromId, String toId) =>
      _roomsRef(roomId).child('signals').child(fromId).child(toId);

  DatabaseReference _iceRef(String roomId, String fromId, String toId) =>
      _signalsRef(roomId, fromId, toId).child('ice');

  Future<void> joinRoom({
    required String roomId,
    required String myUserId,
    required IntercomRole myRole,
  }) async {
    final memberRef = _membersRef(roomId).child(myUserId);

    // Timeout so a misconfigured databaseURL fails fast rather than hanging.
    await memberRef
        .set(<String, dynamic>{
          'role': myRole.name,
          'joinedAt': ServerValue.timestamp,
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException(
            'Firebase RTDB write timed out. '
            'Check your databaseURL and internet connection.',
          ),
        );

    // Remove from the room if the client disconnects unexpectedly.
    memberRef.onDisconnect().remove();
  }

  Future<void> leaveRoom({
    required String roomId,
    required String myUserId,
  }) async {
    // Clean up signals involving this user.
    try {
      await _roomsRef(roomId).child('signals').child(myUserId).remove();
    } catch (_) {}
    await _membersRef(roomId).child(myUserId).remove();
  }

  /// Removes all signaling data (offers, answers, ICE candidates) involving
  /// [myUserId] so stale data from a previous session isn't misinterpreted.
  Future<void> cleanSignals({
    required String roomId,
    required String myUserId,
  }) async {
    final signalsRef = _roomsRef(roomId).child('signals');
    try {
      // Remove signals sent *from* me.
      await signalsRef.child(myUserId).remove();

      // Remove signals sent *to* me by any peer.
      final snapshot = await signalsRef.get();
      if (snapshot.value is Map) {
        final senders = (snapshot.value as Map).keys;
        for (final sender in senders) {
          await signalsRef.child(sender.toString()).child(myUserId).remove();
        }
      }
    } catch (e) {
      debugPrint('[Signaling] cleanSignals error: $e');
    }
  }

  /// Emits the set of active member userIds in the room.
  Stream<Set<String>> watchMembers(String roomId) {
    return _membersRef(roomId).onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return const <String>{};
      if (value is Map) {
        return value.keys.map((e) => e.toString()).toSet();
      }
      throw IntercomError('Unexpected members snapshot format');
    });
  }

  /// Emits the current active speaker userIds.
  Stream<Set<String>> watchActiveSpeakers(String roomId) {
    return _activeSpeakersRef(roomId).onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return const <String>{};
      if (value is Map) {
        return value.keys.map((e) => e.toString()).toSet();
      }
      return const <String>{};
    });
  }

  Future<void> setMode({
    required String roomId,
    required CommunicationMode mode,
  }) async {
    await _modeRef(roomId).set(mode.name);
  }

  Stream<CommunicationMode> watchMode(String roomId) {
    return _modeRef(roomId).onValue.map((event) {
      final value = event.snapshot.value?.toString();
      if (value == CommunicationMode.openMic.name) {
        return CommunicationMode.openMic;
      }
      // Default fallback
      return CommunicationMode.intercom;
    });
  }

  /// Tries to acquire the speaker lock (Intercom) or just sets talking (OpenMic).
  Future<bool> tryAcquireSpeakerLock({
    required String roomId,
    required String myUserId,
    required Duration lockTtl,
    required CommunicationMode mode,
  }) async {
    final lockRef = _activeSpeakersRef(roomId);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (mode == CommunicationMode.openMic) {
      // Open mic: no strict exclusivity. Just add our user.
      await lockRef.child(myUserId).set({
        'updatedAtMs': nowMs,
      });
      lockRef.child(myUserId).onDisconnect().remove();
      return true;
    }

    // Intercom mode: strict single-speaker lock check via transaction.
    final result = await lockRef.runTransaction((Object? currentValue) {
      Map<dynamic, dynamic> currentMap = {};
      if (currentValue is Map) {
        currentMap = Map.from(currentValue);
      }

      bool canAcquire = true;
      for (final entry in currentMap.entries) {
        final uid = entry.key.toString();
        if (uid == myUserId) continue;

        final val = entry.value;
        if (val is Map) {
          final updatedAtRaw = val['updatedAtMs'];
          final updatedAt = updatedAtRaw is int ? updatedAtRaw : int.tryParse(updatedAtRaw?.toString() ?? '');
          final isStale = updatedAt != null && (nowMs - updatedAt) > lockTtl.inMilliseconds;
          if (!isStale) {
            canAcquire = false;
            break;
          }
        }
      }

      if (canAcquire) {
        return Transaction.success(<String, dynamic>{
          myUserId: {
            'updatedAtMs': nowMs,
          }
        });
      }

      return Transaction.abort();
    });

    if (result.committed) {
      lockRef.child(myUserId).onDisconnect().remove();
    }
    return result.committed;
  }

  Future<void> releaseSpeakerLock({
    required String roomId,
    required String myUserId,
  }) async {
    try {
      await _activeSpeakersRef(roomId).child(myUserId).remove();
    } catch (_) {}
  }

  Future<void> sendOffer({
    required String roomId,
    required String fromId,
    required String toId,
    required RTCSessionDescription offer,
  }) async {
    await _signalsRef(roomId, fromId, toId)
        .child('offer')
        .set(<String, dynamic>{
      'sdp': offer.sdp,
      'type': offer.type,
    });
  }

  Future<void> sendAnswer({
    required String roomId,
    required String fromId,
    required String toId,
    required RTCSessionDescription answer,
  }) async {
    await _signalsRef(roomId, fromId, toId)
        .child('answer')
        .set(<String, dynamic>{
      'sdp': answer.sdp,
      'type': answer.type,
    });
  }

  /// Watches for an SDP offer from [fromId] to [toId].
  ///
  /// Uses `onValue` which fires immediately with the current value. If the
  /// node is `null` (the other peer hasn't written yet) we silently skip it
  /// instead of throwing, which would kill the subscription and prevent us
  /// from ever receiving the real offer when it arrives moments later.
  Stream<RTCSessionDescription> watchOffer({
    required String roomId,
    required String fromId,
    required String toId,
  }) {
    final ref = _signalsRef(roomId, fromId, toId).child('offer');
    return ref.onValue
        .where((event) => event.snapshot.value != null) // ← skip nulls
        .map((event) {
      final map = event.snapshot.value as Map;
      final sdp = map['sdp']?.toString() ?? '';
      final type = map['type']?.toString() ?? 'offer';
      debugPrint('[Signaling] Received offer from $fromId → $toId');
      return RTCSessionDescription(sdp, type);
    });
  }

  /// Watches for an SDP answer from [fromId] to [toId].
  ///
  /// Same null-tolerance as [watchOffer].
  Stream<RTCSessionDescription> watchAnswer({
    required String roomId,
    required String fromId,
    required String toId,
  }) {
    final ref = _signalsRef(roomId, fromId, toId).child('answer');
    return ref.onValue
        .where((event) => event.snapshot.value != null) // ← skip nulls
        .map((event) {
      final map = event.snapshot.value as Map;
      final sdp = map['sdp']?.toString() ?? '';
      final type = map['type']?.toString() ?? 'answer';
      debugPrint('[Signaling] Received answer from $fromId → $toId');
      return RTCSessionDescription(sdp, type);
    });
  }

  Future<void> sendIceCandidate({
    required String roomId,
    required String fromId,
    required String toId,
    required RTCIceCandidate candidate,
  }) async {
    // Store candidates under a unique key so receivers can subscribe with
    // onChildAdded.
    final iceRef = _iceRef(roomId, fromId, toId);
    final newRef = iceRef.push();
    await newRef.set(<String, dynamic>{
      'candidate': candidate.candidate ?? '',
      'sdpMid': candidate.sdpMid ?? '',
      'sdpMLineIndex': candidate.sdpMLineIndex ?? 0,
    });
  }

  Stream<RTCIceCandidate> watchIceCandidates({
    required String roomId,
    required String fromId,
    required String toId,
  }) {
    return _iceRef(roomId, fromId, toId).onChildAdded.map((event) {
      final value = event.snapshot.value;
      if (value == null) {
        throw IntercomError('ICE candidate snapshot is null');
      }
      final map = value as Map;
      final candidateStr = map['candidate']?.toString();
      final sdpMid = map['sdpMid']?.toString();
      final idxRaw = map['sdpMLineIndex'];
      final sdpMLineIndex = idxRaw is int ? idxRaw : int.tryParse(idxRaw?.toString() ?? '');
      return RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);
    });
  }

  Future<void> broadcastTtsMessage({
    required String roomId,
    required TtsMessage message,
  }) async {
    final ref = _ttsMessagesRef(roomId).child(message.id);
    await ref.set(message.toJson());

    // Auto-clean old messages (older than 5 minutes)
    final fiveMinsAgo = DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch;
    final oldMessagesQuery = _ttsMessagesRef(roomId).orderByChild('timestamp').endAt(fiveMinsAgo);
    
    try {
      final snapshot = await oldMessagesQuery.once();
      if (snapshot.snapshot.value != null && snapshot.snapshot.value is Map) {
        final messages = Map<dynamic, dynamic>.from(snapshot.snapshot.value as Map);
        for (final key in messages.keys) {
          await _ttsMessagesRef(roomId).child(key.toString()).remove();
        }
      }
    } catch (e) {
      debugPrint('[Signaling] Failed to clean old TTS messages: $e');
    }
  }

  Stream<TtsMessage> watchTtsMessages(String roomId) async* {
    final existingKeys = <String>{};
    
    // 1. Snapshot the current keys so we don't play historical messages
    try {
      final snapshot = await _ttsMessagesRef(roomId).once();
      if (snapshot.snapshot.value != null && snapshot.snapshot.value is Map) {
        final messages = Map<dynamic, dynamic>.from(snapshot.snapshot.value as Map);
        existingKeys.addAll(messages.keys.map((e) => e.toString()));
      }
    } catch (e) {
      debugPrint('[Signaling] Failed to load existing TTS keys: $e');
    }

    // 2. Listen to child additions, ignoring any that were already present
    await for (final event in _ttsMessagesRef(roomId).onChildAdded) {
      final key = event.snapshot.key;
      final value = event.snapshot.value;
      if (key == null || value == null || value is! Map) continue;

      if (!existingKeys.contains(key)) {
        try {
          yield TtsMessage.fromJson(key, value);
        } catch (e) {
          debugPrint('[Signaling] Error parsing incoming TTS message: $e');
        }
      }
    }
  }
}
