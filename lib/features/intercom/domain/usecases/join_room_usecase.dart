import '../entities/intercom_role.dart';
import '../../data/repositories/intercom_repository.dart';

class JoinRoomUseCase {
  final IntercomRepository _repository;

  const JoinRoomUseCase(this._repository);

  Future<void> call({
    required String roomId,
    required String myUserId,
    required IntercomRole myRole,
  }) {
    return _repository.joinRoom(
      roomId: roomId,
      myUserId: myUserId,
      myRole: myRole,
    );
  }
}

