import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../features/intercom/data/datasources/signaling_service.dart';
import '../../features/intercom/data/datasources/webrtc_service.dart';
import '../../features/intercom/data/repositories/intercom_repository.dart';
import '../../features/intercom/data/repositories/intercom_repository_impl.dart';
import '../../features/intercom/domain/usecases/join_room_usecase.dart';
import '../../features/intercom/domain/usecases/set_communication_mode.dart';
import '../../features/intercom/domain/usecases/toggle_ptt_usecase.dart';
import '../../features/intercom/domain/usecases/broadcast_tts_message.dart';
import '../../features/intercom/domain/usecases/listen_tts_messages.dart';
import '../../features/intercom/presentation/controllers/intercom_controller.dart';

final intercomRepositoryProvider = Provider<IntercomRepository>((ref) {
  return IntercomRepositoryImpl(
    signalingService: SignalingService(),
    webRtcService: WebRtcService(),
  );
});

final intercomControllerProvider =
    StateNotifierProvider<IntercomController, IntercomControllerState>(
  (ref) {
    final repository = ref.watch(intercomRepositoryProvider);
    return IntercomController(
      repository: repository,
      joinRoomUseCase: JoinRoomUseCase(repository),
      togglePttUseCase: TogglePttUseCase(repository),
      setCommunicationModeUseCase: SetCommunicationModeUseCase(repository: repository),
      broadcastTtsMessageUseCase: BroadcastTtsMessageUseCase(repository),
      listenTtsMessagesUseCase: ListenTtsMessagesUseCase(repository),
    );
  },
);

