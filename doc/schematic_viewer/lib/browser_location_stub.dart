// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// browser_location_stub.dart
// VM-safe placeholder for browser location access.
//
// 2026 September 30
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

/// Reports that the current browser location is unavailable on the VM.
Uri currentBrowserLocation() => throw UnsupportedError(
      'The current browser location is only available on web.',
    );
