import '../../../../core/errors/intercom_error.dart';
import '../entities/intercom_role.dart';
import '../entities/tts_message.dart';
import '../../data/repositories/intercom_repository.dart';

class UnauthorizedBroadcastException implements Exception {
  final String message;
  UnauthorizedBroadcastException(this.message);

  @override
  String toString() => message;
}

class BroadcastTtsMessageUseCase {
  final IntercomRepository _repository;

  BroadcastTtsMessageUseCase(this._repository);

  Future<void> call({
    required IntercomRole callerRole,
    required TtsMessage message,
  }) async {
    if (callerRole != IntercomRole.director) {
      throw UnauthorizedBroadcastException('Only the Director can broadcast TTS messages.');
    }

    if (message.text.trim().isEmpty) {
      throw IntercomError('TTS broadcast message cannot be empty.');
    }

    if (message.text.length > 300) {
      throw IntercomError('TTS broadcast message cannot exceed 300 characters.');
    }

    await _repository.broadcastTtsMessage(message);
  }
}
