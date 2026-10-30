class RepositoryError {
  final String operation;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final String? documentId;

  const RepositoryError({
    required this.operation,
    required this.message,
    this.error,
    this.stackTrace,
    this.documentId,
  });

  @override
  String toString() =>
      'RepositoryError(operation: $operation, message: $message, documentId: $documentId, error: $error)';
}
