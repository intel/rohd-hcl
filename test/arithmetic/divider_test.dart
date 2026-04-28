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

// ---------------------------------------------------------------------------
// Helper: two's complement decode
// ---------------------------------------------------------------------------

/// Decode a raw unsigned bit pattern as a two's complement signed integer.
int _twosComp(int val, int bits) {
  var tmp = val;
  if (val & (1 << (bits - 1)) != 0) {
    tmp = tmp - (1 << bits);
  }
  return tmp;
}

// ---------------------------------------------------------------------------
// Sequence items
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Sequencer / Driver / Monitors
// ---------------------------------------------------------------------------

class MultiCycleDividerSequencer
    extends Sequencer<MultiCycleDividerInputSeqItem> {
  MultiCycleDividerSequencer(Component parent,
      {String name = 'MultiCycleDividerSequencer'})
      : super(name, parent);
}

class MultiCycleDividerDriver extends Driver<MultiCycleDividerInputSeqItem> {
  final MultiCycleDividerInterface intf;

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

    sequencer.stream.listen((newItem) async {
      _driverObjection ??= phase.raiseObjection('div_driver');
      unawaited(_driverObjection!.dropped
          .then((value) => logger.fine('Driver objection dropped')));
      _pendingItems.add(newItem);
    });

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
  final MultiCycleDividerInterface intf;

  MultiCycleDividerInputMonitor(this.intf, Component parent,
      {String name = 'MultiCycleDividerInputMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

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
            mReadyOut: true));
      }
    });
  }
}

class MultiCycleDividerOutputMonitor
    extends Monitor<MultiCycleDividerOutputSeqItem> {
  final MultiCycleDividerInterface intf;

  MultiCycleDividerOutputMonitor(this.intf, Component parent,
      {String name = 'MultiCycleDividerOutputMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    intf.clk.posedge.listen((event) {
      if (intf.validOut.value == LogicValue.one) {
        add(MultiCycleDividerOutputSeqItem(
            mQuotient: intf.quotient.value.toInt(),
            mRemainder: intf.remainder.value.toInt(),
            mDivZero: intf.divZero.value == LogicValue.one,
            mValidOut: true,
            mReadyIn: intf.readyIn.value == LogicValue.one));
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Scoreboard / Agent / Env
// ---------------------------------------------------------------------------

class MultiCycleDividerScoreboard extends Component {
  final Stream<MultiCycleDividerInputSeqItem> inStream;
  final Stream<MultiCycleDividerOutputSeqItem> outStream;
  final MultiCycleDividerInterface intf;
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
        final tCurrRemain =
            inSign ? _twosComp(_currRemain, intf.remainder.width) : _currRemain;

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
          check2 =
              !computeRemainder || (in1 - (in2 * tCurrResult)) == tCurrRemain;
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
      {this.computeRemainder = true, String name = 'MultiCycleDividerEnv'})
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

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

class MultiCycleDividerTest extends Test {
  final Module dut;
  late final MultiCycleDividerInterface intf;
  final bool computeRemainder;
  final List<Sequence>? sequences;

  late final MultiCycleDividerEnv env;
  late final MultiCycleDividerSequencer _divSequencer;

  MultiCycleDividerTest(this.dut, this.intf,
      {this.computeRemainder = true,
      this.sequences,
      String name = 'MultiCycleDividerTest'})
      : super(name) {
    env = MultiCycleDividerEnv(intf, this, computeRemainder: computeRemainder);
    _divSequencer = env.agent.sequencer;
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('div_test');
    logger.info('Running the test (computeRemainder=$computeRemainder)...');

    Simulator.registerAction(1, () {
      intf.reset.put(0);
      intf.dividend.put(0);
      intf.divisor.put(0);
      intf.validIn.put(0);
    });
    Simulator.registerAction(10, () => intf.reset.put(1));
    Simulator.registerAction(20, () => intf.reset.put(0));

    await intf.reset.nextNegedge;

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
    obj.drop();
  }
}

// ---------------------------------------------------------------------------
// Testbenches
// ---------------------------------------------------------------------------

class TopTB {
  late final MultiCycleDivider divider;
  static const int width = 32;

  TopTB(MultiCycleDividerInterface intf, {bool computeRemainder = true}) {
    intf.clk <= SimpleClockGenerator(10).clk;
    divider = MultiCycleDivider(intf, computeRemainder: computeRemainder);
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
// Sequences
// ---------------------------------------------------------------------------

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
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 9,
          mDivisor: 3,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 5,
          mDivisor: 2,
          mValidIn: true,
          mIsSigned: false,
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 4,
          mDivisor: 1,
          mValidIn: true,
          mIsSigned: false,
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: -10,
          mDivisor: 2,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 13,
          mDivisor: -10,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: -10,
          mDivisor: -9,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 1,
          mDivisor: 4,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: 4,
          mDivisor: 0,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
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
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)) - 1,
          mDivisor: (1 << (numBits - 1)) - 1,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)) - 1,
          mDivisor: (1 << (numBits - 1)),
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)),
          mDivisor: (1 << (numBits - 1)) - 1,
          mValidIn: true,
          mIsSigned: false,
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)),
          mDivisor: (1 << (numBits - 1)),
          mValidIn: true,
          mIsSigned: false,
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)) - 1,
          mDivisor: -1,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)),
          mDivisor: -1,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)) - 1,
          mDivisor: 1,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
      ..add(MultiCycleDividerInputSeqItem(
          mDividend: (1 << (numBits - 1)),
          mDivisor: 1,
          mValidIn: true,
          mIsSigned: true,
          mReadyOut: true))
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
  final rng = Random(0xdeadbeef);

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

/// Corner-case sequence parameterised by [dataWidth] — signed vectors only.
class MultiCycleDividerCornerSequence extends Sequence {
  final int dataWidth;

  MultiCycleDividerCornerSequence(
      {required this.dataWidth,
      String name = 'MultiCycleDividerCornerSequence'})
      : super(name);

  @override
  Future<void> body(Sequencer sequencer) async {
    final seq = sequencer as MultiCycleDividerSequencer;

    final maxS = (1 << (dataWidth - 1)) - 1;
    final minS = -(1 << (dataWidth - 1));

    void add(int a, int b, {required bool signed}) =>
        seq.add(MultiCycleDividerInputSeqItem(
            mDividend: a,
            mDivisor: b,
            mIsSigned: signed,
            mValidIn: true,
            mReadyOut: true));

    // +/+
    add(6, 3, signed: true);
    add(7, 3, signed: true);
    add(1, maxS, signed: true);
    add(maxS, 1, signed: true);
    add(maxS, maxS, signed: true);
    // +/-
    add(6, -3, signed: true);
    add(7, -3, signed: true);
    add(maxS, -1, signed: true);
    // -/+
    add(-6, 3, signed: true);
    add(-7, 3, signed: true);
    add(minS, 1, signed: true);
    // -/-
    add(-6, -3, signed: true);
    add(-7, -3, signed: true);
    add(minS, minS, signed: true);
    // overflow
    add(minS, -1, signed: true);
    // divide-by-zero
    add(3, 0, signed: true);
    add(-3, 0, signed: true);
    add(0, 0, signed: true);
  }
}

int _to1sComp(int value, int bits) {
  final mask = (1 << bits) - 1;
  if (value < 0) {
    return ~ -value & mask;
  }
  return value & mask;
}

/// Interpret an n-bit raw value as a one's complement signed integer.
int _from1sComp(int raw, int bits) {
  if (raw & (1 << (bits - 1)) != 0) {
    return -(~raw & ((1 << bits) - 1));
  }
  return raw;
}

// ---------------------------------------------------------------------------
// Testbench
// ---------------------------------------------------------------------------

class TopTBOnesComp {
  late final OnesComplementDivider divider;
  static const int width = 8;

  TopTBOnesComp(MultiCycleDividerInterface intf,
      {bool computeRemainder = true}) {
    intf.clk <= SimpleClockGenerator(10).clk;
    divider = OnesComplementDivider(intf, computeRemainder: computeRemainder);
  }
}

// ---------------------------------------------------------------------------
// VF infrastructure
// ---------------------------------------------------------------------------

/// Input monitor that decodes pin values using [_from1sComp] instead of
/// [twosComp], so signed dividends/divisors are captured correctly.
class OnesComplementInputMonitor
    extends Monitor<MultiCycleDividerInputSeqItem> {
  final MultiCycleDividerInterface intf;

  OnesComplementInputMonitor(this.intf, Component parent,
      {String name = 'OnesComplementInputMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));
    intf.clk.posedge.listen((event) {
      if (intf.validIn.value == LogicValue.one &&
          intf.readyIn.value == LogicValue.one) {
        add(MultiCycleDividerInputSeqItem(
            mDividend: intf.isSigned.value.toBool()
                ? _from1sComp(intf.dividend.value.toInt(), intf.dividend.width)
                : intf.dividend.value.toInt(),
            mDivisor: intf.isSigned.value.toBool()
                ? _from1sComp(intf.divisor.value.toInt(), intf.divisor.width)
                : intf.divisor.value.toInt(),
            mIsSigned: intf.isSigned.value.toBool(),
            mValidIn: true,
            mReadyOut: true));
      }
    });
  }
}

/// Scoreboard for [OnesComplementDivider].
///
/// Interprets both inputs (via [_from1sComp] in the input monitor) and raw
/// register outputs (via [_from1sComp]) as one's complement signed integers.
/// For unsigned inputs the raw value is used as-is.
/// Divide-by-zero: triggered by all-zeros OR (signed) all-ones divisor.
class OnesComplementScoreboard extends Component {
  final Stream<MultiCycleDividerInputSeqItem> inStream;
  final Stream<MultiCycleDividerOutputSeqItem> outStream;
  final MultiCycleDividerInterface intf;
  final bool computeRemainder;

  OnesComplementScoreboard(
      this.inStream, this.outStream, this.intf, Component parent,
      {this.computeRemainder = true, String name = 'OnesComplementScoreboard'})
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

        final tCurrResult = inSign
            ? _from1sComp(_currResult, intf.quotient.width)
            : _currResult;
        final tCurrRemain = inSign
            ? _from1sComp(_currRemain, intf.remainder.width)
            : _currRemain;

        // in1/in2 already decoded by OnesComplementInputMonitor.
        final isDivZero = in2 == 0;

        bool check1;
        bool check2;
        if (isDivZero) {
          check1 = _divZero;
          check2 = _divZero;
        } else {
          check1 = (in1 ~/ in2) == tCurrResult;
          check2 =
              !computeRemainder || (in1 - (in2 * tCurrResult)) == tCurrRemain;
        }

        if (check1 && check2) {
          logger.info(isDivZero
              ? 'Divide by 0 error correctly encountered.'
              : 'Correct result: dividend=$in1, divisor=$in2, '
                  'quotient=$tCurrResult, remainder=$tCurrRemain');
        } else {
          logger.severe(isDivZero
              ? 'No Divide by zero error for denominator of 0.'
              : 'Incorrect result: dividend=$in1, divisor=$in2, '
                  'quotient=$tCurrResult, remainder=$tCurrRemain');
        }
        _triggerCheck = false;
      }
    });
  }
}

class OnesComplementAgent extends Agent {
  final MultiCycleDividerInterface intf;
  late final MultiCycleDividerSequencer sequencer;
  late final MultiCycleDividerDriver driver;
  late final OnesComplementInputMonitor inMonitor;
  late final MultiCycleDividerOutputMonitor outMonitor;

  OnesComplementAgent(this.intf, Component parent,
      {String name = 'OnesComplementAgent'})
      : super(name, parent) {
    sequencer = MultiCycleDividerSequencer(this);
    driver = MultiCycleDividerDriver(intf, sequencer, this);
    inMonitor = OnesComplementInputMonitor(intf, this);
    outMonitor = MultiCycleDividerOutputMonitor(intf, this);
  }
}

class OnesComplementEnv extends Env {
  final MultiCycleDividerInterface intf;
  final bool computeRemainder;

  late final OnesComplementAgent agent;
  late final OnesComplementScoreboard scoreboard;

  OnesComplementEnv(this.intf, Component parent,
      {this.computeRemainder = true, String name = 'OnesComplementEnv'})
      : super(name, parent) {
    agent = OnesComplementAgent(intf, this);
    scoreboard = OnesComplementScoreboard(
        agent.inMonitor.stream, agent.outMonitor.stream, intf, this,
        computeRemainder: computeRemainder);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));
  }
}

class OnesComplementTest extends Test {
  final Module dut;
  late final MultiCycleDividerInterface intf;
  final bool computeRemainder;
  final List<Sequence>? sequences;

  late final OnesComplementEnv env;
  late final MultiCycleDividerSequencer _sequencer;

  OnesComplementTest(this.dut, this.intf,
      {this.computeRemainder = true,
      this.sequences,
      String name = 'OnesComplementTest'})
      : super(name) {
    env = OnesComplementEnv(intf, this, computeRemainder: computeRemainder);
    _sequencer = env.agent.sequencer;
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));
    final obj = phase.raiseObjection('ones_comp_test');
    logger.info(
        'Running OnesComplementTest (computeRemainder=$computeRemainder)...');

    Simulator.registerAction(1, () {
      intf.reset.put(0);
      intf.dividend.put(0);
      intf.divisor.put(0);
      intf.validIn.put(0);
    });
    Simulator.registerAction(10, () => intf.reset.put(1));
    Simulator.registerAction(20, () => intf.reset.put(0));

    await intf.reset.nextNegedge;

    if (sequences != null) {
      for (final seq in sequences!) {
        await _sequencer.start(seq);
      }
    } else {
      await _sequencer
          .start(OnesCompSignedCornerSequence(dataWidth: intf.dataWidth));
    }

    obj.drop();
  }
}

// ---------------------------------------------------------------------------
// Sequences
// ---------------------------------------------------------------------------

/// Basic smoke sequence for [OnesComplementDivider].
class OnesCompBasicSequence extends Sequence {
  final int dataWidth;

  OnesCompBasicSequence(
      {required this.dataWidth, String name = 'OnesCompBasicSequence'})
      : super(name);

  @override
  Future<void> body(Sequencer sequencer) async {
    final seq = sequencer as MultiCycleDividerSequencer;

    void u(int a, int b) => seq.add(MultiCycleDividerInputSeqItem(
        mDividend: a,
        mDivisor: b,
        mIsSigned: false,
        mValidIn: true,
        mReadyOut: true));
    void s(int a, int b) => seq.add(MultiCycleDividerInputSeqItem(
        mDividend: _to1sComp(a, dataWidth),
        mDivisor: _to1sComp(b, dataWidth),
        mIsSigned: true,
        mValidIn: true,
        mReadyOut: true));

    s(4, 2);
    s(9, 3);
    u(5, 2);
    u(4, 1);
    s(-10, 2);
    s(13, -10);
    s(-10, -9);
    s(1, 4);
    s(4, 0);
    u((1 << (dataWidth - 1)) - 1, 6);
  }
}

/// Edge-case sequence for [OnesComplementDivider].
///
/// Targets boundary values specific to 1's complement including negative-zero
/// (-0 = all-ones) as divisor.
class OnesCompEvilSequence extends Sequence {
  final int dataWidth;

  OnesCompEvilSequence(
      {required this.dataWidth, String name = 'OnesCompEvilSequence'})
      : super(name);

  @override
  Future<void> body(Sequencer sequencer) async {
    final seq = sequencer as MultiCycleDividerSequencer;
    final maxS = (1 << (dataWidth - 1)) - 1;

    void s(int a, int b) => seq.add(MultiCycleDividerInputSeqItem(
        mDividend: _to1sComp(a, dataWidth),
        mDivisor: _to1sComp(b, dataWidth),
        mIsSigned: true,
        mValidIn: true,
        mReadyOut: true));
    void u(int a, int b) => seq.add(MultiCycleDividerInputSeqItem(
        mDividend: a,
        mDivisor: b,
        mIsSigned: false,
        mValidIn: true,
        mReadyOut: true));

    s(maxS, maxS);
    s(maxS, 1);
    s(maxS, -1);
    s(-maxS, 1);
    s(-maxS, -1);
    s(-maxS, maxS);
    s(maxS, -maxS);
    s(1, maxS);
    s(-1, maxS);
    u((1 << dataWidth) - 2, 1);
    u(0, 1);
    // negative-zero divisor (-0 = all-ones) → divZero
    seq.add(MultiCycleDividerInputSeqItem(
        mDividend: 5,
        mDivisor: (1 << dataWidth) - 1,
        mIsSigned: true,
        mValidIn: true,
        mReadyOut: true));
  }
}

/// Random volume sequence for [OnesComplementDivider].
class OnesCompVolumeSequence extends Sequence {
  final int dataWidth;
  final int numReps;
  final Random rng;

  OnesCompVolumeSequence(this.numReps,
      {required this.dataWidth,
      int seed = 0xdeadbeef,
      String name = 'OnesCompVolumeSequence'})
      : rng = Random(seed),
        super(name);

  @override
  Future<void> body(Sequencer sequencer) async {
    final seq = sequencer as MultiCycleDividerSequencer;
    final maxS = (1 << (dataWidth - 1)) - 1;
    final maxU = (1 << dataWidth) - 2; // exclude all-ones (-0)

    for (var i = 0; i < numReps; i++) {
      if (i % 2 == 0) {
        seq.add(MultiCycleDividerInputSeqItem(
            mDividend: rng.nextInt(maxU + 1),
            mDivisor: rng.nextInt(maxU + 1),
            mIsSigned: false,
            mValidIn: true,
            mReadyOut: true));
      } else {
        final a = rng.nextInt(2 * maxS + 1) - maxS;
        final b = rng.nextInt(2 * maxS + 1) - maxS;
        seq.add(MultiCycleDividerInputSeqItem(
            mDividend: _to1sComp(a, dataWidth),
            mDivisor: _to1sComp(b, dataWidth),
            mIsSigned: true,
            mValidIn: true,
            mReadyOut: true));
      }
    }
  }
}

/// Signed corner-case sequence for [OnesComplementDivider] — all four sign
/// quadrants plus both forms of divide-by-zero (positive and negative zero).
class OnesCompSignedCornerSequence extends Sequence {
  final int dataWidth;

  OnesCompSignedCornerSequence(
      {required this.dataWidth, String name = 'OnesCompSignedCornerSequence'})
      : super(name);

  @override
  Future<void> body(Sequencer sequencer) async {
    final seq = sequencer as MultiCycleDividerSequencer;

    void add(int a, int b) => seq.add(MultiCycleDividerInputSeqItem(
        mDividend: _to1sComp(a, dataWidth),
        mDivisor: _to1sComp(b, dataWidth),
        mIsSigned: true,
        mValidIn: true,
        mReadyOut: true));

    final maxS = (1 << (dataWidth - 1)) - 1;
    final minS = -maxS;

    // +/+
    add(6, 3);
    add(7, 3);
    add(1, maxS);
    add(maxS, 1);
    add(maxS, maxS);
    // +/-
    add(6, -3);
    add(7, -3);
    add(maxS, -1);
    // -/+
    add(-6, 3);
    add(-7, 3);
    add(minS, 1);
    // -/-
    add(-6, -3);
    add(-7, -3);
    add(minS, minS);
    // divide-by-zero: positive zero
    add(5, 0);
    // divide-by-zero: negative zero (-0 = all-ones)
    seq.add(MultiCycleDividerInputSeqItem(
        mDividend: 5,
        mDivisor: (1 << dataWidth) - 1,
        mIsSigned: true,
        mValidIn: true,
        mReadyOut: true));
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  for (final computeRemainder in [true, false]) {
    final label = computeRemainder ? 'with remainder' : 'quotient-only';

    group('2\'s C. Divider Tests ($label)', () {
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

    group('2\'s C. Divider Corner Cases ${TopTBNarrow.width}-bit ($label)', () {
      test('targeted structural corners', () async {
        Logger.root.level = Level.SEVERE;

        final intf = MultiCycleDividerInterface(dataWidth: TopTBNarrow.width);
        final tb = TopTBNarrow(intf, computeRemainder: computeRemainder);
        await tb.divider.build();

        Simulator.setMaxSimTime(300000);

        final test = MultiCycleDividerTest(tb.divider, intf,
            computeRemainder: computeRemainder,
            sequences: [
              MultiCycleDividerCornerSequence(dataWidth: TopTBNarrow.width)
            ]);

        await test.start();
      }, timeout: const Timeout(Duration(minutes: 1)));
    });
  }

  for (final computeRemainder in [true, false]) {
    final label = computeRemainder ? 'with remainder' : 'quotient-only';

    group('1\'s C. Divider Tests ($label)', () {
      test('VF tests', () async {
        Logger.root.level = Level.SEVERE;

        final intf = MultiCycleDividerInterface(dataWidth: TopTB.width);
        final tb = TopTBOnesComp(intf, computeRemainder: computeRemainder);
        await tb.divider.build();

        Simulator.setMaxSimTime(200000);

        final test = OnesComplementTest(tb.divider, intf,
            computeRemainder: computeRemainder,
            sequences: [
              OnesCompBasicSequence(dataWidth: TopTB.width),
              OnesCompEvilSequence(dataWidth: TopTB.width),
              OnesCompVolumeSequence(1000, dataWidth: TopTB.width),
            ]);
        await test.start();
      });

      test('Factory method build', () async {
        final clk = Logic(name: 'clk');
        final reset = Logic(name: 'reset');
        final validIn = Logic(name: 'validIn');
        final dividend = Logic(name: 'dividend', width: TopTB.width);
        final divisor = Logic(name: 'divisor', width: TopTB.width);
        final isSigned = Logic(name: 'isSigned');
        final readyOut = Logic(name: 'readyOut');
        final div = OnesComplementDivider.ofLogics(
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
        Logic(name: 'tQuotient', width: TopTB.width).gets(div.quotient);
        Logic(name: 'tRemainder', width: TopTB.width).gets(div.remainder);
        Logic(name: 'tDivZero').gets(div.divZero);
        Logic(name: 'tReadyIn').gets(div.readyIn);
      });
    });

    group('1\'s C. Divider Corner Cases ${TopTBOnesComp.width}-bit ($label)',
        () {
      test('targeted structural corners', () async {
        Logger.root.level = Level.SEVERE;

        final intf = MultiCycleDividerInterface(dataWidth: TopTBOnesComp.width);
        final tb = TopTBOnesComp(intf, computeRemainder: computeRemainder);
        await tb.divider.build();

        Simulator.setMaxSimTime(300000);

        final test = OnesComplementTest(tb.divider, intf,
            computeRemainder: computeRemainder,
            sequences: [
              OnesCompSignedCornerSequence(dataWidth: TopTBOnesComp.width),
            ]);
        await test.start();
      }, timeout: const Timeout(Duration(minutes: 1)));
    });
  }
}
