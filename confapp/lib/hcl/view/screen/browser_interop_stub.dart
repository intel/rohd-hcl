// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// browser_interop_stub.dart
// VM-safe implementations of browser-only integrations.
//
// 2026 September 25
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:flutter/widgets.dart';

/// VM placeholder for the web worker used to synthesize generated RTL.
class YosysWorker {
  /// Creates a placeholder for the worker at `scriptPath`.
  YosysWorker(this._scriptPath);

  final String _scriptPath;

  /// Reports that [message] cannot be sent from the VM.
  void postMessage(Map<String, String> message) {
    throw UnsupportedError(
      'Yosys synthesis via $_scriptPath is only available on web.',
    );
  }

  /// Reports that the browser worker is unavailable on the VM.
  Future<String> nextMessage() => Future.error(
        UnsupportedError(
          'Yosys synthesis via $_scriptPath is only available on web.',
        ),
      );
}

/// Reports that downloading [content] to [fileName] requires a browser.
void downloadFile({required String content, required String fileName}) {
  throw UnsupportedError('File downloads are only available on web.');
}

/// Returns [child] without browser-specific context-menu handling.
Widget browserContextMenuSuppressor({required Widget child}) => child;
