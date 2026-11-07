// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_cam.dart
// Configurator for content-addressable memories.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [Cam].
class CamConfigurator extends Configurator {
  /// Number of CAM entries.
  final IntConfigKnob entryCountKnob = IntConfigKnob(value: 8);

  /// Width of each lookup tag.
  final IntConfigKnob tagWidthKnob = IntConfigKnob(value: 8);

  /// Number of independent write ports.
  final IntConfigKnob writePortCountKnob = IntConfigKnob(value: 1);

  /// Number of independent lookup ports.
  final IntConfigKnob lookupPortCountKnob = IntConfigKnob(value: 1);

  /// Whether to expose valid-entry count, full, and empty outputs.
  final ToggleConfigKnob validTrackingKnob = ToggleConfigKnob(value: false);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Entry Count': entryCountKnob,
    'Tag Width': tagWidthKnob,
    'Write Port Count': writePortCountKnob,
    'Lookup Port Count': lookupPortCountKnob,
    'Enable Valid Tracking': validTrackingKnob,
  });

  @override
  Module createModule() {
    if (entryCountKnob.value < 2) {
      throw RohdHclException(
          'A configurable CAM requires at least two entries.');
    }
    if (lookupPortCountKnob.value < 1) {
      throw RohdHclException('A CAM requires at least one lookup port.');
    }
    if (writePortCountKnob.value < 0) {
      throw RohdHclException(
          'A CAM cannot have a negative number of write ports.');
    }

    final indexWidth = log2Ceil(entryCountKnob.value);
    final writePorts = List<TagInterface>.generate(writePortCountKnob.value,
        (_) => TagInterface(indexWidth, tagWidthKnob.value));
    final lookupPorts = List<TagInterface>.generate(lookupPortCountKnob.value,
        (_) => TagInterface(indexWidth, tagWidthKnob.value));

    return Cam(
      Logic(),
      Logic(),
      writePorts,
      lookupPorts,
      numEntries: entryCountKnob.value,
      enableValidTracking: validTrackingKnob.value,
    );
  }

  @override
  String get name => 'Content-Addressable Memory';
}
