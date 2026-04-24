// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// divider_test.dart
// Tests for Integer Divider
//
// 2024 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

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
  final bool mIsSigned;
  final bool mValidIn;
  final bool mReadyOut;
  MultiCycleDividerInputSeqItem(
      {required this.mDividend,
      required this.mDivisor,
      required this.mIsSigned,
      required this.mValidIn,
      required this.mReadyOut});

  int get dividend => mDividend;
  int get divisor => mDivisor;
  int get isSigned => mIsSigned ? 1 : 0;
  int get validIn => mValidIn ? 1 : 0;
  int get readyOut => mReadyOut ? 1 : 0;

  @override
  String toString() => '''
dividend=$mDividend, 
divisor=$mDivisor,
isSigned=$mIsSigned,
validIn=$mValidIn,
readyOut=$mReadyOut
''';
}

class MultiCycleDividerOutputSeqItem extends SequenceItem {
  final int mQuotient;
  final int mRemainder;
  final bool mDivZero;
  final bool mValidOut;
  final bool mReadyIn;
  MultiCycleDividerOutputSeqItem(
      {required this.mQuotient,
      required this.mRemainder,
      required this.mDivZero,
      required this.mValidOut,
      required this.mReadyIn});

  int get quotient => mQuotient;
  int get remainder => mRemainder;
  int get divZero => mDivZero ? 1 : 0;
  int get validOut => mValidOut ? 1 : 0;
  int get readyIn => mReadyIn ? 1 : 0;

  @override
  String toString() => '''
quotient=$mQuotient,
remainder=$mRemainder, 
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
    sequencer.stream.listen((newItem) async {
      _driverObjection ??= phase.raiseObjection('div_driver');
      unawaited(_driverObjection!.dropped
          .then((value) => logger.fine('Driver objection dropped')));
      _pendingItems.add(newItem);
    });

    // Every clock negative edge, drive the next pending item if it exists
    // but only when the DUT isn't busy
    intf.clk.negedge.listen((args) {
      if (_pendingItems.isNotEmpty && intf.readyIn.value == LogicValue.one) {
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
      intf.isSigned.inject(0);
      intf.validIn.inject(0);
      intf.readyOut.inject(1);
    } else {
      intf.dividend.inject(item.dividend);
      intf.divisor.inject(item.divisor);
      intf.isSigned.inject(item.isSigned);
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
          intf.readyIn.value == LogicValue.one) {
        add(MultiCycleDividerInputSeqItem(
            mDividend: intf.isSigned.value.toBool()
                ? _twosComp(intf.dividend.value.toInt(), intf.dividend.width)
                : intf.dividend.value.toInt(),
            mDivisor: intf.isSigned.value.toBool()
                ? _twosComp(intf.divisor.value.toInt(), intf.divisor.width)
                : intf.divisor.value.toInt(),
            mIsSigned: intf.isSigned.value.toBool(),
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
            // must convert to two's complement rep.
            mQuotient: intf.quotient.value.toInt(),
            mRemainder: intf.remainder.value.toInt(),
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

  /// When [false], only the quotient is verified and remainder is expected
  /// to always be 0.
  final bool computeRemainder;

  MultiCycleDividerScoreboard(
      this.inStream, this.outStream, this.intf, Component parent,
      {this.computeRemainder = true,
      String name = 'MultiCycleDividerScoreboard'})
      : super(name, parent);

  final List<int> _aQueue = [];
  final List<int> _bQueue = [];
  final List<bool> _signQueue = [];

  int _currResult = 0;
  int _currRemain = 0;
  bool _divZero = false;
  bool _triggerCheck = false;

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await intf.reset.nextNegedge;

    inStream.listen((event) {
      _aQueue.add(event.mDividend);
      _bQueue.add(event.mDivisor);
      _signQueue.add(event.mIsSigned);
    });

    outStream.listen((event) {
      _currResult = event.mQuotient;
      _currRemain = event.mRemainder;
      _divZero = event.mDivZero;
      if (!computeRemainder) {
        expect(event.mRemainder, 0,
            reason: 'remainder must be 0 in quotient-only mode');
      }
      _triggerCheck = true;
    });

    intf.clk.negedge.listen((_) {
      if (_aQueue.isNotEmpty && _triggerCheck) {
        final in1 = _aQueue.removeAt(0);
        final in2 = _bQueue.removeAt(0);
        final inSign = _signQueue.removeAt(0);

        final tCurrResult =
            inSign ? _twosComp(_currResult, intf.quotient.width) : _currResult;
        final tCurrRemain = inSign
            ? _twosComp(_currRemain, intf.remainder.width)
            : _currRemain;

        final overflow = inSign &&
            in1 ==
                _twosComp(
                    1 << (intf.quotient.width - 1), intf.quotient.width) &&
            in2 == -1;

        bool check1;
        bool check2;

        if (in2 == 0) {
          check1 = _divZero;
          check2 = _divZero;
        } else if (overflow) {
          check1 = tCurrResult ==
              _twosComp(1 << (intf.quotient.width - 1), intf.quotient.width);
          check2 = tCurrRemain == 0;
        } else {
          check1 = (in1 ~/ in2) == tCurrResult;
          check2 = computeRemainder
              ? (in1 - (in2 * tCurrResult)) == tCurrRemain
              : true; // remainder not computed; skip check
        }

        if (check1 && check2) {
          logger.info(in2 == 0
              ? 'Divide by 0 error correctly encountered for denominator of 0.'
              : 'Correct result: dividend=$in1, divisor=$in2, '
                  'quotient=$tCurrResult, remainder=$tCurrRemain');
        } else {
          logger.severe(in2 == 0
              ? 'No Divide by zero error for denominator of 0.'
              : 'Incorrect result: dividend=$in1, divisor=$in2, '
                  'quotient=$tCurrResult, remainder=$tCurrRemain');
        }
        _triggerCheck = false;
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
  final bool computeRemainder;

  late final MultiCycleDividerAgent agent;
  late final MultiCycleDividerScoreboard scoreboard;

  MultiCycleDividerEnv(this.intf, Component parent,
      {this.computeRemainder = true,
      String name = 'MultiCycleDividerEnv'})
      : super(name, parent) {
    agent = MultiCycleDividerAgent(intf, this);
    scoreboard = MultiCycleDividerScoreboard(
        agent.inMonitor.stream, agent.outMonitor.stream, intf, this,
        computeRemainder: computeRemainder);
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
          mIsSigned: true,
          mReadyOut: true)) // even divide by 2
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 9,
          mDivisor: 3,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true)) // even divide not by 2
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 5,
          mDivisor: 2,
          mValidIn: true,
          mIsSigned: false,
          mReadyOut: true)) // not even divide
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 4,
          mDivisor: 1,
          mValidIn: true,
          mIsSigned: false,
          mReadyOut: true)) // divide by 1
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: -10,
          mDivisor: 2,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true)) // negative-positive
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 13,
          mDivisor: -10,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true)) // positive-negative
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: -10,
          mDivisor: -9,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true)) // negative-negative
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 1,
          mDivisor: 4,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true)) // bigger divisor
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 4,
          mDivisor: 0,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true)) // divide by 0
      // long latency division
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 0xffffffec,
          mDivisor: 0x6,
          mValidIn: true,
          mIsSigned: false,
          mReadyOut: true));
  }
}

class MultiCycleDividerEvilSequence extends Sequence {
  late final int numBits;

  MultiCycleDividerEvilSequence(
      {required this.numBits, String name = 'MultiCycleDividerEvilSequence'})
      : super(name);

  @override
  Future<void> body(Sequencer sequencer) async {
    sequencer as MultiCycleDividerSequencer
      // largest positive divided by largest positive
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)) - 1,
          mDivisor: (1 << (numBits - 1)) - 1,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      // largest positive divided by largest negative
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)) - 1,
          mDivisor: (1 << (numBits - 1)),
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      // largest negative divided by largest positive
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)),
          mDivisor: (1 << (numBits - 1)) - 1,
          mValidIn: true,
          mIsSigned: false,
          mReadyOut: true))
      // largest negative divided by largest negative
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)),
          mDivisor: (1 << (numBits - 1)),
          mValidIn: true,
          mIsSigned: false,
          mReadyOut: true))
      // largest positive divided by negative 1
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)) - 1,
          mDivisor: -1,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      // largest negative divided by negative 1
      // this is the only true overflow case...
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)),
          mDivisor: -1,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      // largest positive divided by 1
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)) - 1,
          mDivisor: 1,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      // largest negative divided by 1
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)),
          mDivisor: 1,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      // unsigned version of overflow case
      // which should not result in overflow
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)),
          mDivisor: -1,
          mValidIn: true,
          mIsSigned: false,
          mReadyOut: true));
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
      final isSigned = i % 2;
      divSequencer.add(MultiCycleDividerInputSeqItem(
          mDividend: a,
          mDivisor: b,
          mIsSigned: isSigned == 0,
          mValidIn: true,
          mReadyOut: true));
    }
  }
}

class MultiCycleDividerTest extends Test {
  final MultiCycleDivider dut;
  late final MultiCycleDividerInterface intf;
  final bool computeRemainder;

  /// Optional override sequences. When non-null, [run] starts these instead
  /// of the default basic/evil/volume sequences.
  final List<Sequence>? sequences;

  /// The test environment for [dut].
  late final MultiCycleDividerEnv env;

  /// A private, local pointer to the test environment's [Sequencer].
  late final MultiCycleDividerSequencer _divSequencer;

  MultiCycleDividerTest(this.dut, this.intf,
      {this.computeRemainder = true,
      this.sequences,
      String name = 'MultiCycleDividerTest'})
      : super(name) {
    env = MultiCycleDividerEnv(intf, this, computeRemainder: computeRemainder);
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

    logger.info('Running the test (computeRemainder=$computeRemainder)...');

    // Add some simple reset behavior at specified timestamps
    Simulator.registerAction(1, () {
      intf.reset.put(0);
      intf.dividend.put(0);
      intf.divisor.put(0);
      intf.validIn.put(0);
    });
    Simulator.registerAction(10, () => intf.reset.put(1));
    Simulator.registerAction(20, () => intf.reset.put(0));

    // Wait for the next negative edge of reset
    await intf.reset.nextNegedge;

    // Kick off sequences on the sequencer
    if (sequences != null) {
      for (final seq in sequences!) {
        await _divSequencer.start(seq);
      }
    } else {
      await _divSequencer.start(MultiCycleDividerBasicSequence());
      await _divSequencer.start(MultiCycleDividerEvilSequence(numBits: 32));
      await _divSequencer.start(MultiCycleDividerVolumeSequence(1000));
    }

    logger.info('Done adding stimulus to the sequencer');

    // Done adding stimulus, we can drop our objection now
    obj.drop();
  }
}

class TopTB {
  late final MultiCycleDivider divider;
  static const int width = 32;

  TopTB(MultiCycleDividerInterface intf, {bool computeRemainder = true}) {
    intf.clk <= SimpleClockGenerator(10).clk;
    divider = MultiCycleDivider(intf, computeRemainder: computeRemainder);
  }
}

// ---------------------------------------------------------------------------
// Corner-case sequence and narrow testbench
// ---------------------------------------------------------------------------

/// Corner-case sequence parameterised by [dataWidth] so numeric bounds match.
class MultiCycleDividerCornerSequence extends Sequence {
  final int dataWidth;

  MultiCycleDividerCornerSequence(
      {required this.dataWidth,
      String name = 'MultiCycleDividerCornerSequence'})
      : super(name);

  @override
  Future<void> body(Sequencer sequencer) async {
    final seq = sequencer as MultiCycleDividerSequencer;

    final maxU = (1 << dataWidth) - 1; // e.g. 255 for 8-bit
    final maxS = (1 << (dataWidth - 1)) - 1; // e.g.  127
    final minS = -(1 << (dataWidth - 1)); // e.g. -128

    void add(int a, int b, {required bool signed, required String desc}) =>
        seq.add(MultiCycleDividerInputSeqItem(
            mDividend: a,
            mDivisor: b,
            mIsSigned: signed,
            mValidIn: true,
            mReadyOut: true));

    // ---- unsigned -----------------------------------------------------------
    add(0, 1, signed: false, desc: 'U: 0/1');
    add(0, maxU, signed: false, desc: 'U: 0/MAX');
    add(1, maxU, signed: false, desc: 'U: 1/MAX → q=0,r=1');
    add(6, 3, signed: false, desc: 'U: even divide');
    add(7, 3, signed: false, desc: 'U: divide with remainder');
    add(5, 1, signed: false, desc: 'U: divide-by-1');
    add(8, 4, signed: false, desc: 'U: power-of-2 divisor');
    add(9, 4, signed: false, desc: 'U: power-of-2 divisor with rem');
    add(maxU, 1, signed: false, desc: 'U: MAX/1 (worst-case latency)');
    add(maxU, maxU, signed: false, desc: 'U: MAX/MAX=1');
    add(maxU, maxU - 1, signed: false, desc: 'U: MAX/(MAX-1)=1,r=1');
    add(6, 0, signed: false, desc: 'U: dz nonzero dividend');
    add(0, 0, signed: false, desc: 'U: dz zero dividend');

    // ---- signed: +/+ --------------------------------------------------------
    add(6, 3, signed: true, desc: 'S: +6/+3');
    add(7, 3, signed: true, desc: 'S: +7/+3 with rem');
    add(1, maxS, signed: true, desc: 'S: 1/MAX → q=0');
    add(maxS, 1, signed: true, desc: 'S: MAX/1 → q=MAX');
    add(maxS, maxS, signed: true, desc: 'S: MAX/MAX=1');

    // ---- signed: +/- --------------------------------------------------------
    add(6, -3, signed: true, desc: 'S: +6/-3 → q=-2');
    add(7, -3, signed: true, desc: 'S: +7/-3 → q=-2,r=1');
    add(maxS, -1, signed: true, desc: 'S: MAX/-1 → q=-MAX');

    // ---- signed: -/+ --------------------------------------------------------
    add(-6, 3, signed: true, desc: 'S: -6/+3 → q=-2');
    add(-7, 3, signed: true, desc: 'S: -7/+3 → q=-2,r=-1');
    add(minS, 1, signed: true, desc: 'S: MIN/1 → q=MIN');

    // ---- signed: -/- --------------------------------------------------------
    add(-6, -3, signed: true, desc: 'S: -6/-3 → q=2');
    add(-7, -3, signed: true, desc: 'S: -7/-3 → q=2,r=-1');
    add(minS, minS, signed: true, desc: 'S: MIN/MIN=1');

    // ---- signed overflow (the only true overflow case) ----------------------
    add(minS, -1, signed: true, desc: 'S: ov MIN/-1');

    // ---- signed divide-by-zero ----------------------------------------------
    add(3, 0, signed: true, desc: 'S: dz positive');
    add(-3, 0, signed: true, desc: 'S: dz negative');
    add(0, 0, signed: true, desc: 'S: dz zero dividend');
  }
}

class TopTBNarrow {
  late final MultiCycleDivider divider;
  static const int width = 8;

  TopTBNarrow(MultiCycleDividerInterface intf, {bool computeRemainder = true}) {
    intf.clk <= SimpleClockGenerator(10).clk;
    divider = MultiCycleDivider(intf, computeRemainder: computeRemainder);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  // Run the full VF + factory-method smoke tests in both modes.
  for (final computeRemainder in [true, false]) {
    final label = computeRemainder ? 'with remainder' : 'quotient-only';

    group('divider tests ($label)', () {
      test('VF tests', () async {
        Logger.root.level = Level.SEVERE;

        final intf = MultiCycleDividerInterface();
        final tb = TopTB(intf, computeRemainder: computeRemainder);
        await tb.divider.build();

        Simulator.setMaxSimTime(200000);

        final test = MultiCycleDividerTest(tb.divider, intf,
            computeRemainder: computeRemainder);
        await test.start();
      });

      test('Factory method build', () async {
        final clk = Logic(name: 'clk');
        final reset = Logic(name: 'reset');
        final validIn = Logic(name: 'validIn');
        final dividend = Logic(name: 'dividend', width: 32);
        final divisor = Logic(name: 'divisor', width: 32);
        final isSigned = Logic(name: 'isSigned');
        final readyOut = Logic(name: 'readyOut');
        final div = MultiCycleDivider.ofLogics(
            clk: clk,
            reset: reset,
            validIn: validIn,
            dividend: dividend,
            divisor: divisor,
            isSigned: isSigned,
            readyOut: readyOut,
            computeRemainder: computeRemainder);
        await div.build();

        Logic(name: 'tValidOut').gets(div.validOut);
        Logic(name: 'tQuotient', width: 32).gets(div.quotient);
        Logic(name: 'tRemainder', width: 32).gets(div.remainder);
        Logic(name: 'tDivZero').gets(div.divZero);
        Logic(name: 'tReadyIn').gets(div.readyIn);
      });
    });
  }

  test('quotient-only is O(n) cycles — latency == dataWidth+2 cycles',
      () async {
    const w = 8;
    final intf = MultiCycleDividerInterface(dataWidth: w);
    intf.clk <= SimpleClockGenerator(10).clk;
    final dut = MultiCycleDivider(intf, computeRemainder: false);
    await dut.build();

    int? latency;
    int startCycle = 0;
    int cycleCount = 0;

    intf.clk.posedge.listen((_) => cycleCount++);

    Simulator.registerAction(1, () {
      intf.reset.put(0);
      intf.dividend.put(0);
      intf.divisor.put(0);
      intf.validIn.put(0);
      intf.readyOut.put(1);
    });
    Simulator.registerAction(10, () => intf.reset.put(1));
    Simulator.registerAction(20, () => intf.reset.put(0));

    Simulator.setMaxSimTime(5000);

    unawaited(Simulator.run());

    await intf.reset.nextNegedge;

    // Worst-case: dividend=255, divisor=1 (unsigned 8-bit).
    intf.validIn.put(1);
    intf.dividend.put(255);
    intf.divisor.put(1);
    intf.isSigned.put(0);
    startCycle = cycleCount;

    await intf.clk.nextPosedge; // input accepted
    intf.validIn.put(0);

    await intf.validOut.nextPosedge;
    latency = cycleCount - startCycle;

    // O(n): exactly w process cycles + 1 convert + 1 done leading edge.
    expect(latency, equals(w + 2),
        reason: 'O(n) divider latency should be dataWidth+2=$w+2 cycles');
    expect(intf.quotient.value.toInt(), equals(255));
    expect(intf.remainder.value.toInt(), equals(0));

    await Simulator.endSimulation();
  });

  // ---------------------------------------------------------------------------
  // Targeted corner-case tests using an 8-bit DUT via the VF harness.
  //
  // An 8-bit DUT keeps simulation fast (O(n²) worst-case ≤ 64 cycles/op)
  // while each vector targets a distinct structural corner.
  // ---------------------------------------------------------------------------
  for (final computeRemainder in [true, false]) {
    final label = computeRemainder ? 'with remainder' : 'quotient-only';

    group('divider corner cases 8-bit ($label)', () {
      test('targeted structural corners', () async {
        Logger.root.level = Level.SEVERE;

        final intf = MultiCycleDividerInterface(dataWidth: TopTBNarrow.width);
        final tb = TopTBNarrow(intf, computeRemainder: computeRemainder);
        await tb.divider.build();

        Simulator.setMaxSimTime(500000);

        final test = MultiCycleDividerTest(tb.divider, intf,
            computeRemainder: computeRemainder,
            sequences: [
              MultiCycleDividerCornerSequence(dataWidth: TopTBNarrow.width)
            ]);

        await test.start();
      }, timeout: const Timeout(Duration(minutes: 1)));
    });
  }
}
