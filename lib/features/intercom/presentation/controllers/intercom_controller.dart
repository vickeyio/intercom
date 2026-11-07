import 'dart:async';

import 'package:flutter/widgets.dart'; // For WidgetsBindingObserver later if needed
import 'package:state_notifier/state_notifier.dart';

import '../../../../core/services/notification_service.dart';
import '../../services/tts_service.dart';
import '../../domain/entities/tts_message.dart';
import '../../domain/entities/communication_mode.dart';
import '../../domain/entities/intercom_connection_status.dart';
import '../../domain/entities/intercom_event.dart';
import '../../domain/entities/intercom_role.dart';
import '../../domain/usecases/join_room_usecase.dart';
import '../../domain/usecases/set_communication_mode.dart';
import '../../domain/usecases/toggle_ptt_usecase.dart';
import '../../domain/usecases/broadcast_tts_message.dart';
import '../../domain/usecases/listen_tts_messages.dart';
import '../../data/repositories/intercom_repository.dart';

class IntercomControllerState {
  final IntercomConnectionStatus connectionStatus;
  final Set<String> memberIds;
  final Set<String> activeSpeakerIds;
  final String? errorMessage;
  final bool amTalking;
  final CommunicationMode communicationMode;
  final List<TtsMessage> ttsMessageHistory;
  final bool isTtsSpeaking;
  final String pendingTtsText;
  final List<TtsMessage> queuedTtsMessages;

  const IntercomControllerState({
    required this.connectionStatus,
    required this.memberIds,
    required this.activeSpeakerIds,
    required this.errorMessage,
    required this.amTalking,
    required this.communicationMode,
    required this.ttsMessageHistory,
    required this.isTtsSpeaking,
    required this.pendingTtsText,
    required this.queuedTtsMessages,
  });

  const IntercomControllerState.initial()
      : connectionStatus = IntercomConnectionStatus.disconnected,
        memberIds = const <String>{},
        activeSpeakerIds = const <String>{},
        errorMessage = null,
        amTalking = false,
        communicationMode = CommunicationMode.intercom,
        ttsMessageHistory = const [],
        isTtsSpeaking = false,
        pendingTtsText = '',
        queuedTtsMessages = const [];

  IntercomControllerState copyWith({
    IntercomConnectionStatus? connectionStatus,
    Set<String>? memberIds,
    Set<String>? activeSpeakerIds,
    String? errorMessage,
    bool? amTalking,
    CommunicationMode? communicationMode,
    List<TtsMessage>? ttsMessageHistory,
    bool? isTtsSpeaking,
    String? pendingTtsText,
    List<TtsMessage>? queuedTtsMessages,
    bool clearError = false,
  }) {
    return IntercomControllerState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      memberIds: memberIds ?? this.memberIds,
      activeSpeakerIds: activeSpeakerIds ?? this.activeSpeakerIds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      amTalking: amTalking ?? this.amTalking,
      communicationMode: communicationMode ?? this.communicationMode,
      ttsMessageHistory: ttsMessageHistory ?? this.ttsMessageHistory,
      isTtsSpeaking: isTtsSpeaking ?? this.isTtsSpeaking,
      pendingTtsText: pendingTtsText ?? this.pendingTtsText,
      queuedTtsMessages: queuedTtsMessages ?? this.queuedTtsMessages,
    );
  }
}


class IntercomController extends StateNotifier<IntercomControllerState> with WidgetsBindingObserver {
  IntercomController({
    required IntercomRepository repository,
    required JoinRoomUseCase joinRoomUseCase,
    required TogglePttUseCase togglePttUseCase,
    required SetCommunicationModeUseCase setCommunicationModeUseCase,
    required BroadcastTtsMessageUseCase broadcastTtsMessageUseCase,
    required ListenTtsMessagesUseCase listenTtsMessagesUseCase,
  })  : _repository = repository,
        _joinRoomUseCase = joinRoomUseCase,
        _togglePttUseCase = togglePttUseCase,
        _setCommunicationModeUseCase = setCommunicationModeUseCase,
        _broadcastTtsMessageUseCase = broadcastTtsMessageUseCase,
        _listenTtsMessagesUseCase = listenTtsMessagesUseCase,
        super(const IntercomControllerState.initial()) {
    WidgetsBinding.instance.addObserver(this);
    TtsService().isSpeaking.addListener(_onTtsSpeakingChanged);
  }

  final IntercomRepository _repository;
  final JoinRoomUseCase _joinRoomUseCase;
  final TogglePttUseCase _togglePttUseCase;
  final SetCommunicationModeUseCase _setCommunicationModeUseCase;
  final BroadcastTtsMessageUseCase _broadcastTtsMessageUseCase;
  final ListenTtsMessagesUseCase _listenTtsMessagesUseCase;

  StreamSubscription<IntercomEvent>? _eventsSub;
  StreamSubscription<TtsMessage>? _ttsSub;
  String? _myUserId;
  String? _roomId;
  IntercomRole? _myRole;

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    _appLifecycleState = lifecycleState;
  }

  void _onTtsSpeakingChanged() {
    state = state.copyWith(isTtsSpeaking: TtsService().isSpeaking.value);
    
    // If TTS stopped and we have queued messages, and we are not currently talking, play the next one
    if (!TtsService().isSpeaking.value && !state.amTalking && state.queuedTtsMessages.isNotEmpty) {
      _playNextQueuedTts();
    }
  }

  void _playNextQueuedTts() {
    if (state.queuedTtsMessages.isEmpty) return;
    
    final nextMsg = state.queuedTtsMessages.first;
    final updatedQueue = List<TtsMessage>.from(state.queuedTtsMessages)..removeAt(0);
    
    state = state.copyWith(queuedTtsMessages: updatedQueue);
    TtsService().speak(nextMsg.text);
  }

  void updateTtsText(String text) {
    state = state.copyWith(pendingTtsText: text);
  }

  Future<void> broadcastTtsMessage() async {
    final text = state.pendingTtsText.trim();
    if (text.isEmpty || _roomId == null || _myRole == null || _myUserId == null) return;

    final msg = TtsMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      senderName: 'Director', // Or get from actual profile
      senderId: _myUserId!,
      timestamp: DateTime.now(),
      roomId: _roomId!,
    );

    try {
      await _broadcastTtsMessageUseCase(callerRole: _myRole!, message: msg);
      state = state.copyWith(pendingTtsText: '');
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString(),
        clearError: false,
      );
    }
  }

  void _ensureSubscription() {
    _eventsSub?.cancel();
    _eventsSub = _repository.events.listen((event) {
      switch (event) {
        case IntercomMembersUpdated():
          state = state.copyWith(memberIds: event.memberIds, clearError: true);
        case IntercomActiveSpeakersUpdated():
          final speakers = event.activeSpeakerIds;
          final amTalking = _myUserId != null && speakers.contains(_myUserId!);
          
          final wasTalking = state.amTalking;
          state = state.copyWith(
            activeSpeakerIds: speakers,
            amTalking: amTalking,
            clearError: true,
          );
          
          // If we just stopped talking and there are queued messages, start playing them.
          if (wasTalking && !amTalking && state.queuedTtsMessages.isNotEmpty) {
            // Give a tiny delay for audio routing to switch back from mic to speaker if needed
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!state.amTalking && !TtsService().isSpeaking.value) {
                _playNextQueuedTts();
              }
            });
          }

        case IntercomConnectionStatusUpdated():
          state = state.copyWith(
            connectionStatus: event.status,
            errorMessage: event.errorMessage,
            clearError: event.errorMessage == null,
          );
        case IntercomModeUpdated():
          state = state.copyWith(communicationMode: event.mode, clearError: true);
        case IntercomErrorEvent():
          state = state.copyWith(
            connectionStatus: IntercomConnectionStatus.error,
            errorMessage: event.message,
          );
      }
    });

    _ttsSub?.cancel();
    if (_roomId != null) {
      _ttsSub = _listenTtsMessagesUseCase(roomId: _roomId!).listen(_onTtsMessageReceived);
    }
  }

  void _onTtsMessageReceived(TtsMessage msg) {
    // Add to history
    final newHistory = List<TtsMessage>.from(state.ttsMessageHistory)..insert(0, msg);
    if (newHistory.length > 10) newHistory.removeLast(); // Keep last 10

    state = state.copyWith(ttsMessageHistory: newHistory);

    // Should we queue it? DO NOT queue or play if we are the sender
    if (msg.senderId != _myUserId) {
      if (state.amTalking || state.isTtsSpeaking || state.queuedTtsMessages.isNotEmpty) {
        final updatedQueue = List<TtsMessage>.from(state.queuedTtsMessages)..add(msg);
        state = state.copyWith(queuedTtsMessages: updatedQueue);
      } else {
        // Play immediately
        TtsService().speak(msg.text);
      }
      
      // Show Local Notification if app is in background
      if (_appLifecycleState == AppLifecycleState.paused || _appLifecycleState == AppLifecycleState.hidden || _appLifecycleState == AppLifecycleState.inactive) {
        NotificationService().showTtsNotification(
          senderName: msg.senderName,
          message: msg.text,
        );
      }
    }
  }

  Future<void> joinRoom({
    required String roomId,
    required String myUserId,
    required IntercomRole myRole,
  }) async {
    _myUserId = myUserId;
    _roomId = roomId;
    _myRole = myRole;
    _ensureSubscription();
    await _joinRoomUseCase.call(
      roomId: roomId,
      myUserId: myUserId,
      myRole: myRole,
    );
  }

  bool get amActiveSpeaker => _myUserId != null && state.activeSpeakerIds.contains(_myUserId!);

  Future<void> setCommunicationMode(CommunicationMode mode) async {
    if (_roomId == null || _myRole == null) return;
    await _setCommunicationModeUseCase.call(
      roomId: _roomId!,
      myRole: _myRole!,
      newMode: mode,
    );
  }

  Future<bool> startTalk() async {
    // If TTS is currently speaking, wait, or let it overlap?
    // Usually PTT duck/pauses TTS, or just plays over. We let it start.
    return _togglePttUseCase.call(enable: true);
  }

  Future<void> stopTalk() async {
    await _togglePttUseCase.call(enable: false);
  }

  Future<void> leaveRoom() async {
    await _eventsSub?.cancel();
    await _ttsSub?.cancel();
    _eventsSub = null;
    _ttsSub = null;
    await _repository.leaveRoom();
    _myUserId = null;
    _roomId = null;
    _myRole = null;
    state = const IntercomControllerState.initial();
    
    await TtsService().stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TtsService().isSpeaking.removeListener(_onTtsSpeakingChanged);
    _eventsSub?.cancel();
    _ttsSub?.cancel();
    TtsService().stop();
    super.dispose();
  }
}

