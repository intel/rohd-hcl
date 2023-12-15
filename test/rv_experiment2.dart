import 'dart:async';
import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A round-robin arbiter.
class RoundRobinArbiter2 extends Module implements Arbiter {
  @override
  final int count;

  @override
  late final List<Logic> grants = UnmodifiableListView(
    [for (var i = 0; i < count; i++) output('grant_$i')],
  );

  /// Creates an [Arbiter] that fairly takes turns between [requests].
  RoundRobinArbiter2(List<Logic> requests,
      {required Logic clk,
      required Logic reset,
      super.name = 'round_robin_arbiter'})
      : count = requests.length {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    requests = [
      for (var i = 0; i < count; i++) addInput('request_$i', requests[i])
    ];

    final preference = Logic(name: 'preference', width: log2Ceil(count));

    final rotatedReqs = requests
        .rswizzle()
        .rotateRight(preference, maxAmount: count - 1)
        .elements;
    final priorityArb = PriorityArbiter(rotatedReqs);
    final unRotatedGrants = priorityArb.grants
        .rswizzle()
        .rotateLeft(preference, maxAmount: count - 1);

    for (var i = 0; i < count; i++) {
      addOutput('grant_$i') <= unRotatedGrants[i];
    }

    Sequential(clk, reset: reset, [
      If(unRotatedGrants.or(), then: [
        //TODO: bug in HIOP
        preference < TreeOneHotToBinary(unRotatedGrants).binary + 1,
      ]),
    ]);
  }
}

abstract class HandshakeInterface extends PairInterface {
  HandshakeInterface(
      {super.portsFromConsumer,
      super.portsFromProvider,
      super.sharedInputPorts,
      super.modify});
}

abstract class ReadyValidInterface extends HandshakeInterface {
  Logic get ready => port('ready');
  Logic get valid => port('valid');
  Logic get data => port('data'); //TODO: width

  ReadyValidInterface({super.modify})
      : super(
          portsFromProvider: [Port('valid'), Port('data', 8)],
          portsFromConsumer: [Port('ready')],
        );
}

class ReadyAndValidInterface extends ReadyValidInterface {
  ReadyAndValidInterface({super.modify});
}

class ReadyThenValidInterface extends ReadyValidInterface {
  ReadyThenValidInterface({super.modify});

  ReadyAndValidInterface toDownstreamReadyAndValid(Logic clk, Logic reset) {
    final downstream = ReadyAndValidInterface();

    final readEnable = Logic();
    final fifo = Fifo(
      clk,
      reset,
      depth: 2,
      writeEnable: valid,
      writeData: data,
      readEnable: readEnable,
    );

    readEnable <= downstream.ready & downstream.valid;
    ready <= ~fifo.full;
    downstream.data <= fifo.readData;
    downstream.valid <= ~fifo.empty;

    return downstream;
  }
}

class ValidThenReadyInterface extends ReadyValidInterface {
  ValidThenReadyInterface({super.modify});

  ReadyAndValidInterface toDownstreamReadyAndValid(Logic clk, Logic reset) {
    final downstream = ReadyAndValidInterface();

    final readEnable = Logic();
    final fifo = Fifo(
      clk,
      reset,
      depth: 2,
      writeEnable: ready,
      writeData: data,
      readEnable: readEnable,
    );

    readEnable <= downstream.ready & downstream.valid;
    ready <= ~fifo.full & valid;
    downstream.data <= fifo.readData;
    downstream.valid <= ~fifo.empty;

    return downstream;
  }
}

class ReadyAndValidToManyValidThenReadyGasket extends Module {}

class HandshakeGasket extends Module {
  HandshakeGasket(
    Logic clk,
    Logic reset,
    List<ReadyValidInterface> upstreams,
    List<ReadyValidInterface> downstreams, {
    super.name = 'handshakeGasket',
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
        //TODO
      }
    } else if (upstreams.length == 1 && downstreams.length > 1) {
      //TODO: assuming that all upstreams are already ReadyAndValid...
      // and that downstreams are ReadyAndValid

      final readyThenValidDownstreams = List.generate(
          downstreams.length, (index) => ReadyThenValidInterface());

      final arb = RoundRobinArbiter2(
        clk: clk,
        reset: reset,
        [
          ...readyThenValidDownstreams
              .map((downstream) => downstream.ready & upstreams[0].valid)
        ],
      );

      for (var i = 0; i < downstreams.length; i++) {
        readyThenValidDownstreams[i].valid <= arb.grants[i];
        readyThenValidDownstreams[i].data <= upstreams[0].data;
      }
      upstreams[0].ready <=
          readyThenValidDownstreams
              .map((downstream) => downstream.ready)
              .toList()
              .swizzle()
              .or();

      for (var i = 0; i < readyThenValidDownstreams.length; i++) {
        final readyAndValidDownstream =
            readyThenValidDownstreams[i].toDownstreamReadyAndValid(clk, reset);
        downstreams[i].data <= readyAndValidDownstream.data;
        downstreams[i].valid <= readyAndValidDownstream.valid;
        readyAndValidDownstream.ready <= downstreams[i].ready;
      }
    } else if (upstreams.length > 1 && downstreams.length == 1) {
      //TODO: assuming that all upstreams are already ReadyAndValid...
      // and that downstreams are ReadyAndValid

      final validThenReadyDownstream = ValidThenReadyInterface();

      final arb = RoundRobinArbiter2(
        clk: clk,
        reset: reset,
        [
          ...upstreams.map(
              (upstream) => upstream.valid & validThenReadyDownstream.ready)
        ],
      );

      validThenReadyDownstream.valid <=
          upstreams.map((upstream) => upstream.valid).toList().swizzle().or();

      for (var i = 0; i < upstreams.length; i++) {
        upstreams[i].ready <= arb.grants[i];
      }

      validThenReadyDownstream.data <=
          cases(Const(1), {
            for (var i = 0; i < arb.grants.length; i++)
              arb.grants[i]: upstreams[i].data,
          });

      final readyAndValidDownstream =
          validThenReadyDownstream.toDownstreamReadyAndValid(clk, reset);
      downstreams[0].data <= readyAndValidDownstream.data;
      downstreams[0].valid <= readyAndValidDownstream.valid;
      readyAndValidDownstream.ready <= downstreams[0].ready;
    }
  }
}

class ExampleReadyAndValidStage extends Module {
  ExampleReadyAndValidStage(Logic clk, Logic reset,
      ReadyAndValidInterface upstream, ReadyAndValidInterface downstream,
      {super.name = 'exampleStage'}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    upstream = ReadyAndValidInterface(
      modify: (original) => 'up_$original',
    )..pairConnectIO(this, upstream, PairRole.consumer);
    downstream = ReadyAndValidInterface(
      modify: (original) => 'dn_$original',
    )..pairConnectIO(this, downstream, PairRole.provider);

    final readEnable = Logic();

    final f = Fifo(
      clk,
      reset,
      depth: 2,
      writeEnable: upstream.valid & upstream.ready,
      writeData: upstream.data,
      readEnable: readEnable,
    );

    readEnable <= (downstream.valid & downstream.ready);

    downstream.valid <= ~f.empty;
    upstream.ready <= ~f.full | readEnable;
    downstream.data <= f.readData;
  }
}

class ExampleTopModule extends Module {
  ExampleTopModule(Logic clk, Logic reset, ReadyAndValidInterface upstream,
      ReadyAndValidInterface downstream)
      : super(name: 'top') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    upstream = ReadyAndValidInterface(modify: (original) => 'up_$original')
      ..pairConnectIO(this, upstream, PairRole.consumer);
    downstream = ReadyAndValidInterface(modify: (original) => 'dn_$original')
      ..pairConnectIO(this, downstream, PairRole.provider);

    const count = 2;

    final middleInterfaces1 =
        List.generate(2, (index) => ReadyAndValidInterface());
    final middleInterfaces2 =
        List.generate(2, (index) => ReadyAndValidInterface());

    HandshakeGasket(clk, reset, [upstream], middleInterfaces1,
        name: 'fanOutGasket');

    for (var i = 0; i < count; i++) {
      ExampleReadyAndValidStage(
          clk, reset, middleInterfaces1[i], middleInterfaces2[i],
          name: 'exampleStage$i');
    }

    HandshakeGasket(clk, reset, middleInterfaces2, [downstream],
        name: 'fanInGasket');
  }
}

/// Assume no flops in [combStage]
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

class ExampleTopModule2 extends Module {
  ExampleTopModule2(Logic clk, Logic reset, ReadyAndValidInterface upstream,
      ReadyAndValidInterface downstream)
      : super(name: 'top') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    upstream = ReadyAndValidInterface(modify: (original) => 'up_$original')
      ..pairConnectIO(this, upstream, PairRole.consumer);
    downstream = ReadyAndValidInterface(modify: (original) => 'dn_$original')
      ..pairConnectIO(this, downstream, PairRole.provider);

    var tmp = upstream;
    tmp = doStage(clk, reset, tmp, (data) => data + 1);
    tmp = doStage(clk, reset, tmp, (data) => data + 1);
    tmp = doStage(clk, reset, tmp, (data) => data + 1);
    tmp = doStage(clk, reset, tmp, (data) => data + 1);
    tmp = doStage(clk, reset, tmp, (data) => data + 1);
    tmp = doStage(clk, reset, tmp, (data) => data + 1);

    downstream.data <= tmp.data;
  }
}

void main() async {
  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic();
  final up = ReadyAndValidInterface();
  final dn = ReadyAndValidInterface();
  final mod = ExampleTopModule2(clk, reset, up, dn);
  await mod.build();

  // print(mod.generateSynth());
  WaveDumper(mod);

  var data = 0;

  up.valid.inject(0);
  dn.ready.inject(0);

  Simulator.setMaxSimTime(500);
  unawaited(Simulator.run());

  await clk.nextNegedge;
  reset.inject(1);
  await clk.nextNegedge;
  await clk.nextNegedge;
  reset.inject(0);
  await clk.nextNegedge;
  await clk.nextNegedge;
  // up.valid.inject(1);

  await clk.nextNegedge;
  await clk.nextNegedge;
  await clk.nextNegedge;
  clk.negedge.listen((event) {
    if (up.ready.value.isValid && up.ready.value.toBool()) {
      up.valid.inject(1);
      up.data.inject(data++);
    } else {
      up.valid.inject(0);
    }
  });
  await clk.nextNegedge;
  await clk.nextNegedge;
  await clk.nextNegedge;
  dn.ready.inject(1);

  await clk.waitCycles(20);

  Simulator.endSimulation();
  await Simulator.simulationEnded;
}
