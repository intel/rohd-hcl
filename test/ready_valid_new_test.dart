import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

import 'ready_valid_simple_test.dart';

class ReadyValidBfmTest extends Test {
  final clk = SimpleClockGenerator(10).clk;
  final Logic reset = Logic();
  final Logic ready = Logic();
  final Logic valid = Logic();
  final Logic data = Logic(width: 8);

  late final ReadyValidTransmitterAgent transmitter;
  late final ReadyValidMonitor monitor;

  String get outFolder => 'tmp_test/newreadyvalid/$name/';

  ReadyValidBfmTest(
    super.name, {
    super.randomSeed = 1234,
    super.printLevel = Level.ALL,
  }) {
    transmitter = ReadyValidTransmitterAgent(
      clk: clk,
      reset: reset,
      ready: ready,
      valid: valid,
      data: data,
      parent: this,
    );

    monitor = ReadyValidMonitor(
      clk: clk,
      reset: reset,
      ready: ready,
      valid: valid,
      data: data,
      parent: this,
    );

    Directory(outFolder).createSync(recursive: true);

    final tracker = ReadyValidTracker(outputFolder: outFolder);
    monitor.stream.listen(tracker.record);

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();
    });
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('apbBfmTestObj');

    await _resetFlow();

    logger.info('Reset flow completed');

    for (var i = 0; i < 10; i++) {
      final pkt = ReadyValidPacket(LogicValue.ofInt(i, 8));

      logger.info('Adding packet $i');
      transmitter.sequencer.add(pkt);
    }
    await clk.waitCycles(3);

    logger.info('Dropping objection!');

    obj.drop();
  }

  Future<void> _resetFlow() async {
    await clk.waitCycles(2);
    reset.inject(1);
    await clk.waitCycles(3);
    reset.inject(0);
    await clk.waitCycles(3);
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  Future<void> runTest(ReadyValidBfmTest readyValidBfmTest,
      {bool dumpWaves = false}) async {
    Simulator.setMaxSimTime(3000);
    final up = ReadyAndValidInterface();
    final dn = ReadyAndValidInterface();
    final mod = ReadyAndValidStage(
        readyValidBfmTest.clk, readyValidBfmTest.reset, up, dn);

    up.valid <= readyValidBfmTest.valid;
    up.data <= readyValidBfmTest.data;
    readyValidBfmTest.ready <= up.ready;
    dn.ready.inject(0);

    // unawaited(readyValidBfmTest.clk
    //     .waitCycles(15)
    //     .then((value) => dn.ready.inject(1)));
    // DAK: how to add other injections to the test
    // (e.g. then is not powerful enough, I need to wait)
    unawaited(readyValidBfmTest.clk
        .waitCycles(15)
        .then((value) => dn.ready.inject(1)));
    await mod.build();
    if (dumpWaves) {
      WaveDumper(mod);
    }

    await readyValidBfmTest.start();
  }

  test('simple', () async {
    await runTest(ReadyValidBfmTest('simple'), dumpWaves: true);
  });
}
