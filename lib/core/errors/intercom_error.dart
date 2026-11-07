class IntercomError implements Exception {
  final String message;

  const IntercomError(this.message);

  @override
  String toString() => 'IntercomError: $message';
}

