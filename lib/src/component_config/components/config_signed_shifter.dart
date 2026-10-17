// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_signed_shifter.dart
// Configurator for signed bidirectional shifting.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [SignedShifter].
class SignedShifterConfigurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.bitOperations;

  @override
  String get subcategory => 'shifting';

  /// Width of the shifted input and output.
  final IntConfigKnob dataWidthKnob = IntConfigKnob(value: 8);

  /// Width of the signed shift-amount input.
  final IntConfigKnob shiftWidthKnob = IntConfigKnob(value: 4);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Data Width': dataWidthKnob,
    'Shift Width': shiftWidthKnob,
  });

  @override
  Module createModule() => SignedShifter(
        Logic(width: dataWidthKnob.value),
        Logic(width: shiftWidthKnob.value),
      );

  @override
  String get name => 'Signed Shifter';
}
