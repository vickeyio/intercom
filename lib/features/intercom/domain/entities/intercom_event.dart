import 'communication_mode.dart';
import 'intercom_connection_status.dart';

sealed class IntercomEvent {
  const IntercomEvent();
}

class IntercomModeUpdated extends IntercomEvent {
  final CommunicationMode mode;
  const IntercomModeUpdated(this.mode);
}

class IntercomMembersUpdated extends IntercomEvent {
  final Set<String> memberIds;
  const IntercomMembersUpdated(this.memberIds);
}

class IntercomActiveSpeakersUpdated extends IntercomEvent {
  final Set<String> activeSpeakerIds;
  const IntercomActiveSpeakersUpdated(this.activeSpeakerIds);
}

class IntercomConnectionStatusUpdated extends IntercomEvent {
  final IntercomConnectionStatus status;
  final String? errorMessage;
  const IntercomConnectionStatusUpdated(this.status, {this.errorMessage});
}

class IntercomErrorEvent extends IntercomEvent {
  final String message;
  const IntercomErrorEvent(this.message);
}

