// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fifo.dart
// Implementation of FIFOs.
//
// 2023 March 13
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A module [Fifo] implementing a simple FIFO (First In, First Out) buffer.
///
/// Supports a bypass if [Fifo] is empty and written & read at the same time.
class Fifo<LogicType extends Logic> extends Module {
  /// High if the entire FIFO is full and it cannot accept any more new items.
  Logic get full => output('full');

  /// High if there is nothing in [Fifo].
  Logic get empty => output('empty');

  /// Read data for the next item in [Fifo]
  ///
  /// This data is visible even when not actively removing from [Fifo].
  late final LogicType readData;

  /// High if an error condition is reached.
  ///
  /// There is no guarantee that it will hold high once asserted.
  /// Behavior upon error is undefined.
  ///
  /// If [generateError] is `false`, this output will not exist.
  Logic? get error => generateError ? output('error') : null;

  /// The number of items in [Fifo].
  ///
  /// If [generateOccupancy] is `false`, this output will not exist.
  Logic? get occupancy => generateOccupancy ? output('occupancy') : null;

  /// The depth of [Fifo].
  ///
  /// Must be greater than 0.
  final int depth;

  /// If `true`, then the [occupancy] output will be generated.
  final bool generateOccupancy;

  /// If `true`, then the [error] output will be generated.
  final bool generateError;

  /// If `true`, then it is possible to bypass through [Fifo] by writing
  /// and reading at the same time while [empty].
  final bool generateBypass;

  /// Push signal.
  Logic get _writeEnable => input('writeEnable');

  /// Pop signal.
  Logic get _readEnable => input('readEnable');

  /// Clock.
  Logic get _clk => input('clk');

  /// Reset.
  Logic get _reset => input('reset');

  /// Write data.
  Logic get _writeData => input('writeData');

  /// The width of the data transmitted through this [Fifo].
  final int dataWidth;

  /// The address width for elements in the storage of this [Fifo].
  final int _addrWidth;

  /// The first initial values of the [Fifo], if any.
  late final List<Logic> _initialValues;

  /// Constructs a [Fifo] with [RegisterFile]-based storage.
  ///
  /// If [initialValues] is provided, the [Fifo] will contain those values after
  /// [reset]. The length of [initialValues] must fit in the [depth]. The values
  /// may be either [Logic]s or constants compatible with [LogicValue.of].
  Fifo(Logic clk, Logic reset,
      {required Logic writeEnable,
      required LogicType writeData,
      required Logic readEnable,
      required this.depth,
      this.generateError = false,
      this.generateOccupancy = false,
      this.generateBypass = false,
      super.name = 'fifo',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName,
      List<dynamic>? initialValues})
      : dataWidth = writeData.width,
        _addrWidth = max(1, log2Ceil(depth)),
        super(
            definitionName:
                definitionName ?? 'Fifo_D${depth}_W${writeData.width}') {
    if (depth <= 0) {
      throw RohdHclException('Depth must be at least 1.');
    }
    if (_addrWidth <= 0) {
      throw RohdHclException(
          'Assumption that address width is non-zero in implementation');
    }

    addInput('clk', clk);
    addInput('reset', reset);

    // set up read/write ports
    addInput('writeEnable', writeEnable);
    addTypedInput('writeData', writeData);
    addInput('readEnable', readEnable);
    readData = addTypedOutput(
        'readData', writeData.clone as LogicType Function({String? name}));

    // set up info ports
    addOutput('full');
    addOutput('empty');

    if (generateError) {
      addOutput('error');
    }

    if (generateOccupancy) {
      addOutput('occupancy', width: log2Ceil(depth + 1));
    }

    if (initialValues == null) {
      _initialValues = [];
    } else {
      if (initialValues.length > depth) {
        throw RohdHclException('Initial values length (${initialValues.length})'
            ' exceeds depth ($depth)');
      }

      _initialValues = initialValues
          .mapIndexed((i, e) => e is Logic
              ? addTypedInput('initialValue_$i', e)
              : Const(e, width: dataWidth))
          .toList();

      if (_initialValues.any((e) => e.width != dataWidth)) {
        throw RohdHclException('All initial values must have width of'
            ' $dataWidth, but found:'
            ' ${_initialValues.map((e) => e.width).toList()}');
      }
    }

    _buildLogic();
  }

  /// Builds all the logic for [Fifo].
  void _buildLogic() {
    // set up the RF storage
    final wrPort = DataPortInterface(dataWidth, _addrWidth);
    final rdPort = DataPortInterface(dataWidth, _addrWidth);
    RegisterFile(
      _clk,
      _reset,
      [wrPort],
      [rdPort],
      numEntries: depth,
      resetValue: List.generate(
          depth,
          (i) => i < _initialValues.length
              ? _initialValues[i]
              : Const(0, width: dataWidth)), // fill rest with 0s
    );

    final wrPointer = Logic(name: 'wrPointer', width: _addrWidth);
    final rdPointer = Logic(name: 'rdPointer', width: _addrWidth);

    // empty calculation
    final matchedPointers = Logic(name: 'matchedPointers');
    matchedPointers <= wrPointer.eq(rdPointer);
    empty <= matchedPointers & ~full;

    // error calculation
    if (generateError) {
      final overflow = full & _writeEnable & ~_readEnable;

      var underflow = empty & _readEnable;
      if (generateBypass) {
        underflow &= ~_writeEnable;
      }

      error! <= underflow | overflow;
    }

    // occupancy calculation
    if (generateOccupancy) {
      Sequential(_clk, reset: _reset, resetValues: {
        occupancy!: _initialValues.length,
      }, [
        Case(
            conditionalType: ConditionalType.unique,
            [_writeEnable, _readEnable].swizzle(),
            [
              // write, no read
              CaseItem(Const(LogicValue.ofString('10')),
                  [occupancy! < occupancy! + 1]),

              // read, no write
              CaseItem(Const(LogicValue.ofString('01')),
                  [occupancy! < occupancy! - 1]),
            ],
            defaultItem: [
              occupancy! < occupancy
            ])
      ]);
    }

    // bypass means don't write to [Fifo], feed straight through
    Logic? bypass;
    if (generateBypass) {
      bypass = Logic(name: 'bypass');
      bypass <= empty & _readEnable & _writeEnable;
      wrPort.en <= _writeEnable & ~bypass;
    } else {
      wrPort.en <= _writeEnable;
    }

    wrPort.addr <= wrPointer;
    wrPort.data <= _writeData;

    // we can read from [Fifo] at all times to allow peeking,
    // including a new write if it's empty
    final peekWriteData = Logic(name: 'peekWriteData')
      ..gets(empty & _writeEnable);

    rdPort.en <= Const(1);
    rdPort.addr <= rdPointer;
    readData <=
        (generateBypass
            ? mux(peekWriteData, _writeData, rdPort.data)
            : rdPort.data);

    final pointerIncrements = [
      wrPointer < _incrWithWrap(wrPointer, _writeEnable),
      rdPointer < _incrWithWrap(rdPointer, _readEnable),
    ];

    Sequential(_clk, reset: _reset, resetValues: {
      full: _initialValues.length == depth ? Const(1) : Const(0),
      wrPointer: Const(_initialValues.length, width: _addrWidth),
    }, [
      if (generateBypass)
        If(~bypass!, then: pointerIncrements)
      else
        ...pointerIncrements,

      // full condition is one of these options:
      //  - we were already full, and pointers are staying the same.
      //  - [wrPointer] is 1 behind read, and we're writing without reading
      //    otherwise, [_readdEnable] has progressed or we're in undefined error
      //    territory.
      full <
          (full & (_writeEnable.eq(_readEnable))) |
              (rdPointer.eq(_incrWithWrap(wrPointer)) &
                  _writeEnable &
                  ~_readEnable)
    ]);
  }

  /// Increments [original] by 1, but wraps accounting for [depth].
  ///
  /// Optionally, the increment can be conditional on [condition].
  Logic _incrWithWrap(Logic original, [Logic? condition]) {
    final maxValue = depth - 1;
    final wrapped = mux(
        original.eq(maxValue), Const(0, width: original.width), original + 1);
    return condition != null ? mux(condition, wrapped, original) : wrapped;
  }
}

/// A checker for [Fifo]s that they are being used properly and not reaching any
/// dangerous conditions.
///
/// This is not intended to check that the [Fifo] is *functioning* properly, but
/// rather that it hasn't been used in an innpropriate way.  For example:
/// - No error condition hit (underflow/overflow)
/// - Empty at the end of the test
class FifoChecker extends Component {
  /// The [Fifo] being checked.
  final Fifo fifo;

  /// If `true`, will check that [fifo] is empty at the end of the test.
  final bool enableEndOfTestEmptyCheck;

  /// If `true`, will flag an error if there is an underflow in the [fifo].
  final bool enableUnderflowCheck;

  /// If `true`, will flag an error if there is an overflow in the [fifo].
  final bool enableOverflowCheck;

  /// If `true`, will flag an error if the [fifo]'s error signal is asserted, if
  /// it is present.
  final bool enableErrorCheck;

  /// Builds a checker for a [fifo].
  ///
  /// Attaches to the top level [Test.instance] if no parent is provided.
  FifoChecker(
    this.fifo, {
    String name = 'fifoChecker',
    Component? parent,
    this.enableEndOfTestEmptyCheck = true,
    this.enableUnderflowCheck = true,
    this.enableOverflowCheck = true,
    this.enableErrorCheck = true,
  }) : super(name, parent ?? Test.instance) {
    var hasReset = false;

    final fifoPortSignals = [...fifo.inputs.values, ...fifo.outputs.values]
        // data can be invalid since it's not control
        .where((e) => !e.name.contains('Data'));

    fifo._clk.posedge.listen((event) {
      if (!fifo._reset.previousValue!.isValid) {
        // reset is invalid, bad state.
        hasReset = false;
        return;
      } else if (fifo._reset.previousValue!.toBool()) {
        // reset is high, track that and move on.
        hasReset = true;
        return;
      } else if (hasReset) {
        // reset is low, and we've previously reset, should be good to check.
        if (!fifoPortSignals
            .map((e) => e.previousValue!.isValid)
            .reduce((a, b) => a && b)) {
          final portValuesMap = Map.fromEntries(
              fifoPortSignals.map((e) => MapEntry(e.name, e.previousValue!)));
          logger.severe('Fifo control port has an invalid value after reset.'
              ' Port values: $portValuesMap');
          return;
        }

        if (fifo.full.previousValue!.toBool() &&
            fifo._writeEnable.previousValue!.toBool() &&
            !fifo._readEnable.previousValue!.toBool()) {
          if (enableOverflowCheck) {
            logger
                .severe('Fifo $fifo received a write that caused an overflow.');
          }
        } else if (fifo.empty.previousValue!.toBool() &&
            fifo._readEnable.previousValue!.toBool()) {
          if (!(fifo.generateBypass &&
              fifo._writeEnable.previousValue!.toBool())) {
            if (enableUnderflowCheck) {
              logger.severe(
                  'Fifo $fifo received a read that caused an underflow.');
            }
          }
        }
      }

      if (fifo.generateError && enableErrorCheck) {
        if (fifo.error!.previousValue!.toBool()) {
          logger.severe('Fifo $fifo error signal was asserted.');
        }
      }
    });
  }

  @override
  void check() {
    if (enableEndOfTestEmptyCheck) {
      if (!fifo.empty.value.isValid) {
        logger.severe('Fifo empty signal has invalid value at end of test.');
      } else if (!fifo.empty.value.toBool()) {
        logger.severe('Fifo $fifo is not empty at the end of the test.');
      }
    }
  }
}

/// A tracker for a [Fifo] which can generate logs.
class FifoTracker extends Tracker {
  /// Internal tracking of occupancy in case the [Fifo] didn't generate it.
  int _occupancy = 0;

  /// Constructs a new tracker for [fifo].
  ///
  /// If no [name] is provided, will be named based on the [fifo]'s name.
  FifoTracker(
    Fifo fifo, {
    String? name,
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    super.spacer,
    super.separator,
    super.overflow,
  }) : super(name ?? fifo.name, [
          const TrackerField('Time', columnWidth: 8),
          const TrackerField('Command', columnWidth: 2),
          TrackerField('Data',
              columnWidth: fifo.dataWidth ~/ 4 + log2Ceil(fifo.dataWidth) + 1),
          TrackerField('Occupancy', columnWidth: fifo.depth ~/ 10 + 1),
        ]) {
    fifo._clk.posedge.listen((event) {
      if (fifo._writeEnable.previousValue!.toBool()) {
        record(_FifoEvent(
          _FifoCmd.wr,
          fifo._writeData.previousValue!,
          ++_occupancy,
        ));
      }

      if (fifo._readEnable.previousValue!.toBool()) {
        record(_FifoEvent(
          _FifoCmd.rd,
          fifo.readData.previousValue!,
          --_occupancy,
        ));
      }
    });
  }
}

enum _FifoCmd { wr, rd }

class _FifoEvent implements Trackable {
  final int time;
  final _FifoCmd cmd;
  final LogicValue data;
  final int? occupancy;

  _FifoEvent(this.cmd, this.data, this.occupancy) : time = Simulator.time;

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case 'Time':
        return time.toString();
      case 'Command':
        return cmd.name.toUpperCase();
      case 'Data':
        return data.toString();
      case 'Occupancy':
        return occupancy?.toString();
    }
    return null;
  }
}
