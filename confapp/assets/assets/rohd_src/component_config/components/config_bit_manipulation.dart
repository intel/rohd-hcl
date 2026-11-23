// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_bit_manipulation.dart
// Configurators for bit manipulation components.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configures constant-fill padding.
class PadConfigurator extends Configurator {
  /// Input width.
  final IntConfigKnob widthKnob = PositiveIntConfigKnob(value: 8);

  /// Minimum output width.
  final IntConfigKnob minimumWidthKnob = PositiveIntConfigKnob(value: 16);

  /// Pad at the least significant end.
  final ToggleConfigKnob lsbsKnob = ToggleConfigKnob(value: true);

  /// Fill inserted bits with ones.
  final ToggleConfigKnob fillKnob = ToggleConfigKnob(value: false);

  @override
  ComponentCategory get category => ComponentCategory.bitOperations;
  @override
  String get subcategory => 'shifting';
  @override
  String get name => 'Pad';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Input Width': widthKnob,
        'Minimum Output Width': minimumWidthKnob,
        'Pad LSBs': lsbsKnob,
        'Fill Ones': fillKnob,
      };
  @override
  Module createModule() => Pad(
        Logic(width: widthKnob.value),
        atLeast: minimumWidthKnob.value,
        lsbs: lsbsKnob.value,
        fill: fillKnob.value,
      );
}

/// Configures runtime bit filling.
class SetBitsConfigurator extends Configurator {
  /// Input width.
  final IntConfigKnob widthKnob = PositiveIntConfigKnob(value: 8);

  /// Width of the runtime count.
  final IntConfigKnob countWidthKnob = PositiveIntConfigKnob(value: 4);

  /// Set bits at the least significant end.
  final ToggleConfigKnob lsbsKnob = ToggleConfigKnob(value: true);

  /// Fill selected bits with ones.
  final ToggleConfigKnob fillKnob = ToggleConfigKnob(value: false);

  @override
  ComponentCategory get category => ComponentCategory.bitOperations;
  @override
  String get subcategory => 'shifting';
  @override
  String get name => 'Set Bits';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Input Width': widthKnob,
        'Count Width': countWidthKnob,
        'Set LSBs': lsbsKnob,
        'Fill Ones': fillKnob,
      };
  @override
  Module createModule() => SetBits(
        Logic(name: 'inp', width: widthKnob.value),
        Logic(name: 'count', width: countWidthKnob.value),
        lsbs: lsbsKnob.value,
        fill: fillKnob.value,
      );
}

/// Configures replacement of a runtime-selected bit range.
class WithSetConfigurator extends Configurator {
  /// Width of the subject.
  final IntConfigKnob widthKnob = PositiveIntConfigKnob(value: 8);

  /// Width of the replacement value.
  final IntConfigKnob valueWidthKnob = PositiveIntConfigKnob(value: 4);

  /// Width of the runtime start index.
  final IntConfigKnob startWidthKnob = PositiveIntConfigKnob(value: 4);

  @override
  ComponentCategory get category => ComponentCategory.bitOperations;
  @override
  String get subcategory => 'shifting';
  @override
  String get name => 'With Set';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Subject Width': widthKnob,
        'Value Width': valueWidthKnob,
        'Start Width': startWidthKnob,
      };
  @override
  Module createModule() => WithSet(
        Logic(name: 'subject', width: widthKnob.value),
        Logic(name: 'start', width: startWidthKnob.value),
        Logic(name: 'value', width: valueWidthKnob.value),
      );
}
