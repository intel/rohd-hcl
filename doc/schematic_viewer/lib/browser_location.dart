// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// browser_location.dart
// Selects browser location access when compiling for the web.
//
// 2026 September 30
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

export 'browser_location_stub.dart'
    if (dart.library.js_interop) 'browser_location_web.dart';
