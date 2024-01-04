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
  /// The [data] including the [parity] bit (as the most significant bit).
  Logic get data => _output;
  late final Logic _output;

  /// The [parity] bit computed for the provided data.
  Logic get parity => output('parity');

  /// Construct a [Module] for generating transmit data [data]. Combines given
  /// [Logic] named [bus] with a [parity] bit for error check after
  /// transmission.
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
  /// [checkError] is an getter for parity result with `0` for success and `1`
  /// for fail
  Logic get checkError => _checkError;
  late Logic _checkError;

  /// The original [data] (without [parity]).
  Logic get data => _data;
  late Logic _data;

  /// [parity] is an getter for parity Bit received upon data transmission
  Logic get parity => _parity;
  late Logic _parity;

  /// Constructs a [Module] which checks data that has been transmitted with
  /// parity. This will split the transmitted data in [bus] into 2 parts: the
  /// original [data], and the error bit upon which [checkError] is calculated
  /// for parity error checking.
  ParityReceiver(Logic bus) {
    bus = addInput('bus', bus, width: bus.width);

    // Slice from 1 from least significant bit to the end
    final transmittedData = bus.slice(-2, 0);
    final parityBit = bus[-1];
    final parityError = ~transmittedData.xor().eq(parityBit);

    _data = addOutput('transmittedData', width: transmittedData.width);
    _parity = addOutput('parity', width: parityBit.width);
    _checkError = addOutput('checkError', width: parityError.width);

    _data <= transmittedData;
    _parity <= parityBit;
    _checkError <= parityError;
  }
}
