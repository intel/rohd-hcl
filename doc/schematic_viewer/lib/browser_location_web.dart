// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// browser_location_web.dart
// Browser implementation of location access.
//
// 2026 September 30
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:web/web.dart' as web;

/// Returns the current browser page location.
Uri currentBrowserLocation() => Uri.parse(web.window.location.href);
