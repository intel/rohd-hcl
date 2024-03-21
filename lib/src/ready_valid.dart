// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid.dart
// Ready-Valid building blocks that use ready and valid signals
// to control data transfer.
//
// 2024 February 29
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A connection class to connect ready-valid components
abstract class ReadyValidConnect extends PairInterface {
  /// Create connections between ready-valid components
  ReadyValidConnect(
      {super.portsFromConsumer,
      super.portsFromProvider,
      super.sharedInputPorts,
      super.modify});
}

/// The base class for ready-valid interfaces
abstract class ReadyValidInterface extends ReadyValidConnect {
  /// ready port accessor
  Logic get ready => port('ready');

  /// valid port accessor
  Logic get valid => port('valid');

  /// data port accessor
  Logic get data => port('data');

  /// Create a ready-valid interface with data
  ReadyValidInterface({super.modify})
      : super(
          portsFromProvider: [Port('valid'), Port('data', 8)],
          portsFromConsumer: [Port('ready')],
        );
}

/// A concrete class for ready-and-valid interfaces
class ReadyAndValidInterface extends ReadyValidInterface {
  /// Create a ready-and-valid interface
  ReadyAndValidInterface({super.modify});
}

/// An implementation of a connection between ready-valid components
class ReadyValidConnector extends Module {
  /// create a ready-valid connector between sets of ready-valid components
  ReadyValidConnector(
    Logic clk,
    Logic reset,
    List<ReadyValidInterface> upstreams,
    List<ReadyValidInterface> downstreams, {
    super.name = 'ReadyValidConnector',
  }) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    upstreams = [
      for (var i = 0; i < upstreams.length; i++)
        ReadyAndValidInterface(
          modify: (original) => 'up_${i}_$original',
        )..pairConnectIO(this, upstreams[i], PairRole.consumer),
    ];

    downstreams = [
      for (var i = 0; i < downstreams.length; i++)
        ReadyAndValidInterface(
          modify: (original) => 'dn_${i}_$original',
        )..pairConnectIO(this, downstreams[i], PairRole.provider),
    ];

    if (upstreams.length == 1 && downstreams.length == 1) {
      if (upstreams[0] is ReadyAndValidInterface &&
          downstreams[0] is ReadyAndValidInterface) {
        // connect directly
        upstreams[0].ready <= downstreams[0].ready;
        downstreams[0].valid <= upstreams[0].valid;
        downstreams[0].data <= upstreams[0].data;
      }
    } else if (upstreams.length == 1 && downstreams.length > 1) {
      final arb = RoundRobinArbiter(
        clk: clk,
        reset: reset,
        [
          ...downstreams
              .map((downstream) => downstream.ready & upstreams[0].valid)
        ],
      );

      for (var i = 0; i < downstreams.length; i++) {
        downstreams[i].valid <= arb.grants[i];
        downstreams[i].data <= upstreams[0].data;
      }
      upstreams[0].ready <=
          downstreams
              .map((downstream) => downstream.ready)
              .toList()
              .swizzle()
              .or();
    } else if (upstreams.length > 1 && downstreams.length == 1) {
      final arb = RoundRobinArbiter(
        clk: clk,
        reset: reset,
        [...upstreams.map((upstream) => upstream.valid & downstreams[0].ready)],
      );

      downstreams[0].valid <=
          upstreams.map((upstream) => upstream.valid).toList().swizzle().or();

      for (var i = 0; i < upstreams.length; i++) {
        upstreams[i].ready <= arb.grants[i];
      }

      downstreams[0].data <=
          cases(Const(1), {
            for (var i = 0; i < arb.grants.length; i++)
              arb.grants[i]: upstreams[i].data,
          });
    }
  }

  /// A ready-and-valid stage that can wrap combinational logic with a FIFO
  ///  that observes ready-and-valid protocol
  ///     Assume no flops in [combStage]
  ReadyAndValidInterface doStage(Logic clk, Logic reset,
      ReadyAndValidInterface upstream, Logic Function(Logic data) combStage) {
    final downstream = ReadyAndValidInterface();

    final fifo = Fifo(
      clk,
      reset,
      writeEnable: upstream.valid & upstream.ready,
      writeData: upstream.data,
      readEnable: downstream.valid & downstream.ready,
      depth: 1,
    );

    downstream.valid <= ~fifo.empty;
    upstream.ready <= ~fifo.full | downstream.ready;

    downstream.data <= combStage(fifo.readData);

    return downstream;
  }
}
