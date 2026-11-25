// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_strided_address_generator_test.dart
// Tests for Tensor Strided Address Generator.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('generates retained M/N/K strided addresses in K-inner order', () async {
    final fixture = _AddressFixture();
    await fixture.buildAndReset();
    await fixture.send(
      base: 10,
      mExtent: 2,
      nExtent: 2,
      kExtent: 3,
      mStride: 24,
      nStride: 6,
      kStride: 2,
      commandId: 5,
    );
    expect(fixture.dut.busy.value, LogicValue.one);
    expect(fixture.downstream.valid.value, LogicValue.one);

    final addresses = <int>[];
    final coordinates = <(int, int, int)>[];
    for (var beat = 0; beat < 12; beat++) {
      expect(
        fixture.downstream.valid.value,
        LogicValue.one,
        reason: 'beat=$beat',
      );
      addresses.add(fixture.downstream.data.address.value.toInt());
      coordinates.add((
        fixture.downstream.data.mIndex.value.toInt(),
        fixture.downstream.data.nIndex.value.toInt(),
        fixture.downstream.data.kIndex.value.toInt(),
      ));
      expect(fixture.downstream.data.commandId.value.toInt(), 5);
      if (beat == 3) {
        final retained = fixture.downstream.data.value;
        await fixture.clk.nextPosedge;
        await fixture.clk.nextPosedge;
        expect(fixture.downstream.data.value, retained);
      }
      await fixture.acceptOutput();
      if (beat < 11) {
        expect(
          fixture.downstream.valid.value,
          LogicValue.one,
          reason: 'next beat after $beat',
        );
      }
    }

    expect(addresses, [10, 12, 14, 16, 18, 20, 34, 36, 38, 40, 42, 44]);
    expect(coordinates.first, (0, 0, 0));
    expect(coordinates.last, (1, 1, 2));
    expect(fixture.dut.commandsAccepted.value.toInt(), 1);
    expect(fixture.dut.addressesAccepted.value.toInt(), 12);
    expect(fixture.dut.stallCycles.value.toInt(), greaterThanOrEqualTo(2));
    expect(fixture.dut.overflowedAddresses.value.toInt(), 0);
    await Simulator.endSimulation();
  });

  test('reports wrapped address overflow', () async {
    final fixture = _AddressFixture();
    await fixture.buildAndReset();
    await fixture.send(
      base: 250,
      mExtent: 1,
      nExtent: 1,
      kExtent: 2,
      mStride: 0,
      nStride: 0,
      kStride: 10,
      commandId: 1,
    );
    expect(fixture.downstream.valid.value, LogicValue.one);

    expect(fixture.downstream.data.address.value.toInt(), 250);
    expect(fixture.downstream.data.overflow.value, LogicValue.zero);
    await fixture.acceptOutput();
    expect(fixture.downstream.valid.value, LogicValue.one);
    expect(fixture.downstream.data.address.value.toInt(), 4);
    expect(fixture.downstream.data.overflow.value, LogicValue.one);
    await fixture.acceptOutput();
    expect(fixture.dut.overflowedAddresses.value.toInt(), 1);
    await Simulator.endSimulation();
  });

  test('accepts and diagnoses a zero-extent command', () async {
    final fixture = _AddressFixture();
    await fixture.buildAndReset();
    await fixture.send(
      base: 0,
      mExtent: 0,
      nExtent: 1,
      kExtent: 1,
      mStride: 1,
      nStride: 1,
      kStride: 1,
      commandId: 0,
    );
    expect(fixture.dut.invalidCommand.value, LogicValue.one);
    expect(fixture.downstream.valid.value, LogicValue.zero);
    await Simulator.endSimulation();
  });

  test('software address helper matches generated arithmetic', () {
    expect(
      tensorStridedAddress(
        baseAddress: BigInt.from(10),
        mIndex: 1,
        nIndex: 2,
        kIndex: 3,
        mStride: BigInt.from(24),
        nStride: BigInt.from(6),
        kStride: BigInt.two,
      ),
      BigInt.from(52),
    );
  });
}

class _AddressFixture {
  final Logic clk = SimpleClockGenerator(10).clk;
  final Logic reset = Logic();
  late final ReadyValidInterface<TensorAddressCommand> upstream =
      ReadyValidInterface(
    TensorAddressCommand(
      addressWidth: 8,
      mWidth: 2,
      nWidth: 2,
      kWidth: 2,
      commandIdWidth: 3,
    ),
  );
  late final ReadyValidInterface<TensorAddressBeat> downstream =
      ReadyValidInterface(
    TensorAddressBeat(
      addressWidth: 8,
      mWidth: 2,
      nWidth: 2,
      kWidth: 2,
      commandIdWidth: 3,
    ),
  );
  late final TensorStridedAddressGenerator dut = TensorStridedAddressGenerator(
    clk: clk,
    reset: reset,
    upstream: upstream,
    downstream: downstream,
    counterWidth: 12,
  );

  Future<void> buildAndReset() async {
    await dut.build();
    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());
    reset.inject(1);
    upstream.valid.inject(0);
    upstream.data.inject(0);
    downstream.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextNegedge;
  }

  Future<void> send({
    required int base,
    required int mExtent,
    required int nExtent,
    required int kExtent,
    required int mStride,
    required int nStride,
    required int kStride,
    required int commandId,
  }) async {
    upstream.data.baseAddress.inject(base);
    upstream.data.mExtent.inject(mExtent);
    upstream.data.nExtent.inject(nExtent);
    upstream.data.kExtent.inject(kExtent);
    upstream.data.mStride.inject(mStride);
    upstream.data.nStride.inject(nStride);
    upstream.data.kStride.inject(kStride);
    upstream.data.commandId.inject(commandId);
    upstream.valid.inject(1);
    while (upstream.ready.value != LogicValue.one) {
      await clk.nextNegedge;
    }
    await clk.nextPosedge;
    upstream.valid.inject(0);
    await clk.nextNegedge;
  }

  Future<void> waitForOutput() async {
    while (downstream.valid.value != LogicValue.one) {
      await clk.nextNegedge;
    }
  }

  Future<void> acceptOutput() async {
    downstream.ready.inject(1);
    await clk.nextPosedge;
    downstream.ready.inject(0);
    await clk.nextNegedge;
  }
}
