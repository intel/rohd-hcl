// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_shift_register.dart
// Configurator for shift registers.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [ShiftRegister].
class ShiftRegisterConfigurator extends Configurator {
  /// Width of the data input and output.
  final IntConfigKnob widthKnob = IntConfigKnob(value: 8);

  /// Number of shift stages.
  final IntConfigKnob depthKnob = IntConfigKnob(value: 4);

  /// Whether to generate an enable input.
  final ToggleConfigKnob includeEnableKnob = ToggleConfigKnob(value: false);

  /// Whether to generate a reset input.
  final ToggleConfigKnob includeResetKnob = ToggleConfigKnob(value: false);

  /// Whether the reset is asynchronous.
  final ToggleConfigKnob asyncResetKnob = ToggleConfigKnob(value: false);

  /// Optional reset value applied to every stage.
  final IntOptionalConfigKnob resetValueKnob =
      IntOptionalConfigKnob(value: null);

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => UnmodifiableMapView({
        'Width': widthKnob,
        'Depth': depthKnob,
        'Generate Enable Input': includeEnableKnob,
        'Generate Reset Input': includeResetKnob,
        if (includeResetKnob.value) 'Asynchronous Reset': asyncResetKnob,
        if (includeResetKnob.value) 'Reset Value': resetValueKnob,
      });

  @override
  Module createModule() => ShiftRegister(
        Logic(width: widthKnob.value),
        clk: Logic(),
        depth: depthKnob.value,
        enable: includeEnableKnob.value ? Logic() : null,
        reset: includeResetKnob.value ? Logic() : null,
        asyncReset: includeResetKnob.value && asyncResetKnob.value,
        resetValue: includeResetKnob.value ? resetValueKnob.value : null,
      );

  @override
  String get name => 'Shift Register';
}
