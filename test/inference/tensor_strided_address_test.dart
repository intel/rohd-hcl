// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _AddressStream extends Module {
  _AddressStream({
    InferenceMultiplierFunctor multiplier = nativeInferenceMultiplierFunctor,
  }) {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final upstream = ReadyValidInterface<TensorAddressCommand>(
      TensorAddressCommand(
          addressWidth: 8, mWidth: 3, nWidth: 3, kWidth: 3, commandIdWidth: 3),
    );
    final downstream = ReadyValidInterface<TensorAddressBeat>(
      TensorAddressBeat(
          addressWidth: 8, mWidth: 3, nWidth: 3, kWidth: 3, commandIdWidth: 3),
    );
    upstream.valid <= addInput('commandValid', Logic());
    downstream.ready <= addInput('addressReady', Logic());
    upstream.data.baseAddress <= addInput('base', Logic(width: 8), width: 8);
    upstream.data.mExtent <= addInput('mExtent', Logic(width: 3), width: 3);
    upstream.data.nExtent <= addInput('nExtent', Logic(width: 3), width: 3);
    upstream.data.kExtent <= addInput('kExtent', Logic(width: 3), width: 3);
    upstream.data.mStride <= addInput('mStride', Logic(width: 8), width: 8);
    upstream.data.nStride <= addInput('nStride', Logic(width: 8), width: 8);
    upstream.data.kStride <= addInput('kStride', Logic(width: 8), width: 8);
    upstream.data.commandId <= addInput('commandId', Logic(width: 3), width: 3);
    final generator = TensorStridedAddressGenerator(
        clk: clk,
        reset: reset,
        upstream: upstream,
        downstream: downstream,
        multiplierImplementation: multiplier);
    addOutput('commandReady') <= upstream.ready;
    addOutput('addressValid') <= downstream.valid;
    addOutput('address', width: 8) <= downstream.data.address;
    addOutput('m', width: 3) <= downstream.data.mIndex;
    addOutput('n', width: 3) <= downstream.data.nIndex;
    addOutput('k', width: 3) <= downstream.data.kIndex;
    addOutput('last') <= downstream.data.last;
    addOutput('overflow') <= downstream.data.overflow;
    addOutput('id', width: 3) <= downstream.data.commandId;
    addOutput('overflowCount', width: 32) <= generator.overflowedAddresses;
    addOutput('stallCount', width: 32) <= generator.stallCycles;
    addOutput('invalid') <= generator.invalidCommand;
  }
}

void main() {
  tearDown(Simulator.reset);

  test('rejects invalid address shapes', () {
    expect(
        () => TensorStridedAddress(
            baseAddress: Logic(), indices: [], strides: [], addressWidth: 1),
        throwsArgumentError);
    expect(
        () => TensorStridedAddress(
            baseAddress: Logic(),
            indices: [Logic()],
            strides: [],
            addressWidth: 1),
        throwsArgumentError);
    expect(
        () => TensorStridedAddress(
            baseAddress: Logic(),
            indices: [Logic()],
            strides: [Logic()],
            addressWidth: 0),
        throwsArgumentError);
  });

  test('random access keeps full precision and flags narrowing', () async {
    final dut = TensorStridedAddress(
      baseAddress: Logic(width: 16),
      indices: [Logic(width: 4), Logic(width: 8), Logic(width: 6)],
      strides: [Logic(width: 8), Logic(width: 12), Logic(width: 16)],
      addressWidth: 16,
    );
    await dut.build();
    final cases = [
      [0, 0, 0, 0, 0, 0, 0],
      [0xfffe, 1, 0, 0, 1, 0, 0],
      [0xffff, 1, 0, 0, 1, 0, 0],
      [0xffff, 15, 255, 63, 255, 4095, 65535],
      [123, 7, 9, 11, 64, 511, 4097],
    ];
    final vectors = [
      for (final c in cases)
        Vector({
          'baseAddress': c[0],
          for (var i = 0; i < 3; i++) 'index_$i': c[i + 1],
          for (var i = 0; i < 3; i++) 'stride_$i': c[i + 4],
        }, {
          'fullAddress': c[0] + c[1] * c[4] + c[2] * c[5] + c[3] * c[6],
          'address': (c[0] + c[1] * c[4] + c[2] * c[5] + c[3] * c[6]) & 0xffff,
          'overflow':
              c[0] + c[1] * c[4] + c[2] * c[5] + c[3] * c[6] > 0xffff ? 1 : 0,
        }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('single dimension supports an address wider than the full calculation',
      () async {
    final dut = TensorStridedAddress(
      baseAddress: Logic(width: 4),
      indices: [Logic(width: 3)],
      strides: [Logic(width: 5)],
      addressWidth: 16,
    );
    await dut.build();
    final vectors = [
      Vector({'baseAddress': 15, 'index_0': 7, 'stride_0': 31},
          {'fullAddress': 232, 'address': 232, 'overflow': 0}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('full result preserves carries beyond 64 bits', () async {
    final dut = TensorStridedAddress(
      baseAddress: Logic(width: 64),
      indices: [Logic(width: 64), Logic(width: 4)],
      strides: [Logic(width: 4), Logic(width: 4)],
      addressWidth: 64,
    );
    await dut.build();
    final maximum = (BigInt.one << 64) - BigInt.one;
    final full = maximum * BigInt.from(9) + BigInt.from(225);
    final vectors = [
      Vector({
        'baseAddress': maximum,
        'index_0': maximum,
        'index_1': 15,
        'stride_0': 8,
        'stride_1': 15,
      }, {
        'fullAddress': full,
        'address': full & maximum,
        'overflow': 1,
      }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  for (final multiplier in [
    nativeInferenceMultiplierFunctor,
    compressionTreeInferenceMultiplierFunctor(),
  ]) {
    test('stream retains commands and overflow with ${multiplier.identity}',
        () async {
      final dut = _AddressStream(multiplier: multiplier);
      await dut.build();
      final inputs = <String, int>{
        'clk': 0,
        'reset': 1,
        'commandValid': 0,
        'addressReady': 0,
        'base': 250,
        'mExtent': 1,
        'nExtent': 2,
        'kExtent': 2,
        'mStride': 32,
        'nStride': 8,
        'kStride': 5,
        'commandId': 7,
      };
      final vectors = <Vector>[];
      void vector(int clk, [Map<String, dynamic> expected = const {}]) {
        inputs['clk'] = clk;
        vectors.add(Vector(Map.of(inputs), expected));
      }

      vector(0);
      vector(1);
      inputs['reset'] = 0;
      inputs['commandValid'] = 1;
      vector(0, {'commandReady': 1, 'addressValid': 0});
      vector(1);
      inputs['commandValid'] = 0;
      inputs['base'] = 0;
      inputs['nStride'] = 1;
      inputs['commandId'] = 0;
      final first = {
        'addressValid': 1,
        'address': 250,
        'm': 0,
        'n': 0,
        'k': 0,
        'last': 0,
        'overflow': 0,
        'id': 7
      };
      vector(0, first);
      vector(1);
      vector(0, first);
      vector(1);
      inputs['addressReady'] = 1;
      vector(0, first);
      vector(1);
      vector(0, {'address': 255, 'n': 0, 'k': 1, 'overflow': 0, 'id': 7});
      vector(1);
      vector(0, {'address': 2, 'n': 1, 'k': 0, 'overflow': 1, 'id': 7});
      vector(1);
      vector(
          0, {'address': 7, 'n': 1, 'k': 1, 'last': 1, 'overflow': 1, 'id': 7});
      vector(1);
      inputs['addressReady'] = 0;
      vector(0, {
        'addressValid': 0,
        'commandReady': 1,
        'overflowCount': 2,
        'stallCount': 2
      });
      inputs['commandValid'] = 1;
      inputs['mExtent'] = 0;
      vector(0);
      vector(1);
      inputs['commandValid'] = 0;
      vector(0, {'addressValid': 0, 'invalid': 1});
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }
}
