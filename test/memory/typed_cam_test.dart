// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_cam_test.dart
// Tests for the typed CAM.
//
// 2026 October 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:test/test.dart';

class _Tag extends LogicStructure {
  Logic get key => elements[0];
  Logic get context => elements[1];

  _Tag({String? name})
      : super([Logic(name: 'key', width: 4), Logic(name: 'context', width: 4)],
            name: name ?? 'tag');

  @override
  _Tag clone({String? name}) => _Tag(name: name ?? this.name);
}

enum _Phase { idle, busy, done, error }

typedef _TagValue = ({LogicValue key, LogicValue context});

_TagValue _decode(LogicValue bits) =>
    (key: bits.getRange(0, 4), context: bits.getRange(4, 8));

LogicValue _encode(_TagValue value) =>
    LogicValue.of([value.context, value.key]);

const _codec = LogicValueCodec<_TagValue>(decode: _decode, encode: _encode);

class _Harness<T extends Logic> extends Module {
  late final Cam<T> cam;
  final List<TagInterface<T>> writes = [];
  final List<TagInterface<T>> lookups = [];

  _Harness(T schema,
      {int entries = 3, int writeCount = 2, bool tracking = true}) {
    final indexWidth = widthFor(entries);
    for (var i = 0; i < writeCount; i++) {
      final port = TagInterface<T>.typed(indexWidth, schema);
      port.tag <=
          addInput('data$i', Logic(width: schema.width), width: schema.width);
      port.idx <=
          addInput('index$i', Logic(width: indexWidth), width: indexWidth);
      port.en <= addInput('write$i', Logic());
      port.hit <= addInput('valid$i', Logic());
      writes.add(port);
    }
    for (var i = 0; i < 2; i++) {
      final port = TagInterface<T>.typed(indexWidth, schema);
      port.tag <=
          addInput('query$i', Logic(width: schema.width), width: schema.width);
      port.en <= Const(0);
      lookups.add(port);
    }
    cam = Cam<T>(
        addInput('clk', Logic()), addInput('reset', Logic()), writes, lookups,
        numEntries: entries, enableValidTracking: tracking);
    for (var i = 0; i < 2; i++) {
      addOutput('hit$i') <= lookups[i].hit;
      addOutput('found$i', width: indexWidth) <= lookups[i].idx;
    }
    if (tracking) {
      addOutput('count', width: cam.validCount!.width) <= cam.validCount!;
      addOutput('full') <= cam.full!;
      addOutput('empty') <= cam.empty!;
    }
  }
}

class _PortDirections<T extends Logic> extends Module {
  late final TagInterface<T> source;
  late final TagInterface<T> internalInput;
  late final TagInterface<T> internalOutput;

  _PortDirections(T schema) {
    source = TagInterface<T>.typed(2, schema);
    internalInput = addInterfacePorts(source,
        inputTags: {DataPortGroup.control, DataPortGroup.data},
        uniquify: (name) => 'input_$name');
    final target = TagInterface<T>.typed(2, schema);
    internalOutput = addInterfacePorts(target,
        outputTags: {DataPortGroup.control},
        uniquify: (name) => 'output_$name');
    internalOutput.tag <= internalInput.tag;
    internalOutput.en <= internalInput.en;
  }
}

class _PortHarness<T extends Logic> extends Module {
  late final _PortDirections<T> child;

  _PortHarness(T schema) {
    // Drive raw bits without invoking domain-specific typed put conversions.
    child = _PortDirections<T>(schema);
    child.source.tag <=
        addInput('data', Logic(width: schema.width), width: schema.width);
    child.source.en <= addInput('enable', Logic());
    child.source.idx <= Const(0, width: 2);
    child.source.hit <= Const(0);
    addOutput('result', width: schema.width) <= child.output('output_tag');
    addOutput('flag') <= child.output('output_en');
  }
}

Future<void> _compare(Module dut, List<Vector> vectors,
    {bool systemC = false}) async {
  await dut.build();
  await SimCompare.checkFunctionalVector(dut, vectors);
  SimCompare.checkIverilogVector(dut, vectors);
  if (systemC) {
    expect(SimCompare.checkSystemCVector(dut, vectors), isTrue);
  }
}

void _expectTag<T extends Logic>(T schema, T signal) {
  expect(signal.runtimeType, schema.runtimeType);
  expect(sameDeclaredPayloadShape(schema, signal), isTrue);
}

List<Vector> _exercise(int first, int second, int third) => [
      Vector({
        'clk': 0,
        'reset': 1,
        'write0': 0,
        'write1': 0,
        'index0': 0,
        'index1': 0,
        'valid0': 0,
        'valid1': 0,
        'data0': 0,
        'data1': 0,
        'query0': first,
        'query1': second
      }, {}),
      Vector({
        'clk': 1
      }, {
        'hit0': 0,
        'found0': 0,
        'hit1': 0,
        'found1': 0,
        'count': 0,
        'full': 0,
        'empty': 1
      }),
      Vector({
        'clk': 0,
        'reset': 0,
        'write0': 1,
        'valid0': 1,
        'index0': 0,
        'data0': first,
        'write1': 1,
        'valid1': 1,
        'index1': 2,
        'data1': second
      }, {}),
      Vector({
        'clk': 1
      }, {
        'hit0': 1,
        'found0': 0,
        'hit1': 1,
        'found1': 2,
        'count': 2,
        'full': 0,
        'empty': 0
      }),
      Vector({'clk': 0, 'write1': 0, 'index0': 1, 'data0': first}, {}),
      Vector({'clk': 1}, {'hit0': 1, 'found0': 0, 'count': 3, 'full': 1}),
      Vector({'clk': 0, 'index0': 0, 'valid0': 0}, {}),
      Vector({'clk': 1}, {'hit0': 1, 'found0': 1, 'count': 2, 'full': 0}),
      Vector({
        'clk': 0,
        'index0': 1,
        'data0': second,
        'valid0': 1,
        'index1': 1,
        'data1': third,
        'valid1': 1,
        'write1': 1,
        'query0': third
      }, {}),
      Vector({'clk': 1},
          {'hit0': 1, 'found0': 1, 'hit1': 1, 'found1': 2, 'count': 2}),
      Vector({'clk': 0, 'data0': first, 'valid1': 0}, {}),
      Vector({'clk': 1}, {'hit0': 0, 'found0': 0, 'count': 1}),
      Vector({
        'clk': 0,
        'index0': 3,
        'index1': 3,
        'data0': third,
        'data1': third,
        'valid1': 1
      }, {}),
      Vector({'clk': 1}, {'hit0': 0, 'hit1': 1, 'found1': 2, 'count': 1}),
      Vector({'clk': 0, 'reset': 1, 'index0': 0, 'index1': 1}, {}),
      Vector({
        'clk': 1
      }, {
        'hit0': 0,
        'hit1': 0,
        'found0': 0,
        'found1': 0,
        'count': 0,
        'full': 0,
        'empty': 1
      }),
    ];

void _checkTags<T extends Logic>(String label, T schema,
    {bool systemC = false}) {
  // Exercise duplicates, invalidation, last-write priority, misses, and reset.
  test('$label typed CAM', () async {
    final dut = _Harness<T>(schema);
    for (final port in [...dut.writes, ...dut.lookups]) {
      _expectTag<T>(schema, port.tag);
      final clone = port.clone();
      _expectTag<T>(schema, clone.tag);
      expect(identical(port.tag, schema), isFalse);
      expect(identical(port.tag, clone.tag), isFalse);
    }
    for (var i = 0; i < 2; i++) {
      expect(
          sameDeclaredPayloadShape(schema, dut.cam.input('wr_tag_$i')), isTrue);
      expect(sameDeclaredPayloadShape(schema, dut.cam.input('lookup_tag_$i')),
          isTrue);
    }
    final mask = (1 << schema.width) - 1;
    await _compare(
        dut, _exercise(0x102030a1 & mask, 0x405060b2 & mask, 0x708090c3 & mask),
        systemC: systemC);
  });

  test('$label typed tag input/output registration', () async {
    final dut = _PortHarness<T>(schema);
    _expectTag<T>(schema, dut.child.internalInput.tag);
    _expectTag<T>(schema, dut.child.internalOutput.tag);
    expect(
        sameDeclaredPayloadShape(schema, dut.child.input('input_tag')), isTrue);
    expect(sameDeclaredPayloadShape(schema, dut.child.output('output_tag')),
        isTrue);
    final mask = (1 << schema.width) - 1;
    await _compare(
        dut,
        [
          Vector({'data': 0x102030a1 & mask, 'enable': 0},
              {'result': 0x102030a1 & mask, 'flag': 0}),
          Vector({'data': 0x405060b2 & mask, 'enable': 1},
              {'result': 0x405060b2 & mask, 'flag': 1}),
        ],
        systemC: systemC);
  });
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  _checkTags('scalar', Logic(width: 8), systemC: true);
  _checkTags('record', _Tag(), systemC: true);
  _checkTags<Logic>('record with Logic static type', _Tag());
  _checkTags('floating-point', FloatingPoint32());
  _checkTags('fixed-point', FixedPoint(integerWidth: 3, fractionWidth: 4));
  _checkTags('enum', LogicEnum<_Phase>(_Phase.values));
  _checkTags('rank-zero', TypedLogicArray<_Tag, LogicValue>([], _Tag.new));
  _checkTags(
      'unpacked multidimensional',
      TypedLogicArray<_Tag, LogicValue>([2, 2], _Tag.new,
          numUnpackedDimensions: 2),
      systemC: true);
  _checkTags('custom codec',
      TypedLogicArray<_Tag, _TagValue>([2], _Tag.new, valueCodec: _codec));

  // Floating numeric equality would alias signed zeros and miss NaN identities.
  test('floating CAM matches NaN payloads and distinguishes signed zeros',
      () async {
    final dut = _Harness(FloatingPoint32(), entries: 4);
    await _compare(
        dut,
        [
          Vector({
            'clk': 0,
            'reset': 1,
            'write0': 0,
            'write1': 0,
            'index0': 0,
            'index1': 0,
            'valid0': 0,
            'valid1': 0,
            'data0': 0,
            'data1': 0,
            'query0': 0,
            'query1': 0x80000000
          }, {}),
          Vector({'clk': 1}, {'hit0': 0, 'hit1': 0}),
          Vector({
            'clk': 0,
            'reset': 0,
            'write0': 1,
            'index0': 0,
            'data0': 0,
            'valid0': 1
          }, {}),
          Vector({'clk': 1}, {'hit0': 1, 'found0': 0, 'hit1': 0}),
          Vector({'clk': 0, 'index0': 1, 'data0': 0x80000000}, {}),
          Vector({'clk': 1}, {'hit0': 1, 'found0': 0, 'hit1': 1, 'found1': 1}),
          Vector({
            'clk': 0,
            'index0': 2,
            'data0': 0x7fc00001,
            'query0': 0x7fc00001,
            'query1': 0x7fc00002
          }, {}),
          Vector({'clk': 1}, {'hit0': 1, 'found0': 2, 'hit1': 0}),
          Vector({'clk': 0, 'index0': 3, 'data0': 0x7fc00002}, {}),
          Vector({'clk': 1}, {'hit0': 1, 'found0': 2, 'hit1': 1, 'found1': 3}),
        ],
        systemC: true);
  });

  // Known queries must ignore unknown stored tags and unknown valid bits.
  test('CAM retains case matching for unknown stored bits', () async {
    final dut = _Harness(_Tag());
    await _compare(dut, [
      Vector({
        'clk': 0,
        'reset': 1,
        'write0': 0,
        'write1': 0,
        'index0': 0,
        'index1': 0,
        'valid0': 0,
        'valid1': 0,
        'data0': 0,
        'data1': 0,
        'query0': 0x21,
        'query1': 0x22
      }, {}),
      Vector({'clk': 1}, {'hit0': 0, 'hit1': 0}),
      Vector({
        'clk': 0,
        'reset': 0,
        'write0': 1,
        'index0': 0,
        'valid0': 1,
        'data0': LogicValue.ofString('0010000x'),
        'write1': 1,
        'index1': 1,
        'valid1': 1,
        'data1': 0x21
      }, {}),
      Vector({'clk': 1}, {'hit0': 1, 'found0': 1, 'hit1': 0}),
      Vector(
          {'clk': 0, 'data0': 0x21, 'valid0': LogicValue.x, 'write1': 0}, {}),
      Vector({'clk': 1}, {'hit0': 1, 'found0': 1, 'hit1': 0}),
      Vector({'clk': 0, 'valid0': 1, 'data0': LogicValue.ofString('0010000z')},
          {}),
      Vector({'clk': 1}, {'hit0': 1, 'found0': 1, 'hit1': 0}),
    ]);
  });

  for (final entries in [1, 3]) {
    test('lookup-only CAM entries=$entries resets cleanly', () async {
      final dut = _Harness(_Tag(), entries: entries, writeCount: 0);
      await _compare(dut, [
        Vector({'clk': 0, 'reset': 1, 'query0': 0, 'query1': 0xa3}, {}),
        Vector({
          'clk': 1
        }, {
          'hit0': 0,
          'found0': 0,
          'hit1': 0,
          'found1': 0,
          'count': 0,
          'empty': 1,
          'full': 0
        }),
        Vector({'clk': 0, 'reset': 0}, {}),
        Vector({'clk': 1}, {'hit0': 0, 'hit1': 0, 'count': 0}),
      ]);
    });
  }

  test('typed CAM tracking remains optional', () async {
    final dut = _Harness(_Tag(), tracking: false);
    expect(dut.cam.validCount, isNull);
    expect(dut.cam.full, isNull);
    expect(dut.cam.empty, isNull);
    await _compare(dut, [
      Vector({
        'clk': 0,
        'reset': 1,
        'write0': 0,
        'write1': 0,
        'index0': 0,
        'index1': 0,
        'valid0': 0,
        'valid1': 0,
        'data0': 0,
        'data1': 0,
        'query0': 0,
        'query1': 0
      }, {}),
      Vector({'clk': 1}, {'hit0': 0, 'hit1': 0}),
    ]);
  });

  test('typed CAM rejects mismatching layouts and index widths', () {
    final first = TypedLogicArray<_Tag, LogicValue>([2, 2], _Tag.new);
    final second = TypedLogicArray<_Tag, LogicValue>([4], _Tag.new);
    expect(
        () => Cam(Logic(), Logic(), [TagInterface.typed(2, first)],
            [TagInterface.typed(2, second)],
            numEntries: 3),
        throwsA(isA<RohdHclException>()));
    expect(
        () => Cam(Logic(), Logic(), [TagInterface(1, 8)], [TagInterface(2, 8)],
            numEntries: 3),
        throwsA(isA<RohdHclException>()));
    expect(
        () => Cam<Logic>(Logic(), Logic(), [], [TagInterface(2, 8)],
            numEntries: 0),
        throwsArgumentError);
    expect(() => TagInterface<_Tag>(2, 8), throwsArgumentError);
  });

  test('typed CAM rejects mismatching codecs', () {
    final otherCodec =
        // Deliberately distinct codec identity.
        // ignore: prefer_const_constructors
        LogicValueCodec<_TagValue>(decode: _decode, encode: _encode);
    final first =
        TypedLogicArray<_Tag, _TagValue>([2], _Tag.new, valueCodec: _codec);
    final second =
        TypedLogicArray<_Tag, _TagValue>([2], _Tag.new, valueCodec: otherCodec);
    expect(
        () => Cam(Logic(), Logic(), [TagInterface.typed(2, first)],
            [TagInterface.typed(2, second)],
            numEntries: 3),
        throwsA(isA<RohdHclException>()));
  });
}
