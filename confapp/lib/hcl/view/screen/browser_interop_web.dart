// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// browser_interop_web.dart
// Browser implementations for Yosys, downloads, and context-menu suppression.
//
// 2026 September 25
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Wraps the browser worker used to synthesize generated RTL with Yosys.
class YosysWorker {
  /// Creates a worker from the JavaScript file at `scriptPath`.
  YosysWorker(String scriptPath) : _worker = web.Worker(scriptPath.toJS);

  final web.Worker _worker;

  /// Sends [message] to the Yosys worker.
  void postMessage(Map<String, String> message) {
    _worker.postMessage(message.jsify());
  }

  /// Returns the next message emitted by the Yosys worker.
  Future<String> nextMessage() => web.EventStreamProviders.messageEvent
      .forTarget(_worker)
      .first
      .then((event) => event.data.dartify()! as String);
}

/// Downloads [content] through a browser anchor using [fileName].
void downloadFile({required String content, required String fileName}) {
  final bytes = base64Encode(content.codeUnits);
  final uri = 'data:application/octet-stream;base64,$bytes';
  web.HTMLAnchorElement()
    ..href = uri
    ..download = fileName
    ..click();
}

/// Prevents the browser context menu from appearing over [child].
Widget browserContextMenuSuppressor({required Widget child}) =>
    _BrowserContextMenuSuppressor(child: child);

class _BrowserContextMenuSuppressor extends StatefulWidget {
  const _BrowserContextMenuSuppressor({required this.child});

  final Widget child;

  static int _refCount = 0;
  static web.EventListener? _listener;

  static void _attach() {
    if (_refCount == 0) {
      _listener = ((web.Event event) => event.preventDefault()).toJS;
      web.document.body?.addEventListener('contextmenu', _listener, true.toJS);
    }
    _refCount++;
  }

  static void _detach() {
    _refCount--;
    if (_refCount == 0 && _listener != null) {
      web.document.body
          ?.removeEventListener('contextmenu', _listener, true.toJS);
      _listener = null;
    }
  }

  @override
  State<_BrowserContextMenuSuppressor> createState() =>
      _BrowserContextMenuSuppressorState();
}

class _BrowserContextMenuSuppressorState
    extends State<_BrowserContextMenuSuppressor> {
  @override
  void initState() {
    super.initState();
    _BrowserContextMenuSuppressor._attach();
  }

  @override
  void dispose() {
    _BrowserContextMenuSuppressor._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
