import '../entities/tts_message.dart';
import '../../data/repositories/intercom_repository.dart';

class ListenTtsMessagesUseCase {
  final IntercomRepository _repository;

  ListenTtsMessagesUseCase(this._repository);

  Stream<TtsMessage> call({required String roomId}) {
    return _repository.watchTtsMessages(roomId);
  }
}
