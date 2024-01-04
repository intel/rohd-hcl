// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// arbiter_test.dart
// Tests for arbiters
//
// 2023 March 13
// Author: Rahul Gautham Putcha <max.korbel@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('parity transmitter', () async {
    const width = 8;

    final vector = Logic(width: width);

    final parityTransmitter = ParityTransmitter(vector);

    vector.put(bin('00000000'));
    expect(parityTransmitter.data.value, LogicValue.ofString('000000000'));

    vector.put(bin('00000001'));
    expect(parityTransmitter.data.value, LogicValue.ofString('100000001'));

    vector.put(bin('10000001'));
    expect(parityTransmitter.data.value, LogicValue.ofString('010000001'));

    vector.put(bin('10001001'));
    expect(parityTransmitter.data.value, LogicValue.ofString('110001001'));

    vector.put(bin('11111101'));
    expect(parityTransmitter.data.value, LogicValue.ofString('111111101'));

    vector.put(bin('11111111'));
    expect(parityTransmitter.data.value, LogicValue.ofString('011111111'));
  });

  test('parity receiver checking', () async {
    const width = 9;

    final vector = Logic(width: width);

    final parityReceiver = ParityReceiver(vector);

    vector.put(bin('000000000'));
    expect(parityReceiver.data.value, LogicValue.ofString('00000000'));
    expect(parityReceiver.parity.value, LogicValue.ofString('0'));
    expect(parityReceiver.checkError.value, LogicValue.ofString('0'));

    vector.put(bin('011111111'));
    expect(parityReceiver.data.value, LogicValue.ofString('11111111'));
    expect(parityReceiver.parity.value, LogicValue.ofString('0'));
    expect(parityReceiver.checkError.value, LogicValue.ofString('0'));

    vector.put(bin('111111101'));
    expect(parityReceiver.data.value, LogicValue.ofString('11111101'));
    expect(parityReceiver.parity.value, LogicValue.ofString('1'));
    expect(parityReceiver.checkError.value, LogicValue.ofString('0'));

    vector.put(bin('111110101'));
    expect(parityReceiver.data.value, LogicValue.ofString('11110101'));
    // This is set to check the incorrect parity bit on purpose
    expect(parityReceiver.parity.value, LogicValue.ofString('1'));
    // checkError equals to `1` means the parity check fail and
    // have noted error in the transmitted data
    expect(parityReceiver.checkError.value, LogicValue.ofString('1'));
  });
}
