// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// behavioral_model_example.dart
// Example of selecting, inspecting, and exporting behavioral models.
//
// 2026 October 20
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

// This executable example prints results for interactive inspection.
// ignore_for_file: avoid_print

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A small CSR map: a `control` block with a 16-bit `command` register.
CsrTopConfig exampleCsrConfig() => CsrTopConfig(
      name: 'device',
      blockSize: 64,
      blocks: [
        CsrBlockConfig(name: 'control', baseAddr: 0, registers: [
          CsrInstanceConfig(
            arch: CsrConfig(
                name: 'command', access: CsrAccess.readWrite, fields: const []),
            addr: 0,
            width: 16,
            resetValue: 0x0000,
          ),
        ]),
      ],
    );

/// Builds a software CSR top, then uses its raw state API and SystemC export.
Future<void> csrSoftwareModelExample() async {
  final top = CsrTop(
    config: exampleCsrConfig(),
    clk: Logic(name: 'clk'),
    reset: Logic(name: 'reset'),
    frontRead: DataPortInterface(16, 8),
    frontWrite: DataPortInterface(16, 8),
    implementationConfiguration: CsrImplementationConfiguration.software,
  );
  await top.build();

  final state = top.softwareModel!;
  final command = state.addressOf('control', 'command');

  // Raw access does not allocate signals or apply write side effects.
  state.poke(command, LogicValue.ofInt(0xbeef, 16));
  print('command after poke: ${state.peek(command)}');

  final saved = state.snapshot();
  state.load({}, replace: true);
  print('command after replace-load of nothing: ${state.peek(command)}');
  state.load(saved, replace: true);
  print('command after restoring snapshot: ${state.peek(command)}');

  // Two-state ports with an explicit unknown-output policy for SystemC.
  final header = top.generateModelSystemC(
    className: 'DeviceCsrs',
    options: const SystemCModelOptions(
      portType: SystemCModelPortType.twoState,
      unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset,
    ),
  );
  print('generated SystemC header: ${header.length} characters');
}

/// Uses the raw state adapter over existing sparse memory storage.
void memoryStorageStateExample() {
  final storage = SparseMemoryStorage(addrWidth: 8, dataWidth: 32);
  final state = MemoryStorageState(storage);

  // An absent sparse entry is distinct from a stored value.
  print('unpopulated address: ${state.peek(3)}');

  state.poke(3, LogicValue.ofInt(0x1234, 32));
  final saved = state.snapshot();
  state.load({}, replace: true);
  print('after replace-load of nothing: ${state.peek(3)}');
  state.load(saved, replace: true);
  print('after restoring snapshot: ${state.peek(3)}');
}

Future<void> main() async {
  await csrSoftwareModelExample();
  memoryStorageStateExample();
}
