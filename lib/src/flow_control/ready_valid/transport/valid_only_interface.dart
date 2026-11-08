// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// valid_only_interface.dart
// Valid-only flow-control interface.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// A payload channel whose provider marks available data with valid.
///
/// A valid-only consumer has no backpressure signal and therefore accepts
/// every cycle for which valid is asserted.
/// {@category Flow Control}
class ValidOnlyInterface<LogicType extends Logic> extends PairInterface {
  /// Payload carried alongside valid.
  final LogicType data;

  /// Indicates that [data] is available in this cycle.
  Logic get valid => port('valid');

  /// Creates a valid-only interface with the given payload shape.
  ValidOnlyInterface(this.data)
      : super(portsFromProvider: [data, Logic.port('valid')]);

  @override
  ValidOnlyInterface<LogicType> clone() =>
      ValidOnlyInterface(data.clone() as LogicType);
}
