// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// serialized_worker_request_queue.dart
// Serializes requests sent to a worker that returns uncorrelated responses.
//
// 2026 September 30
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:collection';

/// Serializes worker requests and pairs each with one [Response].
class SerializedWorkerRequestQueue<Response> {
  /// Creates an empty worker request queue.
  SerializedWorkerRequestQueue();

  final Queue<_PendingWorkerRequest<Response>> _waiting = Queue();

  _PendingWorkerRequest<Response>? _active;
  bool _disposed = false;

  /// Enqueues [send] and returns the eventual response to that request.
  Future<Response> add(void Function() send) {
    if (_disposed) {
      return Future.error(StateError('The worker request queue is disposed.'));
    }

    final pending = _PendingWorkerRequest<Response>(send);
    _waiting.addLast(pending);
    _sendNext();
    return pending.completer.future;
  }

  /// Completes the active request with [response] and dispatches the next one.
  void complete(Response response) {
    final active = _takeActive();
    active.completer.complete(response);
    _sendNext();
  }

  /// Fails the active request with [error] and dispatches the next one.
  void completeError(Object error, [StackTrace? stackTrace]) {
    final active = _takeActive();
    active.completer.completeError(error, stackTrace ?? StackTrace.current);
    _sendNext();
  }

  /// Fails all requests and prevents additional requests from being queued.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;

    final error = StateError('The worker request queue was disposed.');
    final stackTrace = StackTrace.current;
    final pending = [
      if (_active case final active?) active,
      ..._waiting,
    ];
    _active = null;
    _waiting.clear();
    for (final request in pending) {
      request.completer.completeError(error, stackTrace);
    }
  }

  _PendingWorkerRequest<Response> _takeActive() {
    final active = _active;
    if (active == null) {
      throw StateError('The worker responded without an active request.');
    }
    _active = null;
    return active;
  }

  void _sendNext() {
    if (_disposed || _active != null || _waiting.isEmpty) {
      return;
    }

    final next = _waiting.removeFirst();
    _active = next;
    try {
      next.send();
    } on Object catch (error, stackTrace) {
      _active = null;
      next.completer.completeError(error, stackTrace);
      _sendNext();
    }
  }
}

class _PendingWorkerRequest<Response> {
  _PendingWorkerRequest(this.send);

  final void Function() send;
  final Completer<Response> completer = Completer<Response>();
}
