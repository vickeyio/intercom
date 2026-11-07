import '../../data/repositories/intercom_repository.dart';

class TogglePttUseCase {
  final IntercomRepository _repository;

  const TogglePttUseCase(this._repository);

  Future<bool> call({required bool enable}) async {
    if (enable) {
      return _repository.tryStartTalking();
    }
    await _repository.stopTalking();
    return true;
  }
}

