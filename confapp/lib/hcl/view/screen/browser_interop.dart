// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// browser_interop.dart
// Selects browser-only integrations when compiling for the web.
//
// 2026 September 25
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

export 'browser_interop_stub.dart'
    if (dart.library.js_interop) 'browser_interop_web.dart';
