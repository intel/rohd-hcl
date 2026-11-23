// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_csr_example.dart
// Configurator for the CSR example.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Boundary of the example CSR module.
enum CsrExampleBoundary {
  /// A register block.
  block,

  /// A top containing the register block.
  top,
}

/// Configures a small CSR example with two read/write registers.
class CsrExampleConfigurator extends Configurator {
  /// Whether to generate the block or its enclosing top.
  final ChoiceConfigKnob<CsrExampleBoundary> boundaryKnob = ChoiceConfigKnob(
    CsrExampleBoundary.values,
    value: CsrExampleBoundary.top,
    choiceLabels: const {
      CsrExampleBoundary.block: 'Block',
      CsrExampleBoundary.top: 'Top',
    },
  );

  /// Width of both registers and the frontdoor data ports.
  final IntConfigKnob widthKnob = PositiveIntConfigKnob(value: 8);

  /// Whether registers use an asynchronous reset.
  final ToggleConfigKnob asyncResetKnob = ToggleConfigKnob(value: false);

  @override
  ComponentCategory get category => ComponentCategory.memory;
  @override
  String get subcategory => 'csr';
  @override
  String get name => 'CSR Example';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Boundary': boundaryKnob,
        'Register Width': widthKnob,
        'Asynchronous Reset': asyncResetKnob,
      };

  @override
  Module createModule() {
    final block = CsrBlockConfig(
      name: 'control',
      baseAddr: 0,
      registers: [
        for (var i = 0; i < 2; i++)
          CsrInstanceConfig(
            arch: CsrConfig(
              name: 'reg$i',
              access: CsrAccess.readWrite,
              fields: const [],
              isBackdoorWritable: false,
            ),
            addr: i,
            width: widthKnob.value,
            resetValue: i,
          ),
      ],
    );
    final clk = Logic(name: 'clk');
    final reset = Logic(name: 'reset');
    final read = DataPortInterface(widthKnob.value, 1);
    final write = DataPortInterface(widthKnob.value, 1);
    return switch (boundaryKnob.value) {
      CsrExampleBoundary.block => CsrBlock(
          config: block,
          clk: clk,
          reset: reset,
          frontRead: read,
          frontWrite: write,
          asyncReset: asyncResetKnob.value,
        ),
      CsrExampleBoundary.top => CsrTop(
          config: CsrTopConfig(
            name: 'example',
            blockSize: 2,
            blocks: [block],
            asyncReset: asyncResetKnob.value,
          ),
          clk: clk,
          reset: reset,
          frontRead: read,
          frontWrite: write,
          implementationConfiguration: const CsrImplementationConfiguration(),
        ),
    };
  }
}
