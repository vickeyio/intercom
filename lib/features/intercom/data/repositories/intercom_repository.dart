import 'dart:async';

import '../../domain/entities/communication_mode.dart';
import '../../domain/entities/intercom_event.dart';
import '../../domain/entities/intercom_role.dart';
import '../../domain/entities/tts_message.dart';

abstract class IntercomRepository {
  Stream<IntercomEvent> get events;

  Future<void> joinRoom({
    required String roomId,
    required String myUserId,
    required IntercomRole myRole,
  });

  /// Attempts to acquire the speaker lock and enable the microphone track.
  /// Returns `true` if the lock was acquired.
  Future<bool> tryStartTalking();

  /// Releases the speaker lock (if held) and disables the microphone track.
  Future<void> stopTalking();

  Future<void> leaveRoom();

  Future<void> setCommunicationMode({
    required String roomId,
    required CommunicationMode mode,
  });

  Future<void> broadcastTtsMessage(TtsMessage message);
  
  Stream<TtsMessage> watchTtsMessages(String roomId);
}

