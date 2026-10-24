// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_modules_test.dart
// Tests for typed dataflow modules.
//
// 2026 October 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Record extends LogicStructure {
  Logic get key => elements[0];
  Logic get tag => elements[1];

  _Record({String? name})
      : super([Logic(name: 'key', width: 4), Logic(name: 'tag', width: 4)],
            name: name ?? 'record');

  @override
  _Record clone({String? name}) => _Record(name: name ?? this.name);
}

class _GrowingWord extends LogicStructure {
  Logic get data => elements[0];
  Logic get valid => elements[1];

  _GrowingWord(int width, {String? name})
      : super([Logic(name: 'data', width: width), Logic(name: 'valid')],
            name: name ?? 'growing_word');

  @override
  _GrowingWord clone({String? name}) =>
      _GrowingWord(data.width, name: name ?? this.name);
}

class _GrowingReduction extends Module {
  late final _GrowingWord result;
  bool sawDifferentWidths = false;

  _GrowingReduction({required bool inline, required bool pipeline}) {
    final data = [
      for (var i = 0; i < 9; i++)
        _GrowingWord(4)..gets(addInput('data$i', Logic(width: 5), width: 5))
    ];
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    _GrowingWord add(List<_GrowingWord> inputs,
        {int depth = 0, Logic? control, String name = 'add'}) {
      if (inputs.length == 1) {
        return inputs.single;
      }
      sawDifferentWidths |=
          inputs.any((value) => value.data.width != inputs.first.data.width);
      final width = inputs
              .map((value) => value.data.width)
              .reduce((a, b) => a > b ? a : b) +
          1;
      return _GrowingWord(width)
        ..data.gets(inputs
            .map((value) => value.data.zeroExtend(width))
            .reduce((a, b) => a + b))
        ..valid
            .gets(inputs.map((value) => value.valid).reduce((a, b) => a & b));
    }

    result = inline
        ? ReductionTreeGenerator(data, add,
                clk: pipeline ? clk : null,
                reset: reset,
                depthBetweenFlops: pipeline ? 1 : null)
            .out
        : ReductionTree(data, add,
                clk: pipeline ? clk : null,
                reset: reset,
                depthBetweenFlops: pipeline ? 1 : null)
            .out;
    addOutput('result', width: result.width) <= result;
  }
}

class _SortHarness<T extends Logic> extends Module {
  late final BitonicSort<T> sorter;

  _SortHarness(T schema,
      {Logic Function(T a, T b)? isLessThan, bool ascending = true}) {
    final data = [
      for (var i = 0; i < 4; i++)
        schema.cloneTyped(name: 'payload$i')
          ..gets(addInput('data$i', Logic(width: schema.width),
              width: schema.width))
    ];
    sorter = BitonicSort(addInput('clk', Logic()), addInput('reset', Logic()),
        toSort: data, isAscending: ascending, isLessThan: isLessThan);
    for (var i = 0; i < 4; i++) {
      addOutput('result$i', width: schema.width) <= sorter.sorted[i];
    }
  }
}

class _ReductionHarness<T extends Logic> extends Module {
  late final T result;
  late final _Record controlResult;
  late final int latency;

  _ReductionHarness(T schema, {required bool inline, required bool pipeline}) {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final enable = addInput('enable', Logic());
    final control = _Record()
      ..gets(addInput('control', Logic(width: 8), width: 8));
    final data = [
      for (var i = 0; i < 9; i++)
        schema.cloneTyped(name: 'payload$i')
          ..gets(addInput('data$i', Logic(width: schema.width),
              width: schema.width))
    ];
    T select(List<T> inputs,
            {int depth = 0, _Record? control, String name = 'select'}) =>
        inputs.length == 1
            ? inputs.single
            : mux<T>(control!.key[depth], inputs.last, inputs.first,
                outputGenerator: inputs.first.cloneTyped);
    if (inline) {
      final tree = ReductionTreeGenerator(data, select,
          control: control,
          clk: pipeline ? clk : null,
          reset: reset,
          enable: enable,
          depthBetweenFlops: pipeline ? 1 : null);
      result = tree.out;
      controlResult = tree.controlOut!;
      latency = tree.latency;
    } else {
      final tree = ReductionTree(data, select,
          control: control,
          clk: pipeline ? clk : null,
          reset: reset,
          enable: enable,
          depthBetweenFlops: pipeline ? 1 : null);
      result = tree.out;
      controlResult = tree.controlOut!;
      latency = tree.latency;
    }
    addOutput('result', width: schema.width) <= result;
    addOutput('controlResult', width: 8) <= controlResult;
  }
}

class _ToggleHarness<T extends Logic> extends Module {
  late final ToggleGate<T> gate;

  _ToggleHarness(T schema,
      {required bool clockGating, required bool liveReset}) {
    final data = schema.cloneTyped(name: 'payload')
      ..gets(addInput('data', Logic(width: schema.width), width: schema.width));
    final resetValue = schema.cloneTyped(name: 'resetPayload')
      ..gets(addInput('resetData', Logic(width: schema.width),
          width: schema.width));
    gate = ToggleGate(
        data: data,
        clk: addInput('clk', Logic()),
        reset: addInput('reset', Logic()),
        enable: addInput('enable', Logic()),
        resetValue: liveReset ? resetValue : 5,
        clockGateControlIntf:
            clockGating ? null : ClockGateControlInterface(isPresent: false));
    addOutput('result', width: schema.width) <= gate.gatedData;
  }
}

Future<void> _compare(Module dut, List<Vector> vectors,
    {bool systemC = false, bool verilator = false}) async {
  await SimCompare.checkFunctionalVector(dut, vectors);
  SimCompare.checkIverilogVector(dut, vectors);
  if (verilator) {
    SimCompare.checkVerilatorVector(dut, vectors);
  }
  if (systemC) {
    SimCompare.checkSystemCVector(dut, vectors);
  }
}

void _checkSort<T extends Logic>(String name, T schema,
    Logic Function(T a, T b) compare, List<int> data, List<int> expected,
    {bool systemC = false}) {
  for (final ascending in [true, false]) {
    test('$name sort preserves typed payloads, ascending=$ascending', () async {
      final dut =
          _SortHarness(schema, isLessThan: compare, ascending: ascending);
      await dut.build();
      expect(dut.sorter.latency, 3);
      for (final value in dut.sorter.sorted) {
        expect(value.runtimeType, schema.runtimeType);
      }
      expect(dut.sorter.input('toSort0').runtimeType, schema.runtimeType);
      final results = ascending ? expected : expected.reversed.toList();
      await _compare(
          dut,
          [
            Vector({
              'clk': 0,
              'reset': 0,
              for (var i = 0; i < 4; i++) 'data$i': data[i],
            }, {}),
            for (var cycle = 0; cycle < dut.sorter.latency; cycle++) ...[
              Vector({
                'clk': 1
              }, {
                if (cycle == dut.sorter.latency - 1)
                  for (var i = 0; i < 4; i++) 'result$i': results[i],
              }),
              Vector({'clk': 0}, {}),
            ],
          ],
          systemC: systemC);
    });
  }
}

void _checkStorage<T extends Logic>(String name, T schema,
    {bool systemC = false}) {
  for (final inline in [false, true]) {
    for (final pipeline in [false, true]) {
      test('$name reduction inline=$inline, pipeline=$pipeline', () async {
        final dut =
            _ReductionHarness(schema, inline: inline, pipeline: pipeline);
        await dut.build();
        expect(dut.result.runtimeType, schema.runtimeType);
        expect(dut.controlResult, isA<_Record>());
        expect(dut.latency, pipeline ? 1 : 0);
        final vectors = [
          Vector({
            'clk': 0,
            'reset': 1,
            'enable': 1,
            'control': 0xa0,
            for (var i = 0; i < 9; i++) 'data$i': i + 5,
          }, {}),
          Vector({'clk': 1}, {}),
          Vector({'clk': 0, 'reset': 0}, {}),
          Vector({'clk': 1}, {'result': 5, 'controlResult': 0xa0}),
          Vector({
            'clk': 0,
            'enable': 0,
            'control': 0xbf,
            for (var i = 0; i < 9; i++) 'data$i': i + 15,
          }, {}),
          Vector({
            'clk': 1
          }, {
            'result': pipeline ? 5 : 23,
            'controlResult': pipeline ? 0xa0 : 0xbf,
          }),
          Vector({'clk': 0, 'enable': 1}, {}),
          Vector({'clk': 1}, {'result': 23, 'controlResult': 0xbf}),
        ];
        await _compare(dut, vectors, systemC: systemC);
      });
    }
  }

  for (final clockGating in [false, true]) {
    for (final liveReset in [false, true]) {
      test('$name toggle clockGating=$clockGating, liveReset=$liveReset',
          () async {
        final dut = _ToggleHarness(schema,
            clockGating: clockGating, liveReset: liveReset);
        await dut.build();
        expect(dut.gate.gatedData.runtimeType, schema.runtimeType);
        expect(dut.gate.input('data').runtimeType, schema.runtimeType);
        if (liveReset) {
          expect(dut.gate.input('resetValue').runtimeType, schema.runtimeType);
        }
        await _compare(
            dut,
            [
              Vector({
                'clk': 0,
                'reset': 1,
                'enable': 0,
                'data': 9,
                'resetData': 5,
              }, {}),
              Vector({'clk': 1}, {}),
              Vector({'clk': 0}, {}),
              Vector({'clk': 1}, {'result': 5}),
              Vector({'reset': 0, 'enable': 1}, {'result': 9}),
              Vector({'clk': 0}, {'result': 9}),
              Vector({'clk': 1}, {'result': 9}),
              Vector({'enable': 0, 'data': 17}, {'result': 9}),
              Vector({'clk': 0}, {'result': 9}),
              Vector({'clk': 1}, {'result': 9}),
              Vector({'enable': 1}, {'result': 17}),
              Vector({'clk': 0}, {'result': 17}),
              Vector({'clk': 1}, {'result': 17}),
              Vector({'reset': 1, 'enable': 0, 'resetData': 7}, {}),
              Vector({'clk': 0}, {}),
              Vector({'clk': 1}, {'result': liveReset ? 7 : 5}),
            ],
            systemC: systemC);
      });
    }
  }
}

void main() {
  tearDown(Simulator.reset);

  _checkSort('record key', _Record(), (a, b) => a.key.lt(b.key),
      [0x93, 0xf1, 0x24, 0x62], [0xf1, 0x62, 0x93, 0x24],
      systemC: true);
  _checkSort(
      'rank-zero key',
      TypedLogicArray<_Record, LogicValue>([], _Record.new),
      (a, b) => a.scalar.key.lt(b.scalar.key),
      [0x93, 0xf1, 0x24, 0x62],
      [0xf1, 0x62, 0x93, 0x24]);
  _checkSort(
      'unpacked array key',
      TypedLogicArray<_Record, LogicValue>([2, 2], _Record.new,
          numUnpackedDimensions: 1),
      (a, b) => a.at([0, 0]).key.lt(b.at([0, 0]).key),
      [0x93, 0xf1, 0x24, 0x62],
      [0xf1, 0x62, 0x93, 0x24]);

  _checkStorage('plain', Logic(width: 8));
  _checkStorage('record', _Record(), systemC: true);
  _checkStorage('floating point', FloatingPoint32());
  _checkStorage('fixed point', FixedPoint(integerWidth: 3, fractionWidth: 4));
  _checkStorage(
      'rank-zero array', TypedLogicArray<_Record, LogicValue>([], _Record.new));
  _checkStorage(
      'unpacked array',
      TypedLogicArray<_Record, LogicValue>([2, 2], _Record.new,
          numUnpackedDimensions: 1));

  for (final inline in [false, true]) {
    for (final pipeline in [false, true]) {
      test(
          'typed reductions may grow formats, '
          'inline=$inline, pipeline=$pipeline', () async {
        final dut = _GrowingReduction(inline: inline, pipeline: pipeline);
        await dut.build();
        expect(dut.sawDifferentWidths, isTrue);
        expect(dut.result.data.width, 8);
        await _compare(
            dut,
            [
              Vector({
                'clk': 0,
                'reset': 1,
                for (var i = 0; i < 9; i++) 'data$i': 17,
              }, {}),
              Vector({'clk': 1}, {}),
              Vector({'clk': 0, 'reset': 0}, {}),
              Vector({'clk': 1}, {'result': 265}),
            ],
            systemC: !inline && pipeline);
      });
    }
  }

  test('sort rejects matching-width arrays with different shapes', () {
    final a = TypedLogicArray<_Record, LogicValue>([2, 2], _Record.new);
    final b = TypedLogicArray<_Record, LogicValue>([4], _Record.new);
    expect(() => BitonicSort(Logic(), Logic(), toSort: [a, b]),
        throwsA(isA<RohdHclException>()));
  });

  test('sort defaults to floating-point comparisons rather than packed order',
      () async {
    final dut = _SortHarness(FloatingPoint32());
    await dut.build();
    await _compare(dut, [
      Vector({
        'clk': 0,
        'reset': 0,
        'data0': 0x3fc00000,
        'data1': 0xc0000000,
        'data2': 0,
        'data3': 0x40500000,
      }, {}),
      for (var i = 0; i < 3; i++) ...[
        Vector({
          'clk': 1
        }, {
          if (i == 2) ...{
            'result0': 0xc0000000,
            'result1': 0,
            'result2': 0x3fc00000,
            'result3': 0x40500000,
          }
        }),
        Vector({'clk': 0}, {}),
      ],
    ]);
  });

  test('record sorting preserves exact streaming pipeline latency', () async {
    final dut = _SortHarness(_Record(), isLessThan: (a, b) => a.key.lt(b.key));
    await dut.build();
    await _compare(
        dut,
        [
          Vector({'clk': 0, 'reset': 0}, {}),
          for (var frame = 0; frame < 8; frame++) ...[
            Vector({
              'clk': 0,
              'data0': 0x93 + frame,
              'data1': 0xf1 + frame,
              'data2': 0x24 + frame,
              'data3': 0x62 + frame,
            }, {}),
            Vector({
              'clk': 1
            }, {
              if (frame >= 2) ...{
                'result0': 0xf1 + frame - 2,
                'result1': 0x62 + frame - 2,
                'result2': 0x93 + frame - 2,
                'result3': 0x24 + frame - 2,
              },
            }),
          ],
        ],
        systemC: true);
  });

  test('sort uses signed fixed-point comparisons for mixed signs', () async {
    final dut = _SortHarness(FixedPoint(integerWidth: 3, fractionWidth: 4));
    await dut.build();
    await _compare(dut, [
      Vector({
        'clk': 0,
        'reset': 0,
        'data0': 0x18,
        'data1': 0xe0,
        'data2': 0,
        'data3': 0xf0,
      }, {}),
      for (var cycle = 0; cycle < 3; cycle++) ...[
        Vector({
          'clk': 1
        }, {
          if (cycle == 2) ...{
            'result0': 0xe0,
            'result1': 0xf0,
            'result2': 0,
            'result3': 0x18,
          },
        }),
        Vector({'clk': 0}, {}),
      ],
    ]);
  });
}
