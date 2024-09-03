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

class DivInputSeqItem extends SequenceItem {
  final int mDividend;
  final int mDivisor;
  final bool mValidIn;
  DivInputSeqItem(
      {required this.mDividend,
      required this.mDivisor,
      required this.mValidIn});

  int get dividend => mDividend;
  int get divisor => mDivisor;
  int get validIn => mValidIn ? 1 : 0;

  @override
  String toString() =>
      'dividend=${_twosComp(mDividend, 32)}, divisor=${_twosComp(mDivisor, 32)}, validIn=$mValidIn';
}

class DivOutputSeqItem extends SequenceItem {
  final int mQuotient;
  final bool mDivZero;
  final bool mValidOut;
  final bool mIsBusy;
  DivOutputSeqItem(
      {required this.mQuotient,
      required this.mDivZero,
      required this.mValidOut,
      required this.mIsBusy});

  int get quotient => mQuotient;
  int get divZero => mDivZero ? 1 : 0;
  int get validOut => mValidOut ? 1 : 0;
  int get isBusy => mIsBusy ? 1 : 0;

  @override
  String toString() =>
      'quotient=$mQuotient, divZero=$mDivZero, validOut=$mValidOut, isBusy=$mIsBusy';
}

class DivSequencer extends Sequencer<DivInputSeqItem> {
  DivSequencer(Component parent, {String name = 'divSequencer'})
      : super(name, parent);
}

class DivDriver extends Driver<DivInputSeqItem> {
  final DivInterface intf;

  // Keep a queue of items from the sequencer to be driven when desired
  final Queue<DivInputSeqItem> _pendingItems = Queue<DivInputSeqItem>();

  Objection? _driverObjection;

  DivDriver(this.intf, DivSequencer sequencer, Component parent,
      {String name = 'divDriver'})
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
      if (_pendingItems.isNotEmpty && intf.isBusy.value == LogicValue.zero) {
        var nextItem = _pendingItems.removeFirst();
        print(nextItem);
        drive(nextItem);
        if (_pendingItems.isEmpty) {
          _driverObjection?.drop();
          _driverObjection = null;
        }
      }
    });
  }

  // Translate a SequenceItem into pin wiggles
  void drive(DivInputSeqItem? item) {
    if (item == null) {
      intf.dividend.inject(0);
      intf.divisor.inject(0);
      intf.validIn.inject(0);
    } else {
      intf.dividend.inject(item.dividend);
      intf.divisor.inject(item.divisor);
      intf.validIn.inject(item.validIn);
    }
  }
}

class DivInputMonitor extends Monitor<DivInputSeqItem> {
  /// Instance of the [Interface] to the DUT.
  final DivInterface intf;

  DivInputMonitor(this.intf, Component parent,
      {String name = 'divInputMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    // Every positive edge of the clock
    intf.clk.posedge.listen((event) {
      if (intf.validIn.value == LogicValue.one &&
          intf.isBusy.value == LogicValue.zero) {
        add(DivInputSeqItem(
            mDividend:
                _twosComp(intf.dividend.value.toInt(), intf.dividend.width),
            mDivisor: _twosComp(intf.divisor.value.toInt(), intf.divisor.width),
            mValidIn: true)); // must convert to two's complement rep.
      }
    });
  }
}

class DivOutputMonitor extends Monitor<DivOutputSeqItem> {
  /// Instance of the [Interface] to the DUT.
  final DivInterface intf;

  DivOutputMonitor(this.intf, Component parent,
      {String name = 'divInputMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    // Every positive edge of the clock
    intf.clk.posedge.listen((event) {
      if (intf.validOut.value == LogicValue.one) {
        add(DivOutputSeqItem(
            mQuotient: _twosComp(intf.quotient.value.toInt(),
                intf.quotient.width), // must convert to two's complement rep.
            mDivZero: intf.divZero.value == LogicValue.one,
            mValidOut: true,
            mIsBusy: intf.isBusy.value == LogicValue.one));
      }
    });
  }
}

class DivScoreboard extends Component {
  final Stream<DivInputSeqItem> inStream;
  final Stream<DivOutputSeqItem> outStream;

  final DivInterface intf;

  DivScoreboard(this.inStream, this.outStream, this.intf, Component parent,
      {String name = 'divScoreboard'})
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
            String msg = (in2 == 0)
                ? 'Divide by 0 error correctly encountered for denominator of 0.'
                : 'Correct result: a=$in1, b=$in2, result=$currResult';
            logger.info(msg);
          } else {
            String msg = (in2 == 0)
                ? 'No Divide by zero error for denominator of 0.'
                : 'Incorrect result: a=$in1, b=$in2, result=$currResult';
            logger.severe(msg);
          }
          triggerCheck = false;
        }
      }
    });
  }
}

class DivAgent extends Agent {
  final DivInterface intf;
  late final DivSequencer sequencer;
  late final DivDriver driver;
  late final DivInputMonitor inMonitor;
  late final DivOutputMonitor outMonitor;

  DivAgent(this.intf, Component parent, {String name = 'divAgent'})
      : super(name, parent) {
    sequencer = DivSequencer(this);
    driver = DivDriver(intf, sequencer, this);
    inMonitor = DivInputMonitor(intf, this);
    outMonitor = DivOutputMonitor(intf, this);
  }
}

class DivEnv extends Env {
  final DivInterface intf;

  late final DivAgent agent;
  late final DivScoreboard scoreboard;

  DivEnv(this.intf, Component parent, {String name = 'divEnv'})
      : super(name, parent) {
    agent = DivAgent(intf, this);
    scoreboard = DivScoreboard(
        agent.inMonitor.stream, agent.outMonitor.stream, intf, this);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));
  }
}

class DivBasicSequence extends Sequence {
  DivBasicSequence({String name = 'divBasicSequence'}) : super(name);

  @override
  Future<void> body(Sequencer sequencer) async {
    final divSequencer = sequencer as DivSequencer;

    divSequencer.add(DivInputSeqItem(
        mDividend: 4, mDivisor: 2, mValidIn: true)); // even divide by 2
    divSequencer.add(DivInputSeqItem(
        mDividend: 9, mDivisor: 3, mValidIn: true)); // even divide not by 2
    divSequencer.add(DivInputSeqItem(
        mDividend: 5, mDivisor: 2, mValidIn: true)); // not even divide
    divSequencer.add(DivInputSeqItem(
        mDividend: 4, mDivisor: 1, mValidIn: true)); // divide by 1
    divSequencer.add(DivInputSeqItem(
        mDividend: -10, mDivisor: 2, mValidIn: true)); // negative-positive
    divSequencer.add(DivInputSeqItem(
        mDividend: 13, mDivisor: -10, mValidIn: true)); // positive-negative
    divSequencer.add(DivInputSeqItem(
        mDividend: -10, mDivisor: -9, mValidIn: true)); // negative-negative
    divSequencer.add(DivInputSeqItem(
        mDividend: 1, mDivisor: 4, mValidIn: true)); // bigger divisor
    divSequencer.add(DivInputSeqItem(
        mDividend: 4, mDivisor: 0, mValidIn: true)); // divide by 0
  }
}

class DivVolumeSequence extends Sequence {
  final int numReps;
  final rng = Random(0xdeadbeef); // fixed seed

  DivVolumeSequence(this.numReps, {String name = 'divVolumeSequence'})
      : super(name);

  @override
  Future<void> body(Sequencer sequencer) async {
    final divSequencer = sequencer as DivSequencer;

    for (var i = 0; i < numReps; i++) {
      final a = rng.nextInt(1 << 32); // TODO: parametrize
      final b = rng.nextInt(1 << 32); // TODO: parametrize
      divSequencer
          .add(DivInputSeqItem(mDividend: a, mDivisor: b, mValidIn: true));
    }
  }
}

class DivTest extends Test {
  final Divider dut;

  /// The test environment for [dut].
  late final DivEnv env;

  /// A private, local pointer to the test environment's [Sequencer].
  late final DivSequencer _divSequencer;

  DivTest(this.dut, {String name = 'divTest'}) : super(name) {
    env = DivEnv(dut.intf, this);
    _divSequencer = env.agent.sequencer;
  }

  // A "time consuming" method, similar to `task` in SystemVerilog, which
  // waits for a given number of cycles before completing.
  Future<void> waitCycles(int numCycles) async {
    for (var i = 0; i < numCycles; i++) {
      await dut.intf.clk.nextNegedge;
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
      dut.intf.reset.put(0);
      dut.intf.dividend.put(0);
      dut.intf.divisor.put(0);
      dut.intf.validIn.put(0);
    });
    Simulator.registerAction(10, () {
      dut.intf.reset.put(1);
    });
    Simulator.registerAction(20, () {
      dut.intf.reset.put(0);
    });

    // Wait for the next negative edge of reset
    await dut.intf.reset.nextNegedge;

    // Kick off a sequence on the sequencer
    await _divSequencer.start(DivBasicSequence());
    await _divSequencer.start(DivVolumeSequence(1000));

    logger.info('Done adding stimulus to the sequencer');

    // Done adding stimulus, we can drop our objection now
    obj.drop();
  }
}

class TopTB {
  // Instance of the DUT
  late final Divider divider;

  // A constant value for the width to use in this testbench
  static const int width = 32;

  TopTB() {
    final intf = DivInterface(dataWidth: width);

    // Connect a generated clock to the interface
    intf.clk <= SimpleClockGenerator(10).clk;

    // Create the DUT, passing it our interface
    divider = Divider(interface: intf);
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('divider tests', () {
    test('VF tests', () async {
      // Set the logger level
      Logger.root.level = Level.ALL;

      // Create the testbench
      final tb = TopTB();

      // Build the DUT
      await tb.divider.build();

      // Attach a waveform dumper to the DUT
      //WaveDumper(tb.divider);

      // Set a maximum simulation time so it doesn't run forever
      Simulator.setMaxSimTime(100000);

      // Create and start the test!
      final test = DivTest(tb.divider);
      await test.start();
    });
  });
}
