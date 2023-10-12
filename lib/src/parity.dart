// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// parity.dart
// Implementation of Parity modules.
//
// 2023 August 20
// Author: Rahul Gautham Putcha <rahul.gautham.putcha@intel.com>
//

import 'package:rohd/rohd.dart';

/// Encode data to transport with Parity bits
class ParityTransmitter extends Module {
  /// [_output] is output of parity
  /// (use index for accessing from outside Module)
  late Logic _output;

  /// [data] is an getter for transmit data having a parity check
  Logic get data => _output;

  /// [parity] is a getter for parity bit
  Logic get parity => output('parity');

  /// Construct a [Module] for generating transmit data [data].
  /// Combine given [Logic] named [bus] with a parity bit for error check after
  /// transmission
  ParityTransmitter(Logic bus) {
    bus = addInput('bus', bus, width: bus.width);
    addOutput('parity');
    parity <= bus.xor();
    final transmitData = [parity, bus].swizzle();
    _output = addOutput('transmitData', width: transmitData.width);
    _output <= transmitData;
  }
}

/// Check for error & Receive data on transmitted data via parity
class ParityReceiver extends Module {
  /// [_checkError] is parity with result `0` for success and `1` for fail
  late Logic _checkError;

  /// [_parityBit] is parity bit appended to transmitted data for parity
  late Logic _parityBit;

  /// [_data] is transmitted data (not containing without [_parityBit])
  late Logic _data;

  /// [checkError] is an getter for parity result with
  /// `0` for success and `1` for fail
  Logic get checkError => _checkError;

  /// [data] is an getter for transmitted/original data (without [parityBit])
  Logic get data => _data;

  /// [parityBit] is an getter for parity Bit received upon data transmission
  Logic get parityBit => _parityBit;

  /// Constructs a [Module] which encodes data transmitted via parity.
  /// This will split the transmitted data in [bus] into 2 parts: the [data]
  /// having the original, and the error bit upon which [checkError] is
  /// calculated for parity error checking.
  ParityReceiver(Logic bus) {
    bus = addInput('bus', bus, width: bus.width);

    // Slice from 1 from least significant bit to the end
    final transmittedData = bus.slice(-2, 0);
    final parityBit = bus[-1];
    final parityError = ~transmittedData.xor().eq(parityBit);

    _data = addOutput('transmittedData', width: transmittedData.width);
    _parityBit = addOutput('parityBit', width: parityBit.width);
    _checkError = addOutput('checkError', width: parityError.width);

    _data <= transmittedData;
    _parityBit <= parityBit;
    _checkError <= parityError;
  }
}
