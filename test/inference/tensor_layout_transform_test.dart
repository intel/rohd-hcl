// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_layout_transform_test.dart
// Tests for Tensor Layout Transform.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:test/test.dart';

import '../systemc_test_utils.dart';
import '../verilator_test_utils.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('tiler names are bounded and distinguish complete payload schemas',
      () async {
    TensorTileTiler<Logic, LogicValue> create(
        {required bool unpacked, required bool signed, String name = 'tile'}) {
      final format = InferenceNumericFormat.fixedPoint(
        signed: signed,
        integerWidth: signed ? 5 : 6,
        fractionWidth: 2,
      );
      final tile = InferenceTensorTile<Logic, LogicValue>(
        rowCount: 2,
        columnCount: 3,
        elementBuilder: ({name}) => Logic(name: name, width: 8),
        format: format,
        numUnpackedDimensions: unpacked ? 2 : 0,
        name: name,
      );
      return TensorTileTiler(
        clk: Logic(),
        reset: Logic(),
        write: Logic(),
        element: Frame(InferenceTensorStreamElement(
          Logic(name: 'sample', width: 8),
          rowCount: 2,
          columnCount: 3,
        )),
        tileSchema: tile,
      );
    }

    final first = create(unpacked: false, signed: true, name: 'first');
    final renamed = create(unpacked: false, signed: true, name: 'renamed');
    final unpacked = create(unpacked: true, signed: true);
    final unsigned = create(unpacked: false, signed: false);
    expect(first.definitionName, renamed.definitionName);
    expect(first.definitionName, contains('R2_C3_QS_I5_F2_U0_Typed'));
    expect(unpacked.definitionName, contains('_U2_Typed'));
    expect(unsigned.definitionName, contains('QU_I6_F2'));
    expect(first.definitionName, isNot(contains('_H')));
    expect(
      {first.definitionName, unpacked.definitionName, unsigned.definitionName},
      hasLength(3),
    );
    for (final module in [first, renamed, unpacked, unsigned]) {
      expect(module.definitionName.length, lessThanOrEqualTo(80));
      expect(module.definitionName, matches(r'^[A-Za-z_][A-Za-z0-9_]*$'));
      await module.build();
      SimCompare.checkIverilogVector(module, const [], buildOnly: true);
    }
  });

  test('readable schemas hash only beyond the name-length boundary', () {
    LogicStructure schema(int nameLength) => LogicStructure([
          Logic(name: 'a' * nameLength, width: 8),
        ]);
    final short = compactPayloadShapesIdentity([schema(70)]);
    expect(short.length, 80);
    expect(short, startsWith('S1_N70_'));
    final long = compactPayloadShapesIdentity([schema(71)]);
    expect(long, matches(r'^H[0-9a-f]{64}$'));
    expect(compactPayloadShapesIdentity([Logic(width: 8)]), 'L8');
    expect(
      schemaQualifiedDefinitionName('Module_', [schema(70)]),
      matches(r'^Module_H[0-9a-f]{64}$'),
    );
    final different = compactPayloadShapesIdentity([
      LogicStructure([Logic(name: 'a' * 70 + 'b', width: 8)]),
    ]);
    expect(different, isNot(long));
    expect(compactPayloadShapesIdentity([schema(71)]), long);
  });

  test('custom tensor field names and numeric policies retain distinct names',
      () {
    TensorTileTiler<Logic, LogicValue> create(
        {String dataName = 'sample', int accumulatorWidth = 16, int rows = 2}) {
      final tile = inferenceLogicTensorTile(
        rowCount: rows,
        columnCount: 3,
        format: InferenceNumericFormat.signedInteger(
          8,
          accumulatorWidth: accumulatorWidth,
        ),
      );
      return TensorTileTiler(
        clk: Logic(),
        reset: Logic(),
        write: Logic(),
        element: Frame(InferenceTensorStreamElement(
          Logic(name: dataName, width: 8),
          rowCount: rows,
          columnCount: 3,
        )),
        tileSchema: tile,
      );
    }

    final ordinary = create();
    expect(ordinary.definitionName, contains('R2_C3_S8_U0_N6_sample'));
    expect(ordinary.definitionName, isNot(contains('_H')));
    expect(create(rows: 4).definitionName, contains('R4_C3'));
    final custom = create(dataName: 'custom' * 30);
    expect(custom.definitionName, matches(r'^TensorTileTiler_H[0-9a-f]{64}$'));
    expect(create(accumulatorWidth: 24).definitionName, contains('_A24'));
    expect(create(dataName: 'other').definitionName,
        isNot(ordinary.definitionName));
  });

  test('transposes typed tile data and exchanges runtime masks', () async {
    final input = _tile(rows: 2, columns: 3, name: 'inputTile');
    final dut = TensorTileTranspose<Logic, LogicValue>(input);
    await dut.build();
    unawaited(Simulator.run());

    _driveTile(input, [1, 2, 3, 4, 5, 6], rowMask: 0x1, columnMask: 0x5);
    await Simulator.tick();
    expect(_tileValues(dut.result), [1, 4, 2, 5, 3, 6]);
    expect(dut.result.rowCount, 3);
    expect(dut.result.columnCount, 2);
    expect(dut.result.rowMask.value.toInt(), 0x5);
    expect(dut.result.columnMask.value.toInt(), 0x1);
    await Simulator.endSimulation();
  });

  for (final (rows, columns) in [(1, 1), (1, 4), (4, 1), (3, 2)]) {
    test('transpose $rows x $columns is invertible with empty runtime masks',
        () async {
      final input = _tile(rows: rows, columns: columns, name: 'spatialInput');
      final transpose = TensorTileTranspose(input);
      final inverse = TensorTileTranspose(transpose.result);
      await inverse.build();
      unawaited(Simulator.run());
      final values = List.generate(rows * columns, (index) => index + 1);
      _driveTile(input, values, rowMask: 0, columnMask: (1 << columns) - 1);
      await Simulator.tick();
      expect(_tileValues(transpose.result), [
        for (var column = 0; column < columns; column++)
          for (var row = 0; row < rows; row++) values[row * columns + column],
      ]);
      expect(_tileValues(inverse.result), values);
      expect(inverse.result.rowMask.value.toInt(), 0);
      expect(inverse.result.columnMask.value.toInt(), (1 << columns) - 1);
      input.rowMask.inject((1 << rows) - 1);
      input.columnMask.inject(0);
      await Simulator.tick();
      expect(_tileValues(inverse.result), values);
      expect(inverse.result.rowMask.value.toInt(), (1 << rows) - 1);
      expect(inverse.result.columnMask.value.toInt(), 0);
      await Simulator.endSimulation();
    });
  }

  test('spatial transpose preserves structured unpacked elements and X/Z',
      () async {
    final input = InferenceTensorTile<LogicStructure, LogicValue>(
      rowCount: 1,
      columnCount: 3,
      elementBuilder: ({name}) => LogicStructure([
        Logic(name: 'low', width: 4),
        Logic(name: 'high', width: 4),
      ], name: name),
      format: InferenceNumericFormat.unsignedInteger(8),
      numUnpackedDimensions: 2,
    );
    final dut = TensorTileTranspose(input);
    await dut.build();
    unawaited(Simulator.run());
    input.data.arrayElements[0].inject(LogicValue.filled(8, LogicValue.x));
    input.data.arrayElements[1].inject(LogicValue.filled(8, LogicValue.z));
    input.data.arrayElements[2].inject(0xa5);
    input.rowMask.inject(LogicValue.z);
    input.columnMask.inject(LogicValue.ofString('1x0'));
    await Simulator.tick();
    expect(dut.result.data.dimensions, [3, 1]);
    expect(dut.result.data.numUnpackedDimensions, 2);
    expect(dut.result.data.valueCodec, same(input.data.valueCodec));
    expect(dut.result.data.value.arrayValues, [
      LogicValue.filled(8, LogicValue.x),
      LogicValue.filled(8, LogicValue.z),
      LogicValue.ofInt(0xa5, 8),
    ]);
    expect(dut.result.data.arrayElements[2].elements[0].value.toInt(), 5);
    expect(dut.result.data.arrayElements[2].elements[1].value.toInt(), 10);
    expect(dut.result.rowMask.value, LogicValue.ofString('1x0'));
    expect(dut.result.columnMask.value, LogicValue.z);
    await Simulator.endSimulation();
  });

  for (final capacity in [1, 4]) {
    test('tiler capacity $capacity diagnoses markers and recovers next frame',
        () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final write = Logic();
      final rows = capacity == 1 ? 1 : 2;
      final columns = capacity == 1 ? 1 : 2;
      final element = Frame(InferenceTensorStreamElement(
        Logic(name: 'framedSample', width: 8),
        rowCount: rows,
        columnCount: columns,
      ));
      final dut = TensorTileTiler(
        clk: clk,
        reset: reset,
        element: element,
        write: write,
        tileSchema: _tile(rows: rows, columns: columns, name: 'framedOutput'),
      );
      await dut.build();
      unawaited(Simulator.run());
      reset.inject(1);
      write.inject(0);
      element.inject(0);
      await clk.nextPosedge;
      await clk.nextNegedge;
      reset.inject(0);

      Future<void> beat(int data,
          {required bool last, int columnActive = 1}) async {
        element.data.data.inject(data);
        element.data.rowActive.inject(1);
        element.data.columnActive.inject(columnActive);
        element.last.inject(last ? 1 : 0);
        write.inject(1);
        await clk.nextPosedge;
        await clk.nextNegedge;
        write.inject(0);
      }

      for (var index = 0; index < capacity; index++) {
        await beat(index + 1, last: false);
      }
      expect(dut.complete.value, LogicValue.one);
      expect(dut.collectedElements.value.toInt(), capacity);
      expect(dut.framingError.value, LogicValue.one);
      expect(dut.result.rowMask.value.toInt(), 0);
      expect(dut.result.columnMask.value.toInt(), 0);
      if (capacity > 1) {
        await beat(99, last: true);
        expect(dut.complete.value, LogicValue.one);
        expect(dut.collectedElements.value.toInt(), 1);
        expect(dut.framingError.value, LogicValue.one);
      }
      for (var index = 0; index < capacity; index++) {
        await beat(index + 21, last: index == capacity - 1);
        expect(dut.complete.value.toInt(), index == capacity - 1 ? 1 : 0);
      }
      expect(_tileValues(dut.result),
          List.generate(capacity, (index) => index + 21));
      expect(dut.collectedElements.value.toInt(), capacity);
      expect(dut.framingError.value, LogicValue.zero);
      expect(dut.maskInconsistent.value, LogicValue.zero);
      expect(dut.result.rowMask.value.toInt(), (1 << rows) - 1);
      expect(dut.result.columnMask.value.toInt(), (1 << columns) - 1);
      if (capacity > 1) {
        for (var index = 0; index < capacity; index++) {
          await beat(index + 1,
              last: index == capacity - 1, columnActive: index == 2 ? 0 : 1);
        }
        expect(dut.complete.value, LogicValue.one);
        expect(dut.framingError.value, LogicValue.zero);
        expect(dut.maskInconsistent.value, LogicValue.one);
        expect(dut.result.rowMask.value.toInt(), 0);
        expect(dut.result.columnMask.value.toInt(), 0);
      }
      await Simulator.endSimulation();
    });
  }

  for (final (rows, columns) in [(1, 1), (2, 2), (2, 3)]) {
    test('strict $rows x $columns tiling has exact cadence and no bubbles',
        () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final load = Logic();
      final input = _tile(rows: rows, columns: columns, name: 'scheduledInput');
      final dut = _ScheduledTensorTileRoundTrip(
        clk: clk,
        reset: reset,
        load: load,
        input: input,
      );
      await dut.build();
      unawaited(Simulator.run());
      reset.inject(1);
      load.inject(0);
      input.inject(0);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextNegedge;
      final length = rows * columns;
      final first = List.generate(length, (index) => index + 1);
      final second = List.generate(length, (index) => index + 21);
      _driveTile(input, first, rowMask: 1, columnMask: 1);
      load.inject(1);
      await clk.nextPosedge;
      await clk.nextNegedge;
      load.inject(0);
      expect(dut.complete.value, LogicValue.zero);

      for (var packet = 0; packet < 2; packet++) {
        final values = packet == 0 ? first : second;
        for (var index = 0; index < length; index++) {
          expect(dut.active.value, LogicValue.one);
          expect(dut.index.value.toInt(), index);
          expect(dut.element.data.data.value.toInt(), values[index]);
          expect(dut.element.data.rowActive.value.toInt(),
              packet == 0 ? (index ~/ columns == 0 ? 1 : 0) : 1);
          expect(dut.element.data.columnActive.value.toInt(),
              packet == 0 ? (index % columns == 0 ? 1 : 0) : 1);
          expect(dut.element.last.value.toInt(), index == length - 1 ? 1 : 0);
          if (packet == 0 && index == length - 1) {
            _driveTile(input, second,
                rowMask: (1 << rows) - 1, columnMask: (1 << columns) - 1);
            load.inject(1);
          } else {
            load.inject(0);
          }
          await clk.nextPosedge;
          await clk.nextNegedge;
          expect(dut.complete.value.toInt(), index == length - 1 ? 1 : 0);
        }
        expect(_tileValues(dut.result), values);
        expect(dut.result.rowMask.value.toInt(),
            packet == 0 ? 1 : (1 << rows) - 1);
        expect(dut.result.columnMask.value.toInt(),
            packet == 0 ? 1 : (1 << columns) - 1);
        expect(dut.framingError.value, LogicValue.zero);
        expect(dut.maskInconsistent.value, LogicValue.zero);
      }
      expect(dut.active.value, LogicValue.zero);
      await clk.nextPosedge;
      await clk.nextNegedge;
      expect(dut.complete.value, LogicValue.zero);
      await Simulator.endSimulation();
    });
  }

  test('strict tiling reset discards an in-flight tile', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final load = Logic();
    final input = _tile(rows: 2, columns: 3, name: 'resetInput');
    final dut = _ScheduledTensorTileRoundTrip(
      clk: clk,
      reset: reset,
      load: load,
      input: input,
    );
    await dut.build();
    unawaited(Simulator.run());
    reset.inject(1);
    load.inject(0);
    input.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextNegedge;
    _driveTile(input, [1, 2, 3, 4, 5, 6], rowMask: 3, columnMask: 7);
    load.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    load.inject(0);
    for (var cycle = 0; cycle < 3; cycle++) {
      await clk.nextPosedge;
      await clk.nextNegedge;
      expect(dut.complete.value, LogicValue.zero);
    }
    reset.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    expect(dut.active.value, LogicValue.zero);
    expect(dut.complete.value, LogicValue.zero);
    reset.inject(0);
    _driveTile(input, [11, 12, 13, 14, 15, 16], rowMask: 1, columnMask: 5);
    load.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    load.inject(0);
    for (var cycle = 0; cycle < 6; cycle++) {
      await clk.nextPosedge;
      await clk.nextNegedge;
      expect(dut.complete.value.toInt(), cycle == 5 ? 1 : 0);
    }
    expect(_tileValues(dut.result), [11, 12, 13, 14, 15, 16]);
    expect(dut.result.rowMask.value.toInt(), 1);
    expect(dut.result.columnMask.value.toInt(), 5);
    expect(dut.framingError.value, LogicValue.zero);
    expect(dut.maskInconsistent.value, LogicValue.zero);
    await Simulator.endSimulation();
  });

  test('scheduled tensor round trip matches native backends', () async {
    final input = _tile(rows: 2, columns: 3, name: 'rtlInput');
    final dut = _ScheduledTensorTileRoundTrip(
      clk: Logic(),
      reset: Logic(),
      load: Logic(),
      input: input,
    );
    await dut.build();
    final vectors = <Vector>[];
    BigInt tileBits(List<int> values) {
      var bits = (BigInt.from(3) << 48) | (BigInt.from(5) << 50);
      for (var index = 0; index < values.length; index++) {
        bits |= BigInt.from(values[index]) << (index * 8);
      }
      return bits;
    }

    BigInt elementBits(int value, int index) => BigInt.from(value |
        (1 << 8) |
        ((index % 3 == 1 ? 0 : 1) << 9) |
        ((index == 5 ? 1 : 0) << 10));

    void cycle(int reset, int load, BigInt tile, Map<String, dynamic> outputs) {
      final inputs = {
        'clk': 0,
        'reset': reset,
        'load': load,
        'inputTile': tile,
      };
      vectors
        ..add(Vector(inputs, outputs))
        ..add(Vector({...inputs, 'clk': 1}, const {}));
    }

    final first = tileBits([1, 2, 3, 4, 5, 6]);
    final second = tileBits([21, 22, 23, 24, 25, 26]);
    cycle(1, 0, first, const {});
    cycle(0, 1, first, {'active': 0, 'complete': 0});
    for (var packet = 0; packet < 2; packet++) {
      for (var index = 0; index < 6; index++) {
        cycle(0, packet == 0 && index == 5 ? 1 : 0, second, {
          'active': 1,
          'index': index,
          'element': elementBits(packet * 20 + index + 1, index),
          'complete': packet == 1 && index == 0 ? 1 : 0,
          if (packet == 1 && index == 0) 'result': first,
        });
      }
    }
    cycle(0, 0, second, {
      'active': 0,
      'complete': 1,
      'result': second,
      'framingError': 0,
      'maskInconsistent': 0,
    });
    cycle(0, 0, second, {'active': 0, 'complete': 0});
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    if (canRunSystemC()) {
      SimCompare.checkSystemCVector(dut, vectors);
    }
    SimCompare.checkVerilatorVector(dut, vectors);
    expectNoVerilatorWarnings(dut, ['LATCH', 'UNOPTFLAT']);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test(
    'untiler emits row-major framed elements with repeated mask metadata',
    () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final upstream = ReadyValidInterface(
        _tile(rows: 2, columns: 3, name: 'untilerInput'),
      );
      final downstream = ReadyValidInterface(
        Frame(
          InferenceTensorStreamElement(
            Logic(name: 'elementData', width: 8),
            rowCount: 2,
            columnCount: 3,
          ),
        ),
      );
      final dut = ReadyValidTensorTileUntiler<Logic, LogicValue>(
        clk: clk,
        reset: reset,
        upstream: upstream,
        downstream: downstream,
      );
      await dut.build();
      unawaited(Simulator.run());
      reset.inject(1);
      upstream.valid.inject(0);
      upstream.data.inject(0);
      downstream.ready.inject(0);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextNegedge;

      _driveTile(
        upstream.data,
        [1, 2, 3, 4, 5, 6],
        rowMask: 0x1,
        columnMask: 0x5,
      );
      upstream.valid.inject(1);
      await _waitForHigh(clk, upstream.ready, 'untiler input ready');
      await clk.nextPosedge;
      await clk.nextNegedge;
      upstream.valid.inject(0);

      for (var index = 0; index < 6; index++) {
        await _waitForHigh(clk, downstream.valid, 'untiler element $index');
        expect(downstream.data.data.data.value.toInt(), index + 1);
        expect(
          downstream.data.data.rowActive.value.toInt(),
          index ~/ 3 == 0 ? 1 : 0,
        );
        expect(
          downstream.data.data.columnActive.value.toInt(),
          const [1, 0, 1][index % 3],
        );
        expect(
          downstream.data.last.value,
          index == 5 ? LogicValue.one : LogicValue.zero,
        );
        final retained = downstream.data.value;
        if (index == 1) {
          await clk.nextPosedge;
          await clk.nextNegedge;
          expect(downstream.data.value, retained);
        }
        downstream.ready.inject(1);
        await clk.nextPosedge;
        await clk.nextNegedge;
        downstream.ready.inject(0);
      }
      expect(dut.active.value, LogicValue.zero);
      await Simulator.endSimulation();
    },
  );

  test('tiler and untiler reject different same-width element schemas', () {
    final tile = ReadyValidInterface(
      InferenceTensorTile<Logic, LogicValue>(
        rowCount: 1,
        columnCount: 1,
        elementBuilder: ({name}) =>
            LogicStructure([Logic(name: 'sample', width: 8)], name: name),
        format: InferenceNumericFormat.unsignedInteger(8),
      ),
    );
    final stream = ReadyValidInterface(
      Frame(
        InferenceTensorStreamElement<Logic>(
          LogicStructure([
            Logic(name: 'high', width: 4),
            Logic(name: 'low', width: 4),
          ]),
          rowCount: 1,
          columnCount: 1,
        ),
      ),
    );
    expect(
      () => ReadyValidTensorTileUntiler(
        clk: Logic(),
        reset: Logic(),
        upstream: tile,
        downstream: stream,
      ),
      throwsArgumentError,
    );
    expect(
      () => ReadyValidTensorTileTiler(
        clk: Logic(),
        reset: Logic(),
        upstream: stream,
        downstream: tile,
      ),
      throwsArgumentError,
    );
    expect(
      () => TensorTileUntiler(
        clk: Logic(),
        reset: Logic(),
        inputTile: tile.data,
        elementSchema: stream.data.data,
        load: Logic(),
      ),
      throwsArgumentError,
    );
    expect(
      () => TensorTileTiler(
        clk: Logic(),
        reset: Logic(),
        element: stream.data,
        tileSchema: tile.data,
        write: Logic(),
      ),
      throwsArgumentError,
    );
  });

  test('ready/valid tiler retains completion and replaces a one-element tile',
      () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final upstream = ReadyValidInterface(
      Frame(InferenceTensorStreamElement(
        Logic(name: 'oneElement', width: 8),
        rowCount: 1,
        columnCount: 1,
      )),
    );
    final downstream = ReadyValidInterface(
      _tile(rows: 1, columns: 1, name: 'oneTile'),
    );
    final dut = ReadyValidTensorTileTiler(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstream: downstream,
    );
    await dut.build();
    unawaited(Simulator.run());
    reset.inject(1);
    upstream.valid.inject(0);
    upstream.data.inject(0);
    downstream.ready.inject(0);
    await clk.nextPosedge;
    await clk.nextNegedge;
    reset.inject(0);
    upstream.data.data.data.inject(7);
    upstream.data.data.rowActive.inject(1);
    upstream.data.data.columnActive.inject(1);
    upstream.data.last.inject(1);
    upstream.valid.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    expect(downstream.valid.value, LogicValue.one);
    final retained = downstream.data.value;
    upstream.data.data.data.inject(9);
    for (var cycle = 0; cycle < 3; cycle++) {
      expect(upstream.ready.value, LogicValue.zero);
      await clk.nextPosedge;
      await clk.nextNegedge;
      expect(downstream.valid.value, LogicValue.one);
      expect(downstream.data.value, retained);
    }
    downstream.ready.inject(1);
    await Simulator.tick();
    expect(upstream.ready.value, LogicValue.one);
    await clk.nextPosedge;
    await clk.nextNegedge;
    expect(downstream.valid.value, LogicValue.one);
    expect(_tileValues(downstream.data), [9]);
    expect(dut.collectedElements.value.toInt(), 1);
    expect(dut.framingError.value, LogicValue.zero);
    upstream.valid.inject(0);
    await clk.nextPosedge;
    await clk.nextNegedge;
    expect(downstream.valid.value, LogicValue.zero);
    await Simulator.endSimulation();
  });

  test(
    'tiler diagnoses malformed frame length and inconsistent masks',
    () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final upstream = ReadyValidInterface(
        Frame(
          InferenceTensorStreamElement(
            Logic(name: 'elementData', width: 8),
            rowCount: 2,
            columnCount: 3,
          ),
        ),
      );
      final downstream = ReadyValidInterface(
        _tile(rows: 2, columns: 3, name: 'tilerOutput'),
      );
      final dut = ReadyValidTensorTileTiler<Logic, LogicValue>(
        clk: clk,
        reset: reset,
        upstream: upstream,
        downstream: downstream,
      );
      await dut.build();
      unawaited(Simulator.run());
      reset.inject(1);
      upstream.valid.inject(0);
      upstream.data.inject(0);
      downstream.ready.inject(0);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextNegedge;

      for (var index = 0; index < 6; index++) {
        await _sendElement(
          clk,
          upstream,
          data: index + 1,
          rowActive: index == 4 ? 0 : 1,
          columnActive: 1,
          last: index == 5,
        );
      }
      await _waitForHigh(clk, downstream.valid, 'inconsistent tile');
      expect(dut.framingError.value, LogicValue.zero);
      expect(dut.maskInconsistent.value, LogicValue.one);
      expect(dut.collectedElements.value.toInt(), 6);
      expect(downstream.data.rowMask.value.toInt(), 0);
      expect(downstream.data.columnMask.value.toInt(), 0);
      final retained = downstream.data.value;
      for (var cycle = 0; cycle < 3; cycle++) {
        await clk.nextPosedge;
        await clk.nextNegedge;
        expect(downstream.valid.value, LogicValue.one);
        expect(downstream.data.value, retained);
        expect(dut.framingError.value, LogicValue.zero);
        expect(dut.maskInconsistent.value, LogicValue.one);
        expect(dut.collectedElements.value.toInt(), 6);
      }
      downstream.ready.inject(1);
      await clk.nextPosedge;
      await clk.nextNegedge;
      downstream.ready.inject(0);

      for (var index = 0; index < 3; index++) {
        await _sendElement(
          clk,
          upstream,
          data: index + 7,
          rowActive: 1,
          columnActive: 1,
          last: index == 2,
        );
      }
      await _waitForHigh(clk, downstream.valid, 'short tile');
      expect(dut.framingError.value, LogicValue.one);
      expect(dut.maskInconsistent.value, LogicValue.zero);
      expect(dut.collectedElements.value.toInt(), 3);
      expect(downstream.data.rowMask.value.toInt(), 0);
      expect(downstream.data.columnMask.value.toInt(), 0);
      await Simulator.endSimulation();
    },
  );

  test(
    'untiler and tiler round-trip a masked tile through a framed stream',
    () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final upstream = ReadyValidInterface(
        _tile(rows: 2, columns: 3, name: 'roundTripInput'),
      );
      final downstream = ReadyValidInterface(
        _tile(rows: 2, columns: 3, name: 'roundTripOutput'),
      );
      final dut = _TensorTileRoundTrip(
        clk: clk,
        reset: reset,
        upstream: upstream,
        downstream: downstream,
      );
      await dut.build();
      unawaited(Simulator.run());
      reset.inject(1);
      upstream.valid.inject(0);
      upstream.data.inject(0);
      downstream.ready.inject(0);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextNegedge;

      _driveTile(
        upstream.data,
        [0x10, 0x11, 0x12, 0x20, 0x21, 0x22],
        rowMask: 0x3,
        columnMask: 0x3,
      );
      upstream.valid.inject(1);
      await _waitForHigh(clk, upstream.ready, 'round-trip input ready');
      await clk.nextPosedge;
      await clk.nextNegedge;
      upstream.valid.inject(0);
      await _waitForHigh(clk, downstream.valid, 'round-trip output');
      expect(_tileValues(downstream.data), [
        0x10,
        0x11,
        0x12,
        0x20,
        0x21,
        0x22,
      ]);
      expect(downstream.data.rowMask.value.toInt(), 0x3);
      expect(downstream.data.columnMask.value.toInt(), 0x3);
      expect(dut.framingError.value, LogicValue.zero);
      expect(dut.maskInconsistent.value, LogicValue.zero);
      await Simulator.endSimulation();
    },
  );
}

class _ScheduledTensorTileRoundTrip extends Module {
  late final InferenceTensorTile<Logic, LogicValue> result;
  late final Frame<InferenceTensorStreamElement<Logic>> element;

  Logic get active => output('active');
  Logic get index => output('index');
  Logic get complete => output('complete');
  Logic get framingError => output('framingError');
  Logic get maskInconsistent => output('maskInconsistent');

  _ScheduledTensorTileRoundTrip({
    required Logic clk,
    required Logic reset,
    required Logic load,
    required InferenceTensorTile<Logic, LogicValue> input,
  }) : super(
            definitionName: 'ScheduledTensorTileRoundTrip_'
                'R${input.rowCount}_C${input.columnCount}') {
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localLoad = addInput('load', load);
    final localInput = addTypedInput<InferenceTensorTile<Logic, LogicValue>>(
        'inputTile', input);
    final untiler = TensorTileUntiler(
      clk: localClk,
      reset: localReset,
      load: localLoad,
      inputTile: localInput,
      elementSchema: InferenceTensorStreamElement(
        Logic(name: 'sample', width: input.format.elementWidth),
        rowCount: input.rowCount,
        columnCount: input.columnCount,
      ),
    );
    final tiler = TensorTileTiler(
      clk: localClk,
      reset: localReset,
      element: untiler.result,
      write: untiler.active,
      tileSchema: localInput,
    );
    result = addTypedOutput('result', tiler.result.clone);
    result <= tiler.result;
    element = addTypedOutput('element', untiler.result.clone);
    element <= untiler.result;
    addOutput('active') <= untiler.active;
    addOutput('index', width: untiler.index.width) <= untiler.index;
    addOutput('complete') <= tiler.complete;
    addOutput('framingError') <= tiler.framingError;
    addOutput('maskInconsistent') <= tiler.maskInconsistent;
  }
}

class _TensorTileRoundTrip extends Module {
  Logic get framingError => output('framingError');

  Logic get maskInconsistent => output('maskInconsistent');

  _TensorTileRoundTrip({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<InferenceTensorTile<Logic, LogicValue>>
        upstream,
    required ReadyValidInterface<InferenceTensorTile<Logic, LogicValue>>
        downstream,
  }) : super(definitionName: 'TensorTileRoundTrip') {
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localUpstream = addPairInterface(
      upstream,
      PairRole.consumer,
      uniquify: (original) => 'upstream_$original',
    );
    final localDownstream = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(downstream.data.clone()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );
    final stream = ReadyValidInterface(
      Frame(
        InferenceTensorStreamElement(
          Logic(name: 'streamData', width: upstream.data.format.elementWidth),
          rowCount: upstream.data.rowCount,
          columnCount: upstream.data.columnCount,
        ),
      ),
    );
    ReadyValidTensorTileUntiler<Logic, LogicValue>(
      clk: localClk,
      reset: localReset,
      upstream: localUpstream,
      downstream: stream,
      name: 'untiler',
    );
    final tiler = ReadyValidTensorTileTiler<Logic, LogicValue>(
      clk: localClk,
      reset: localReset,
      upstream: stream,
      downstream: localDownstream,
      name: 'tiler',
    );
    addOutput('framingError') <= tiler.framingError;
    addOutput('maskInconsistent') <= tiler.maskInconsistent;
  }
}

InferenceTensorTile<Logic, LogicValue> _tile({
  required int rows,
  required int columns,
  required String name,
}) =>
    inferenceLogicTensorTile(
      rowCount: rows,
      columnCount: columns,
      format: InferenceNumericFormat.unsignedInteger(8),
      name: name,
    );

void _driveTile(
  InferenceTensorTile<Logic, LogicValue> tile,
  List<int> values, {
  required int rowMask,
  required int columnMask,
}) {
  for (var index = 0; index < values.length; index++) {
    tile.data.arrayElements[index].inject(values[index]);
  }
  tile.rowMask.inject(rowMask);
  tile.columnMask.inject(columnMask);
}

List<int> _tileValues(InferenceTensorTile<Logic, LogicValue> tile) => [
      for (final element in tile.data.value.arrayValues) element.toInt(),
    ];

Future<void> _sendElement(
  Logic clk,
  ReadyValidInterface<Frame<InferenceTensorStreamElement<Logic>>> upstream, {
  required int data,
  required int rowActive,
  required int columnActive,
  required bool last,
}) async {
  upstream.data.data.data.inject(data);
  upstream.data.data.rowActive.inject(rowActive);
  upstream.data.data.columnActive.inject(columnActive);
  upstream.data.last.inject(last ? 1 : 0);
  upstream.valid.inject(1);
  await _waitForHigh(clk, upstream.ready, 'tiler input ready');
  await clk.nextPosedge;
  await clk.nextNegedge;
  upstream.valid.inject(0);
}

Future<void> _waitForHigh(Logic clk, Logic signal, String description) async {
  for (var cycle = 0; cycle < 50; cycle++) {
    if (signal.value == LogicValue.one) {
      return;
    }
    await clk.nextNegedge;
  }
  fail('Timed out waiting for $description.');
}
