// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// browser_interop_web_core.dart
// Browser integrations that do not depend on the Flutter framework.
//
// 2026 September 30
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:confapp/hcl/view/screen/serialized_worker_request_queue.dart';
import 'package:web/web.dart' as web;

/// Wraps the browser worker used to synthesize generated RTL with Yosys.
class YosysWorker {
  /// Creates a worker from the JavaScript file at `scriptPath`.
  YosysWorker(String scriptPath) : _worker = web.Worker(scriptPath.toJS) {
    _requests = SerializedWorkerRequestQueue();
    _messageSubscription = web.EventStreamProviders.messageEvent
        .forTarget(_worker)
        .listen(_handleMessage);
  }

  final web.Worker _worker;
  late final SerializedWorkerRequestQueue<String> _requests;
  late final StreamSubscription<web.MessageEvent> _messageSubscription;

  /// Synthesizes the RTL described by [message].
  ///
  /// Requests are serialized because the worker response does not contain a
  /// correlation identifier.
  Future<String> synthesize(Map<String, String> message) {
    final immutableMessage = Map<String, String>.unmodifiable(message);
    return _requests.add(() => _postMessage(immutableMessage));
  }

  void _postMessage(Map<String, String> message) {
    _worker.postMessage(message.jsify());
  }

  void _handleMessage(web.MessageEvent event) {
    try {
      final response = event.data.dartify();
      if (response is! String) {
        throw const FormatException(
          'The Yosys worker returned a non-string response.',
        );
      }
      _requests.complete(response);
    } on Object catch (error, stackTrace) {
      _requests.completeError(error, stackTrace);
    }
  }

  /// Releases the worker and fails any requests that are still pending.
  void dispose() {
    _requests.dispose();
    unawaited(_messageSubscription.cancel());
    _worker.terminate();
  }
}

/// Downloads [content] through a browser anchor using [fileName].
void downloadFile({required String content, required String fileName}) {
  final bytes = base64Encode(utf8.encode(content));
  final uri = 'data:application/octet-stream;base64,$bytes';
  final anchor = web.HTMLAnchorElement()
    ..href = uri
    ..download = fileName;
  web.document.body?.appendChild(anchor);
  try {
    anchor.click();
  } finally {
    anchor.remove();
  }
}

/// Reference-counts browser context-menu suppression.
class BrowserContextMenuSuppression {
  static int _refCount = 0;
  static web.EventListener? _listener;

  /// Prevents browser context menus until balanced by [detach].
  static void attach() {
    if (_refCount == 0) {
      _listener = ((web.Event event) => event.preventDefault()).toJS;
      web.document.body?.addEventListener('contextmenu', _listener, true.toJS);
    }
    _refCount++;
  }

  /// Releases one context-menu suppression reference.
  static void detach() {
    if (_refCount == 0) {
      throw StateError('Context-menu suppression is not attached.');
    }
    _refCount--;
    if (_refCount == 0 && _listener != null) {
      web.document.body
          ?.removeEventListener('contextmenu', _listener, true.toJS);
      _listener = null;
    }
  }
}
