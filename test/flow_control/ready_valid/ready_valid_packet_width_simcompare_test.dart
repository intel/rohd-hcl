// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_packet_width_simcompare_test.dart
// Checks generated RTL parity for packet framing and width conversion.
//
// 2026 August 29
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

TypedLogicArray<Logic, LogicValue> _array(int length, String name) =>
    TypedLogicArray<Logic, LogicValue>(
        [length], ({name}) => Logic(name: name, width: 8),
        name: name);

Future<void> _checkParity(Module module, List<Vector> vectors) async {
  await module.build();
  await SimCompare.checkFunctionalVector(module, vectors);
  SimCompare.checkIverilogVector(module, vectors);
}

List<Vector> _vectors(String dataPort, int data,
        {bool finalBeatInputReady = false}) =>
    [
      Vector({
        'clk': 0,
        'reset': 1,
        dataPort: 0,
        'upstream_valid': 0,
        'downstream_ready': 0
      }, {}),
      Vector({
        'clk': 1,
        'reset': 1,
        dataPort: 0,
        'upstream_valid': 0,
        'downstream_ready': 0
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        dataPort: 0,
        'upstream_valid': 0,
        'downstream_ready': 0
      }, {
        'upstream_ready': 1,
        'downstream_valid': 0
      }),
      Vector({
        'clk': 0,
        'reset': 0,
        dataPort: data,
        'upstream_valid': 1,
        'downstream_ready': 0
      }, {
        'upstream_ready': 1,
        'downstream_valid': 0
      }),
      Vector({
        'clk': 1,
        'reset': 0,
        dataPort: data,
        'upstream_valid': 1,
        'downstream_ready': 0
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        dataPort: 0,
        'upstream_valid': 0,
        'downstream_ready': 0
      }, {
        'upstream_ready': 0,
        'downstream_valid': 1
      }),
      Vector({
        'clk': 0,
        'reset': 0,
        dataPort: 0,
        'upstream_valid': 0,
        'downstream_ready': 1
      }, {
        'upstream_ready': finalBeatInputReady ? 1 : 0,
        'downstream_valid': 1
      }),
      Vector({
        'clk': 1,
        'reset': 0,
        dataPort: 0,
        'upstream_valid': 0,
        'downstream_ready': 1
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        dataPort: 0,
        'upstream_valid': 0,
        'downstream_ready': 0
      }, {
        'upstream_ready': 1,
        'downstream_valid': 0
      })
    ];

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('packetizer matches RTL while a frame is stalled', () async {
    await _checkParity(
        ReadyValidPacketizer(
            clk: Logic(),
            reset: Logic(),
            upstream: ReadyValidInterface<TypedLogicArray<Logic, LogicValue>>(
                _array(1, 'input')),
            downstream: ReadyValidInterface<Frame<Logic>>(
                Frame(Logic(name: 'output', width: 8)))),
        _vectors('upstream_input_', 0x11, finalBeatInputReady: true));
  });

  test('depacketizer matches RTL while a packet is stalled', () async {
    await _checkParity(
        ReadyValidDepacketizer(
            clk: Logic(),
            reset: Logic(),
            upstream: ReadyValidInterface<Frame<Logic>>(
                Frame(Logic(name: 'input', width: 8))),
            downstream: ReadyValidInterface<CollectedPacket<Logic>>(
                CollectedPacket(_array(1, 'output')))),
        _vectors('upstream_input__frame', 0x122, finalBeatInputReady: true));
  });
}
