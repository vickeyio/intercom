import '../../../../core/errors/intercom_error.dart';
import '../../data/repositories/intercom_repository.dart';
import '../entities/communication_mode.dart';
import '../entities/intercom_role.dart';

class SetCommunicationModeUseCase {
  SetCommunicationModeUseCase({
    required IntercomRepository repository,
  }) : _repository = repository;

  final IntercomRepository _repository;

  Future<void> call({
    required String roomId,
    required IntercomRole myRole,
    required CommunicationMode newMode,
  }) async {
    if (myRole != IntercomRole.director) {
      throw IntercomError('Only the director can change the communication mode');
    }
    await _repository.setCommunicationMode(roomId: roomId, mode: newMode);
  }
}
