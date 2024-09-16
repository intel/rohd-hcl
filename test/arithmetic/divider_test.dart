// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// divider_test.dart
// Tests for Integer Divider
//
// 2024 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

// ignore_for_file: avoid_types_on_closure_parameters

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

// helper method to compute 2's complement representation
// of the provided value based on its bit width
int _twosComp(int val, int bits) {
  var tmp = val;
  if (val & (1 << (bits - 1)) != 0) {
    tmp = tmp - (1 << bits);
  }
  return tmp;
}

class MultiCycleDividerInputSeqItem extends SequenceItem {
  final int mDividend;
  final int mDivisor;
  final bool mValidIn;
  final bool mReadyOut;
  MultiCycleDividerInputSeqItem(
      {required this.mDividend,
      required this.mDivisor,
      required this.mValidIn,
      required this.mReadyOut});

  int get dividend => mDividend;
  int get divisor => mDivisor;
  int get validIn => mValidIn ? 1 : 0;
  int get readyOut => mReadyOut ? 1 : 0;

  @override
  String toString() => '''
dividend=$mDividend, 
divisor=$mDivisor,
validIn=$mValidIn,
readyOut=$mReadyOut
''';
}

class MultiCycleDividerOutputSeqItem extends SequenceItem {
  final int mQuotient;
  final bool mDivZero;
  final bool mValidOut;
  final bool mReadyIn;
  MultiCycleDividerOutputSeqItem(
      {required this.mQuotient,
      required this.mDivZero,
      required this.mValidOut,
      required this.mReadyIn});

  int get quotient => mQuotient;
  int get divZero => mDivZero ? 1 : 0;
  int get validOut => mValidOut ? 1 : 0;
  int get readyIn => mReadyIn ? 1 : 0;

  @override
  String toString() => '''
quotient=$mQuotient, 
divZero=$mDivZero,
validOut=$mValidOut,
readyIn=$mReadyIn
''';
}

class MultiCycleDividerSequencer
    extends Sequencer<MultiCycleDividerInputSeqItem> {
  MultiCycleDividerSequencer(Component parent,
      {String name = 'MultiCycleDividerSequencer'})
      : super(name, parent);
}

class MultiCycleDividerDriver extends Driver<MultiCycleDividerInputSeqItem> {
  final MultiCycleDividerInterface intf;

  // Keep a queue of items from the sequencer to be driven when desired
  final Queue<MultiCycleDividerInputSeqItem> _pendingItems =
      Queue<MultiCycleDividerInputSeqItem>();

  Objection? _driverObjection;

  MultiCycleDividerDriver(
      this.intf, MultiCycleDividerSequencer sequencer, Component parent,
      {String name = 'MultiCycleDividerDriver'})
      : super(name, parent, sequencer: sequencer);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    // Listen to new items coming from the sequencer, and add them to a queue
    sequencer.stream.listen((newItem) {
      _driverObjection ??= phase.raiseObjection('div_driver')
        ..dropped.then((value) => logger.fine('Driver objection dropped'));
      _pendingItems.add(newItem);
    });

    // Every clock negative edge, drive the next pending item if it exists
    // but only when the DUT isn't busy
    intf.clk.negedge.listen((args) {
      if (_pendingItems.isNotEmpty && intf.readyIn.value == LogicValue.zero) {
        final nextItem = _pendingItems.removeFirst();
        drive(nextItem);
        if (_pendingItems.isEmpty) {
          _driverObjection?.drop();
          _driverObjection = null;
        }
      }
    });
  }

  // Translate a SequenceItem into pin wiggles
  void drive(MultiCycleDividerInputSeqItem? item) {
    if (item == null) {
      intf.dividend.inject(0);
      intf.divisor.inject(0);
      intf.validIn.inject(0);
      intf.readyOut.inject(1);
    } else {
      intf.dividend.inject(item.dividend);
      intf.divisor.inject(item.divisor);
      intf.validIn.inject(item.validIn);
      intf.readyOut.inject(item.readyOut);
    }
  }
}

class MultiCycleDividerInputMonitor
    extends Monitor<MultiCycleDividerInputSeqItem> {
  /// Instance of the [Interface] to the DUT.
  final MultiCycleDividerInterface intf;

  MultiCycleDividerInputMonitor(this.intf, Component parent,
      {String name = 'MultiCycleDividerInputMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    // Every positive edge of the clock
    intf.clk.posedge.listen((event) {
      if (intf.validIn.value == LogicValue.one &&
          intf.readyIn.value == LogicValue.zero) {
        add(MultiCycleDividerInputSeqItem(
            mDividend:
                _twosComp(intf.dividend.value.toInt(), intf.dividend.width),
            mDivisor: _twosComp(intf.divisor.value.toInt(), intf.divisor.width),
            mValidIn: true,
            mReadyOut: true)); // must convert to two's complement rep.
      }
    });
  }
}

class MultiCycleDividerOutputMonitor
    extends Monitor<MultiCycleDividerOutputSeqItem> {
  /// Instance of the [Interface] to the DUT.
  final MultiCycleDividerInterface intf;

  MultiCycleDividerOutputMonitor(this.intf, Component parent,
      {String name = 'MultiCycleDividerInputMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    // Every positive edge of the clock
    intf.clk.posedge.listen((event) {
      if (intf.validOut.value == LogicValue.one) {
        add(MultiCycleDividerOutputSeqItem(
            mQuotient:
                _twosComp(intf.quotient.value.toInt(), intf.quotient.width),
            // must convert to two's complement rep.
            mDivZero: intf.divZero.value == LogicValue.one,
            mValidOut: true,
            mReadyIn: intf.readyIn.value == LogicValue.one));
      }
    });
  }
}

class MultiCycleDividerScoreboard extends Component {
  final Stream<MultiCycleDividerInputSeqItem> inStream;
  final Stream<MultiCycleDividerOutputSeqItem> outStream;

  final MultiCycleDividerInterface intf;

  MultiCycleDividerScoreboard(
      this.inStream, this.outStream, this.intf, Component parent,
      {String name = 'MultiCycleDividerScoreboard'})
      : super(name, parent);

  final List<int> lastA = [];
  final List<int> lastB = [];

  int currResult = 0;
  bool divZero = false;

  bool triggerCheck = false;

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await intf.reset.nextNegedge;

    inStream.listen((event) {
      lastA.add(event.mDividend);
      lastB.add(event.mDivisor);
    });

    // record the value we saw this cycle
    outStream.listen((event) {
      currResult = event.mQuotient;
      divZero = event.mDivZero;

      triggerCheck = true;
    });

    // check values on negative edge
    intf.clk.negedge.listen((event) {
      if (lastA.isNotEmpty) {
        final in1 = lastA[0];
        final in2 = lastB[0];
        lastA.removeAt(0);
        lastB.removeAt(0);
        if (triggerCheck) {
          final check = (in2 == 0) ? divZero : ((in1 ~/ in2) == currResult);
          if (check) {
            final msg = (in2 == 0)
                ? '''
Divide by 0 error correctly encountered for denominator of 0.
'''
                : '''
Correct result: dividend=$in1, divisor=$in2, quotient=$currResult
                ''';
            logger.info(msg);
          } else {
            final msg = (in2 == 0)
                ? '''
No Divide by zero error for denominator of 0.
'''
                : '''
Incorrect result: dividend=$in1, divisor=$in2, quotient=$currResult
''';
            logger.severe(msg);
          }
          triggerCheck = false;
        }
      }
    });
  }
}

class MultiCycleDividerAgent extends Agent {
  final MultiCycleDividerInterface intf;
  late final MultiCycleDividerSequencer sequencer;
  late final MultiCycleDividerDriver driver;
  late final MultiCycleDividerInputMonitor inMonitor;
  late final MultiCycleDividerOutputMonitor outMonitor;

  MultiCycleDividerAgent(this.intf, Component parent,
      {String name = 'MultiCycleDividerAgent'})
      : super(name, parent) {
    sequencer = MultiCycleDividerSequencer(this);
    driver = MultiCycleDividerDriver(intf, sequencer, this);
    inMonitor = MultiCycleDividerInputMonitor(intf, this);
    outMonitor = MultiCycleDividerOutputMonitor(intf, this);
  }
}

class MultiCycleDividerEnv extends Env {
  final MultiCycleDividerInterface intf;

  late final MultiCycleDividerAgent agent;
  late final MultiCycleDividerScoreboard scoreboard;

  MultiCycleDividerEnv(this.intf, Component parent,
      {String name = 'MultiCycleDividerEnv'})
      : super(name, parent) {
    agent = MultiCycleDividerAgent(intf, this);
    scoreboard = MultiCycleDividerScoreboard(
        agent.inMonitor.stream, agent.outMonitor.stream, intf, this);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));
  }
}

class MultiCycleDividerBasicSequence extends Sequence {
  MultiCycleDividerBasicSequence(
      {String name = 'MultiCycleDividerBasicSequence'})
      : super(name);

  @override
  Future<void> body(Sequencer sequencer) async {
    sequencer as MultiCycleDividerSequencer
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 4,
          mDivisor: 2,
          mValidIn: true,
          mReadyOut: true)) // even divide by 2
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 9,
          mDivisor: 3,
          mValidIn: true,
          mReadyOut: true)) // even divide not by 2
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 5,
          mDivisor: 2,
          mValidIn: true,
          mReadyOut: true)) // not even divide
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 4,
          mDivisor: 1,
          mValidIn: true,
          mReadyOut: true)) // divide by 1
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: -10,
          mDivisor: 2,
          mValidIn: true,
          mReadyOut: true)) // negative-positive
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 13,
          mDivisor: -10,
          mValidIn: true,
          mReadyOut: true)) // positive-negative
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: -10,
          mDivisor: -9,
          mValidIn: true,
          mReadyOut: true)) // negative-negative
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 1,
          mDivisor: 4,
          mValidIn: true,
          mReadyOut: true)) // bigger divisor
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 4,
          mDivisor: 0,
          mValidIn: true,
          mReadyOut: true)); // divide by 0
  }
}

class MultiCycleDividerVolumeSequence extends Sequence {
  final int numReps;
  final rng = Random(0xdeadbeef); // fixed seed

  MultiCycleDividerVolumeSequence(this.numReps,
      {String name = 'MultiCycleDividerVolumeSequence'})
      : super(name);

  @override
  Future<void> body(Sequencer sequencer) async {
    final divSequencer = sequencer as MultiCycleDividerSequencer;

    for (var i = 0; i < numReps; i++) {
      final a = rng.nextInt(1 << 32);
      final b = rng.nextInt(1 << 32);
      divSequencer.add(MultiCycleDividerInputSeqItem(
          mDividend: a, mDivisor: b, mValidIn: true, mReadyOut: true));
    }
  }
}

class MultiCycleDividerTest extends Test {
  final MultiCycleDivider dut;
  late final MultiCycleDividerInterface intf;

  /// The test environment for [dut].
  late final MultiCycleDividerEnv env;

  /// A private, local pointer to the test environment's [Sequencer].
  late final MultiCycleDividerSequencer _divSequencer;

  MultiCycleDividerTest(this.dut, this.intf,
      {String name = 'MultiCycleDividerTest'})
      : super(name) {
    env = MultiCycleDividerEnv(intf, this);
    _divSequencer = env.agent.sequencer;
  }

  // A "time consuming" method, similar to `task` in SystemVerilog, which
  // waits for a given number of cycles before completing.
  Future<void> waitCycles(int numCycles) async {
    for (var i = 0; i < numCycles; i++) {
      await intf.clk.nextNegedge;
    }
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    // Raise an objection at the start of the test so that the
    // simulation doesn't end before stimulus is injected
    final obj = phase.raiseObjection('div_test');

    logger.info('Running the test...');

    // Add some simple reset behavior at specified timestamps
    Simulator.registerAction(1, () {
      intf.reset.put(0);
      intf.dividend.put(0);
      intf.divisor.put(0);
      intf.validIn.put(0);
    });
    Simulator.registerAction(10, () {
      intf.reset.put(1);
    });
    Simulator.registerAction(20, () {
      intf.reset.put(0);
    });

    // Wait for the next negative edge of reset
    await intf.reset.nextNegedge;

    // Kick off a sequence on the sequencer
    await _divSequencer.start(MultiCycleDividerBasicSequence());
    await _divSequencer.start(MultiCycleDividerVolumeSequence(1000));

    logger.info('Done adding stimulus to the sequencer');

    // Done adding stimulus, we can drop our objection now
    obj.drop();
  }
}

class TopTB {
  // Instance of the DUT
  late final MultiCycleDivider divider;

  // A constant value for the width to use in this testbench
  static const int width = 32;

  TopTB(MultiCycleDividerInterface intf) {
    // Connect a generated clock to the interface
    intf.clk <= SimpleClockGenerator(10).clk;

    // Create the DUT, passing it our interface
    divider = MultiCycleDivider(intf);
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('divider tests', () {
    test('VF tests', () async {
      // Set the logger level
      Logger.root.level = Level.OFF;

      // Create the testbench
      final intf = MultiCycleDividerInterface();
      final tb = TopTB(intf);

      // Build the DUT
      await tb.divider.build();

      // Attach a waveform dumper to the DUT
      WaveDumper(tb.divider);

      // Set a maximum simulation time so it doesn't run forever
      Simulator.setMaxSimTime(100000);

      // Create and start the test!
      final test = MultiCycleDividerTest(tb.divider, intf);
      await test.start();
    });

    test('Factory method build', () async {
      final clk = Logic(name: 'clk');
      final reset = Logic(name: 'reset');
      final validIn = Logic(name: 'validIn');
      final dividend = Logic(name: 'dividend', width: 32);
      final divisor = Logic(name: 'divisor', width: 32);
      final readyOut = Logic(name: 'readyOut');
      final div = MultiCycleDivider.ofLogics(
          clk: clk,
          reset: reset,
          validIn: validIn,
          dividend: dividend,
          divisor: divisor,
          readyOut: readyOut);
      await div.build();

      Logic(name: 'tValidOut').gets(div.validOut);
      Logic(name: 'tQuotient', width: 32).gets(div.quotient);
      Logic(name: 'tDivZero').gets(div.divZero);
      Logic(name: 'tReadyIn').gets(div.readyIn);
    });
  });
}
