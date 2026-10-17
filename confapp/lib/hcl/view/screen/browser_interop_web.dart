// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// browser_interop_web.dart
// Browser implementations for Yosys, downloads, and context-menu suppression.
//
// 2026 September 25
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:confapp/hcl/view/screen/browser_interop_web_core.dart';
import 'package:flutter/widgets.dart';

export 'browser_interop_web_core.dart' show YosysWorker, downloadFile;

/// Prevents the browser context menu from appearing over [child].
Widget browserContextMenuSuppressor({required Widget child}) =>
    _BrowserContextMenuSuppressor(child: child);

class _BrowserContextMenuSuppressor extends StatefulWidget {
  const _BrowserContextMenuSuppressor({required this.child});

  final Widget child;

  @override
  State<_BrowserContextMenuSuppressor> createState() =>
      _BrowserContextMenuSuppressorState();
}

class _BrowserContextMenuSuppressorState
    extends State<_BrowserContextMenuSuppressor> {
  @override
  void initState() {
    super.initState();
    BrowserContextMenuSuppression.attach();
  }

  @override
  void dispose() {
    BrowserContextMenuSuppression.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
