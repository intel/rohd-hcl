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
import 'package:rohd_hcl/rohd_hcl.dart';

/// Encode data to transport with Parity bits
class ParityTransmitter extends Module {
  /// [_output] is output of parity (use index for accessing from outside Module)
  late Logic _output;

  /// [data] is an getter for transmit data having a parity check
  Logic get data => _output;

  /// Construct a module
  ParityTransmitter(Logic bus) {
    bus = addInput('bus', bus, width: bus.width);
    final transmitData = [bus, bus.xor()].swizzle();
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
    final transmittedData = bus.slice(-1, 1);
    final parityBit = bus[0];
    final parityError = ~transmittedData.xor().eq(parityBit);

    _data = addOutput('transmittedData', width: transmittedData.width);
    _parityBit = addOutput('parityBit', width: transmittedData.width);
    _checkError = addOutput('checkError', width: parityError.width);

    _data <= transmittedData;
    _parityBit <= parityBit;
    _checkError <= parityError;
  }
}
