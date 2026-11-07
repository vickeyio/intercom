class TtsMessage {
  final String id;
  final String text;
  final String senderName;
  final String senderId;
  final DateTime timestamp;
  final String roomId;

  const TtsMessage({
    required this.id,
    required this.text,
    required this.senderName,
    required this.senderId,
    required this.timestamp,
    required this.roomId,
  });

  factory TtsMessage.fromJson(String id, Map<dynamic, dynamic> json) {
    return TtsMessage(
      id: id,
      text: json['text']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      roomId: json['roomId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'senderName': senderName,
      'senderId': senderId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'roomId': roomId,
    };
  }
}
