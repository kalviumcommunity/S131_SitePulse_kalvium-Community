class WriteFailure {
  final String collection;
  final String documentId;
  final String message;
  final DateTime time;

  const WriteFailure({
    required this.collection,
    required this.documentId,
    required this.message,
    required this.time,
  });

  @override
  bool operator ==(Object other) =>
      other is WriteFailure &&
      other.collection == collection &&
      other.documentId == documentId &&
      other.message == message &&
      other.time == time;

  @override
  int get hashCode => Object.hash(collection, documentId, message, time);
}
