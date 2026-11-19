// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// serial_lfsr.dart
// Serial right-shifting Fibonacci LFSR hardware.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/binary_math/recurrence/binary_linear_recurrence.dart';
import 'package:rohd_hcl/src/binary_math/recurrence/lfsr_descriptor.dart';

/// A right-shifting Fibonacci LFSR that advances one bit per clock.
///
/// [serialOut] is state bit zero, which is the bit shifted out at the next
/// enabled clock edge. Reset, load, and enable behavior is inherited from
/// [BinaryLinearRecurrence].
/// {@category Binary Math}
class SerialLfsr extends BinaryLinearRecurrence {
  /// The LFSR convention and characteristic polynomial.
  final LfsrDescriptor lfsrDescriptor;

  /// The bit shifted out at the next enabled clock edge.
  Logic get serialOut => output('serial_out');

  /// Creates a serial Fibonacci LFSR.
  SerialLfsr({
    required super.clk,
    required this.lfsrDescriptor,
    super.reset,
    super.enable,
    super.load,
    super.loadState,
    super.initialState,
    super.asyncReset,
    super.radix,
    super.name = 'serial_lfsr',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          descriptor: lfsrDescriptor.serialRecurrence,
          definitionName: definitionName ??
              'SerialLfsr_${lfsrDescriptor.configurationSignature}_'
                  'R${radix}_'
                  'V${(initialState ?? BigInt.zero).toRadixString(16)}_'
                  'A${asyncReset ? 1 : 0}_E${enable == null ? 0 : 1}_'
                  'L${load == null ? 0 : 1}',
        ) {
    addOutput('serial_out') <= state[0];
  }
}
