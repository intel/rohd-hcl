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
class ParityTransmitter extends ErrorCheckingTransmitter {
  /// The [parity] bit computed for the provided data.
  @Deprecated('Use `code` instead.')
  Logic get parity => code;

  /// Creates a transmitter that sends data with a parity bit.
  ParityTransmitter(super.data, {super.name = 'parity_tx'})
      : super(codeWidth: 1);

  @override
  Logic calculateCode() => data.xor();
}

/// Check for error & Receive data on transmitted data via parity
class ParityReceiver extends ErrorCheckingReceiver {
  /// Constructs a [Module] which checks data that has been transmitted with
  /// correct parity. This will split the transmitted data in [bus] into 2
  /// parts: the [originalData], and the error bit upon which [error] is
  /// calculated for parity error checking.
  ParityReceiver(super.bus, {super.name = 'parity_rx'})
      : super(codeWidth: 1, supportsErrorCorrection: false);

  @override
  Logic calculateCorrectableError() => Const(0);

  @override
  Logic? calculateCorrectedData() => null;

  @override
  Logic calculateUncorrectableError() => ~originalData.xor().eq(code);

  /// [checkError] is an getter for parity result with `0` for success and `1`
  /// for fail
  @Deprecated('Use `error` or `uncorrectableError` instead.')
  Logic get checkError => error;

  /// The original [data] (without [parity]).
  @Deprecated('Use `originalData` instead.')
  Logic get data => originalData;

  /// [parity] is an getter for parity Bit received upon data transmission
  @Deprecated('Use `code` instead.')
  Logic get parity => code;
}
