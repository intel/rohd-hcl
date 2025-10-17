// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_interface.dart
// Ready/Valid Interface
//
// ignore: flutter_style_todos
// TODO: Need Date
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A ready/valid interface with associated data of type [LogicType].
class ReadyValidInterface<LogicType extends Logic> extends PairInterface {
  /// The data associated with the ready/valid handshake.
  final LogicType data;

  /// Indicates that the consumer is ready to accept data.
  Logic get ready => port('ready');

  /// Indicates that the provider has valid data.
  Logic get valid => port('valid');

  /// Indicates that a transaction has been accepted (both valid and ready).
  late final Logic accepted = (ready & valid).named('${data}_accepted');

  /// Creates a [ReadyValidInterface] with the given [data].
  ReadyValidInterface(this.data)
      : super(
          portsFromProvider: [data, Logic.port('valid')],
          portsFromConsumer: [Logic.port('ready')],
        );

  @override
  ReadyValidInterface<LogicType> clone() =>
      ReadyValidInterface(data.clone() as LogicType);
}

/// A ready/valid interface where ready and valid assert independently.
class ReadyAndValidInterface<LogicType extends Logic>
    extends ReadyValidInterface<LogicType> {
  /// Creates a [ReadyAndValidInterface].
  ReadyAndValidInterface(super.data);

  @override
  ReadyAndValidInterface<LogicType> clone() =>
      ReadyAndValidInterface(data.clone() as LogicType);
}

/// A ready/valid interface where ready must be asserted before valid can be
/// computed.
class ReadyThenValidInterface<LogicType extends Logic>
    extends ReadyValidInterface<LogicType> {
  /// Creates a [ReadyThenValidInterface].
  ReadyThenValidInterface(super.data);

  /// Converts this [ReadyThenValidInterface] to a [ReadyAndValidInterface] by
  /// adding a small FIFO to buffer data.
  ReadyAndValidInterface<LogicType> toDownstreamReadyAndValid(
    Logic clk,
    Logic reset,
  ) {
    final downstream = ReadyAndValidInterface<LogicType>(
      data.clone() as LogicType,
    );

    final readEnable = Logic();
    final fifo = Fifo(
      clk,
      reset,
      depth: 2,
      writeEnable: valid,
      writeData: data,
      readEnable: readEnable,
      name: 'ready_then_valid_to_ready_and_valid_fifo_${data.name}',
    );

    readEnable <= downstream.ready & downstream.valid;
    ready <= ~fifo.full;
    downstream.data <= fifo.readData;
    downstream.valid <= ~fifo.empty;

    return downstream;
  }

  @override
  ReadyThenValidInterface<LogicType> clone() =>
      ReadyThenValidInterface(data.clone() as LogicType);
}
