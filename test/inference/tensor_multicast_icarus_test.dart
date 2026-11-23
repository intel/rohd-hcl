// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_multicast_icarus_test.dart
// Tests for Tensor Multicast Icarus.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/inference/tensor_multicast.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('nested tensor multicast compiles in Icarus', () async {
    final harness = _TensorMulticastHarness(
      clk: Logic(),
      reset: Logic(),
      tile: inferenceLogicTensorTile(
        rowCount: 2,
        columnCount: 2,
        format: InferenceNumericFormat.signedInteger(8),
        name: 'tile',
      ),
      valid: Logic(),
      destinationMask: Logic(width: 2),
      ready0: Logic(),
      ready1: Logic(),
    );
    await harness.build();

    final directory =
        Directory.systemTemp.createTempSync('rohd_hcl_tensor_multicast_');
    final sourcePath = '${directory.path}/tensor_multicast_harness.sv';
    try {
      final systemVerilog = harness.dumpSystemVerilog();
      expect(systemVerilog, contains('module TensorMulticastHarness'));
      expect(systemVerilog, contains('module TensorTileMulticast_'));
      File(sourcePath).writeAsStringSync(systemVerilog);
      final result =
          Process.runSync('iverilog', ['-g2012', '-tnull', sourcePath]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('nested grouped-query distributor compiles in Icarus', () async {
    final harness = _GroupedQueryDistributionHarness(
      clk: Logic(),
      reset: Logic(),
      tile: inferenceLogicTensorTile(
        rowCount: 2,
        columnCount: 2,
        format: InferenceNumericFormat.signedInteger(8),
        name: 'gqaTile',
      ),
      valid: Logic(),
      keyValueHead: Logic(width: 2),
      ready: List.generate(4, (_) => Logic()),
    );
    await harness.build();

    final directory =
        Directory.systemTemp.createTempSync('rohd_hcl_gqa_distribution_');
    final sourcePath = '${directory.path}/gqa_distribution_harness.sv';
    try {
      final systemVerilog = harness.dumpSystemVerilog();
      expect(systemVerilog, contains('module GroupedQueryDistributionHarness'));
      expect(
        systemVerilog,
        contains('module GroupedQueryAttentionTileDistributor_'),
      );
      File(sourcePath).writeAsStringSync(systemVerilog);
      final result =
          Process.runSync('iverilog', ['-g2012', '-tnull', sourcePath]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}

class _TensorMulticastHarness extends Module {
  _TensorMulticastHarness({
    required Logic clk,
    required Logic reset,
    required InferenceTensorTile<Logic, LogicValue> tile,
    required Logic valid,
    required Logic destinationMask,
    required Logic ready0,
    required Logic ready1,
  }) : super(definitionName: 'TensorMulticastHarness') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    tile = addTypedInput('tile', tile);
    valid = addInput('valid', valid);
    destinationMask = addInput('destinationMask', destinationMask, width: 2);
    ready0 = addInput('ready0', ready0);
    ready1 = addInput('ready1', ready1);

    final upstream =
        ValidThenReadyInterface(tile.clone(name: 'multicastInput'));
    final downstreams = [
      ReadyValidInterface(tile.clone(name: 'multicastOutput0')),
      ReadyValidInterface(tile.clone(name: 'multicastOutput1')),
    ];
    upstream.data <= tile;
    upstream.valid <= valid;
    downstreams[0].ready <= ready0;
    downstreams[1].ready <= ready1;

    final multicast = TensorTileMulticast<Logic, LogicValue>(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstreams: downstreams,
      destinationMask: destinationMask,
    );

    addOutput('upstreamReady') <= upstream.ready;
    final output0 = addTypedOutput('output0', tile.clone);
    final output1 = addTypedOutput('output1', tile.clone);
    output0 <= downstreams[0].data;
    output1 <= downstreams[1].data;
    addOutput('valid0') <= downstreams[0].valid;
    addOutput('valid1') <= downstreams[1].valid;
    addOutput('occupied') <= multicast.occupied;
  }
}

class _GroupedQueryDistributionHarness extends Module {
  _GroupedQueryDistributionHarness({
    required Logic clk,
    required Logic reset,
    required InferenceTensorTile<Logic, LogicValue> tile,
    required Logic valid,
    required Logic keyValueHead,
    required List<Logic> ready,
  }) : super(definitionName: 'GroupedQueryDistributionHarness') {
    if (ready.length != 4) {
      throw ArgumentError.value(ready.length, 'ready', 'Must contain 4 bits.');
    }
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    tile = addTypedInput('tile', tile);
    valid = addInput('valid', valid);
    keyValueHead = addInput('keyValueHead', keyValueHead, width: 2);
    final localReady = [
      for (var head = 0; head < ready.length; head++)
        addInput('ready$head', ready[head]),
    ];

    final upstream = ValidThenReadyInterface(tile.clone(name: 'gqaInput'));
    final downstreams = [
      for (var head = 0; head < 4; head++)
        ReadyValidInterface(tile.clone(name: 'gqaOutput$head')),
    ];
    upstream.data <= tile;
    upstream.valid <= valid;
    for (var head = 0; head < downstreams.length; head++) {
      downstreams[head].ready <= localReady[head];
    }
    final distributor = GroupedQueryAttentionTileDistributor<Logic, LogicValue>(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstreams: downstreams,
      keyValueHead: keyValueHead,
      mapping: const GroupedQueryHeadMapping(
        queryHeadCount: 4,
        keyValueHeadCount: 2,
      ),
    );

    addOutput('upstreamReady') <= upstream.ready;
    for (var head = 0; head < downstreams.length; head++) {
      final output = addTypedOutput('output$head', tile.clone);
      output <= downstreams[head].data;
      addOutput('valid$head') <= downstreams[head].valid;
    }
    addOutput('occupied') <= distributor.occupied;
    addOutput('invalidKeyValueHead') <= distributor.invalidKeyValueHead;
  }
}
