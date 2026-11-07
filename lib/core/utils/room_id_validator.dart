class RoomIdValidator {
  RoomIdValidator._();

  static bool isValid(String roomId) {
    final trimmed = roomId.trim();
    if (trimmed.isEmpty) return false;
    // MVP: allow alphanumerics, underscore, dash.
    return RegExp(r'^[A-Za-z0-9_-]{3,64}$').hasMatch(trimmed);
  }
}

