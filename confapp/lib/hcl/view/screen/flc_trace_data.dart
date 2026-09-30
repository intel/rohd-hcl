// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// flc_trace_data.dart
// Reads source trace data embedded in a ROHD netlist.
//
// 2026 September 30
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';

import 'package:rohd_source_navigator/flc_data.dart';

/// Returns source trace data embedded in [netlistJson], when present.
///
/// ROHD 0.6.11 does not emit `rohd.src_trace` attributes. Trace-enabled future
/// ROHD releases can provide them without requiring a Confapp API change.
FlcData? embeddedFlcDataFromNetlistJson(String netlistJson) {
  final decoded = jsonDecode(netlistJson);
  if (decoded is! Map) {
    throw const FormatException('ROHD netlist JSON must contain an object.');
  }

  final flcData = FlcData.fromNetlistJson(
    Map<String, dynamic>.from(decoded),
  );
  return flcData.isEmpty ? null : flcData;
}
