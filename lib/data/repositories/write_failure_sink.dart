import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:site_pulse/data/models/write_failure.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

final writeFailureSink = WriteFailureSink();

class WriteFailureSink {
  final List<WriteFailure> _failures = [];
  final _controller = StreamController<List<WriteFailure>>.broadcast();

  Stream<List<WriteFailure>> get failures =>
      Stream<List<WriteFailure>>.multi((controller) {
        controller.add(List.unmodifiable(_failures));
        final subscription = _controller.stream.listen(
          controller.add,
          onError: controller.addError,
        );
        controller.onCancel = subscription.cancel;
      });

  void report(String collection, RepositoryError error) {
    final failure = WriteFailure(
      collection: collection,
      documentId: error.documentId ?? '',
      message: error.message,
      time: DateTime.now(),
    );
    _failures.add(failure);
    debugPrint(
      'Write failure: collection=${failure.collection} '
      'documentId=${failure.documentId} message=${failure.message}',
    );
    _controller.add(List.unmodifiable(_failures));
  }

  void clear() {
    _failures.clear();
    _controller.add(const []);
  }
}
