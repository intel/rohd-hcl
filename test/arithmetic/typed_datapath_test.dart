// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_datapath_test.dart
// Tests for typed datapath modules.
//
// 2026 October 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Packet extends LogicStructure {
  _Packet({String? name})
      : super([Logic(name: 'tag', width: 3), Logic(name: 'data', width: 5)],
            name: name ?? 'packet');

  @override
  _Packet clone({String? name}) => _Packet(name: name ?? this.name);
}

class _ParentNamedPacket extends LogicStructure {
  final String suffix;

  _ParentNamedPacket({String name = 'packet', this.suffix = 'bits'})
      : super([Logic(name: '${name}_$suffix', width: 8)], name: name);

  @override
  _ParentNamedPacket clone({String? name}) =>
      _ParentNamedPacket(name: name ?? this.name, suffix: suffix);
}

class _DazFloat extends FloatingPoint {
  _DazFloat({super.name})
      : super(
            exponentWidth: 4,
            mantissaWidth: 5,
            explicitJBit: true,
            subNormalAsZero: true);

  @override
  _DazFloat clone({String? name}) => _DazFloat(name: name ?? this.name);

  @override
  FloatingPointValuePopulator<FloatingPointValue> valuePopulator() =>
      FloatingPointValue.populator(
          exponentWidth: 4,
          mantissaWidth: 5,
          explicitJBit: true,
          subNormalAsZero: true);
}

class _MisclonedFloat extends FloatingPoint {
  _MisclonedFloat({bool daz = false, super.name})
      : super(exponentWidth: 4, mantissaWidth: 3, subNormalAsZero: daz);

  @override
  _MisclonedFloat clone({String? name}) =>
      _MisclonedFloat(daz: true, name: name ?? this.name);

  @override
  FloatingPointValuePopulator<FloatingPointValue> valuePopulator() =>
      FloatingPointValue.populator(
          exponentWidth: 4, mantissaWidth: 3, subNormalAsZero: subNormalAsZero);
}

enum _State { first, second, third }

typedef _PacketValue = ({LogicValue bits});

class _TypedFlop<T extends Logic> extends Module {
  late final T registered;

  _TypedFlop(T schema, {bool asyncReset = false}) {
    final data = schema.cloneTyped(name: 'payload')
      ..gets(addInput('data', Logic(width: schema.width), width: schema.width));
    registered = condFlop(addInput('clk', Logic()), data,
        en: addInput('enable', Logic()),
        reset: addInput('reset', Logic()),
        resetValue: 5,
        asyncReset: asyncReset);
    addTypedOutput('result', schema.cloneTyped) <= registered;
  }
}

class _TypedSwap<T extends Logic> extends Module {
  late final (T, T) swapped;

  _TypedSwap(T schema) {
    final a = schema.cloneTyped(name: 'operandA')
      ..gets(addInput('a', Logic(width: schema.width), width: schema.width));
    final b = schema.cloneTyped(name: 'operandB')
      ..gets(addInput('b', Logic(width: schema.width), width: schema.width));
    swapped = swap(addInput('select', Logic()), (a, b));
    addTypedOutput('first', schema.cloneTyped) <= swapped.$1;
    addTypedOutput('second', schema.cloneTyped) <= swapped.$2;
  }
}

class _ConstantFlop extends Module {
  _ConstantFlop() {
    addOutput('result', width: 8) <=
        condFlop<Logic>(addInput('clk', Logic()), Const(9, width: 8));
  }
}

class _MetadataSwap<T extends Logic> extends Module {
  late final FloatingPointSwap<FloatingPoint32, T> sorter;

  _MetadataSwap(String kind, T schema) {
    final a = FloatingPoint32()
      ..gets(addInput('a', Logic(width: 32), width: 32));
    final b = FloatingPoint32()
      ..gets(addInput('b', Logic(width: 32), width: 32));
    final metaA = schema.cloneTyped(name: 'metadataA')
      ..gets(
          addInput('metaA', Logic(width: schema.width), width: schema.width));
    final metaB = schema.cloneTyped(name: 'metadataB')
      ..gets(
          addInput('metaB', Logic(width: schema.width), width: schema.width));
    final select = addInput('select', Logic());
    sorter = switch (kind) {
      'conditional' =>
        FloatingPointConditionalSwap(a, b, select, metaA: metaA, metaB: metaB),
      'value' => FloatingPointSort(a, b, metaA: metaA, metaB: metaB),
      'exponent' => FloatingPointSortByExp(a, b, metaA: metaA, metaB: metaB),
      _ => throw ArgumentError.value(kind, 'kind'),
    };
    addOutput('first', width: 32) <= sorter.outA;
    addOutput('second', width: 32) <= sorter.outB;
    addOutput('firstMeta', width: schema.width) <= sorter.outMetaA!;
    addOutput('secondMeta', width: schema.width) <= sorter.outMetaB!;
  }
}

FixedPoint _constantFixed(int value) =>
    FixedPoint.constant(FixedPointValue.withSignedness(
        integer: LogicValue.ofInt(value >> 4, 4),
        fraction: LogicValue.ofInt(value & 0xf, 4)));

class _ConstantMetadataSwap extends Module {
  late final FloatingPointConditionalSwap<FloatingPoint32, Logic> sorter;

  _ConstantMetadataSwap() {
    final a = FloatingPoint32()
      ..gets(addInput('a', Logic(width: 32), width: 32));
    final b = FloatingPoint32()
      ..gets(addInput('b', Logic(width: 32), width: 32));
    sorter = FloatingPointConditionalSwap<FloatingPoint32, Logic>(
        a, b, addInput('select', Logic()),
        metaA: _constantFixed(0x12), metaB: _constantFixed(0x34));
    addOutput('firstMeta', width: 8) <= sorter.outMetaA!;
    addOutput('secondMeta', width: 8) <= sorter.outMetaB!;
  }
}

class _ConstantUtilityHarness extends Module {
  late final (Logic, Logic) swapped;
  late final Logic registered;

  _ConstantUtilityHarness() {
    final first = _constantFixed(0x12);
    final second = _constantFixed(0x34);
    swapped = swap<Logic>(addInput('select', Logic()), (first, second));
    registered = condFlop<Logic>(addInput('clk', Logic()), first,
        reset: addInput('reset', Logic()), resetValue: second);
    addOutput('first', width: 8) <= swapped.$1;
    addOutput('second', width: 8) <= swapped.$2;
    addOutput('registered', width: 8) <= registered;
  }
}

class _ConstantFloatSort extends Module {
  _ConstantFloatSort() {
    final first =
        FloatingPoint32.constant(FloatingPoint32Value.populator().ofDouble(1));
    final second =
        FloatingPoint32.constant(FloatingPoint32Value.populator().ofDouble(2));
    final sorted = FloatingPointUtilities.sort((first, second));
    final swapped = FloatingPointConditionalSwap<FloatingPoint32, Logic>(
        first, second, addInput('select', Logic()));
    addOutput('larger', width: 32) <= sorted.sorted.$1;
    addOutput('smaller', width: 32) <= sorted.sorted.$2;
    addOutput('swapped', width: 32) <= swapped.outA;
  }
}

Future<void> _compare(Module dut, List<Vector> vectors,
    {bool systemC = false}) async {
  await SimCompare.checkFunctionalVector(dut, vectors);
  SimCompare.checkIverilogVector(dut, vectors);
  if (systemC) {
    SimCompare.checkSystemCVector(dut, vectors);
  }
}

void _checkPayload<T extends Logic>(String description, T schema,
    {bool systemC = false}) {
  for (final asyncReset in [false, true]) {
    test('$description condFlop with asyncReset=$asyncReset', () async {
      final dut = _TypedFlop<T>(schema, asyncReset: asyncReset);
      await dut.build();
      expect(dut.registered.runtimeType, schema.runtimeType);
      expect(dut.output('result').runtimeType, schema.runtimeType);
      if (schema is FixedPoint) {
        final result = dut.registered as FixedPoint;
        expect(result.signed, schema.signed);
        expect(result.integerWidth, schema.integerWidth);
        expect(result.fractionWidth, schema.fractionWidth);
      }
      if (schema is FloatingPoint) {
        final result = dut.registered as FloatingPoint;
        expect(result.explicitJBit, schema.explicitJBit);
        expect(result.subNormalAsZero, schema.subNormalAsZero);
      }
      if (schema is TypedLogicArray) {
        final result = dut.registered as TypedLogicArray;
        expect(result.dimensions, schema.dimensions);
        expect(result.valueCodec, same(schema.valueCodec));
      }
      await _compare(
          dut,
          [
            Vector({'clk': 0, 'reset': 1, 'enable': 1, 'data': 0}, {}),
            Vector({'clk': 1}, {'result': 5}),
            Vector({'clk': 0, 'reset': 0, 'data': 9}, {'result': 5}),
            Vector({'clk': 1}, {'result': 9}),
            Vector({'clk': 0, 'enable': 0, 'data': 17}, {'result': 9}),
            Vector({'clk': 1}, {'result': 9}),
            Vector({'clk': 0, 'reset': 1}, {'result': asyncReset ? 5 : 9}),
            Vector({'clk': 1}, {'result': 5}),
          ],
          systemC: systemC);
    });
  }

  test('$description swap preserves payloads inside typed muxes', () async {
    final dut = _TypedSwap<T>(schema);
    await dut.build();
    expect(dut.swapped.$1.runtimeType, schema.runtimeType);
    expect(dut.swapped.$2.runtimeType, schema.runtimeType);
    final muxes = dut.subModules.whereType<Mux<T>>();
    expect(muxes, hasLength(2));
    for (final mux in muxes) {
      expect(mux.out.runtimeType, schema.runtimeType);
    }
    await _compare(
        dut,
        [
          Vector({'select': 0, 'a': 5, 'b': 9}, {'first': 5, 'second': 9}),
          Vector({'select': 1}, {'first': 9, 'second': 5}),
          Vector({'select': 0, 'a': 17}, {'first': 17, 'second': 9}),
        ],
        systemC: systemC);
  });
}

void _checkMetadata<T extends Logic>(String label, T schema,
    {bool systemC = false}) {
  for (final kind in ['conditional', 'value', 'exponent']) {
    test('$kind swap statically preserves $label metadata', () async {
      final dut = _MetadataSwap<T>(kind, schema);
      await dut.build();
      // ignore: omit_local_variable_types, verifies static metadata type
      final T first = dut.sorter.outMetaA!;
      expect(first.runtimeType, schema.runtimeType);
      for (final port in [
        dut.sorter.input('inMetaA'),
        dut.sorter.input('inMetaB'),
        first,
        dut.sorter.outMetaB!,
      ]) {
        expect(sameRohdPayloadShape(schema, port), isTrue);
      }
      final metadataMuxes = dut.sorter.subModules
          .whereType<Mux<T>>()
          .where((mux) => sameRohdPayloadShape(schema, mux.out));
      expect(metadataMuxes, hasLength(2));
      final mask = (1 << schema.width) - 1;
      final a = 0x102030a1 & mask;
      final b = 0x405060b2 & mask;
      await _compare(
          dut,
          [
            Vector({
              'select': 0,
              'a': 0x3f800000,
              'b': 0x40000000,
              'metaA': a,
              'metaB': b,
            }, {
              'firstMeta': kind == 'conditional' ? a : b,
              'secondMeta': kind == 'conditional' ? b : a,
            }),
            Vector({'select': 1}, {'firstMeta': b, 'secondMeta': a}),
            Vector({
              'a': 0x40400000,
              'b': 0x3f800000
            }, {
              'firstMeta': kind == 'conditional' ? b : a,
              'secondMeta': kind == 'conditional' ? a : b,
            }),
          ],
          systemC: systemC);
    });
  }
}

void main() {
  test('floating-point boundaries reject changed clone formats', () {
    final bad = _MisclonedFloat();
    expect(
        () => FloatingPointClassifier(bad), throwsA(isA<PortTypeException>()));
    expect(() => FloatingPointComparator(bad, _MisclonedFloat()),
        throwsA(isA<PortTypeException>()));
    expect(
        () => FloatingPointConditionalSwap<FloatingPoint, Logic>(
            bad, _MisclonedFloat(), Logic()),
        throwsA(isA<PortTypeException>()));
    expect(
        () => FloatingPointConverter<FloatingPoint, FloatingPoint>(
            bad, FloatingPoint(exponentWidth: 4, mantissaWidth: 3)),
        throwsA(isA<PortTypeException>()));
  });

  tearDown(Simulator.reset);

  test('floating-point swap preserves widened structured constant metadata',
      () async {
    final dut = _ConstantMetadataSwap();
    expect(dut.sorter.input('inMetaA'), isA<FixedPoint>());
    expect(dut.sorter.outMetaA, isA<FixedPoint>());
    await dut.build();
    await _compare(dut, [
      Vector({'a': 0, 'b': 0, 'select': 0},
          {'firstMeta': 0x12, 'secondMeta': 0x34}),
      Vector({'select': 1}, {'firstMeta': 0x34, 'secondMeta': 0x12}),
      Vector({
        'select': LogicValue.x
      }, {
        'firstMeta': LogicValue.ofString('00x10xx0'),
        'secondMeta': LogicValue.ofString('00x10xx0'),
      }),
    ]);
  });

  test('shared swap and flop preserve widened structured constants', () async {
    final dut = _ConstantUtilityHarness();
    expect(dut.swapped.$1, isA<FixedPoint>());
    expect(dut.swapped.$2, isA<FixedPoint>());
    expect(dut.registered, isA<FixedPoint>());
    await dut.build();
    await _compare(dut, [
      Vector(
          {'clk': 0, 'reset': 1, 'select': 0}, {'first': 0x12, 'second': 0x34}),
      Vector({'clk': 1}, {'registered': 0x34}),
      Vector(
          {'clk': 0, 'reset': 0, 'select': 1}, {'first': 0x34, 'second': 0x12}),
      Vector({'clk': 1}, {'registered': 0x12}),
      Vector({
        'select': LogicValue.x
      }, {
        'first': LogicValue.ofString('00x10xx0'),
        'second': LogicValue.ofString('00x10xx0'),
      }),
    ]);
  });

  test('floating-point sorting accepts compatible constant operands', () async {
    final dut = _ConstantFloatSort();
    await dut.build();
    await _compare(dut, [
      Vector({'select': 0},
          {'larger': 0x40000000, 'smaller': 0x3f800000, 'swapped': 0x3f800000}),
      Vector({'select': 1}, {'swapped': 0x40000000}),
    ]);
  });

  _checkPayload('plain', Logic(width: 8));
  _checkPayload('parent-renamed payload', _ParentNamedPacket());

  test('floating-point swaps accept parent-renamed metadata', () async {
    final dut =
        _MetadataSwap<_ParentNamedPacket>('conditional', _ParentNamedPacket());
    await dut.build();
    await _compare(dut, [
      Vector({
        'select': 0,
        'a': 0x3f800000,
        'b': 0x40000000,
        'metaA': 0x12,
        'metaB': 0x34,
      }, {
        'firstMeta': 0x12,
        'secondMeta': 0x34,
      }),
      Vector({'select': 1}, {'firstMeta': 0x34, 'secondMeta': 0x12}),
    ]);
  });

  test('renamed payload checks still reject incompatible flop and swap data',
      () {
    final data = _ParentNamedPacket(name: 'sourcePayload');
    final resetData = _ParentNamedPacket(name: 'resetPayload');
    final incompatible =
        _ParentNamedPacket(name: 'otherPayload', suffix: 'other');
    expect(() => condFlop(Logic(), data, reset: Logic(), resetValue: resetData),
        returnsNormally);
    expect(
        () => condFlop(Logic(), data, reset: Logic(), resetValue: incompatible),
        throwsArgumentError);
    expect(() => swap(Logic(), (data, incompatible)), throwsArgumentError);
  });
  _checkPayload('floating-point subtype', FloatingPoint32(), systemC: true);
  _checkPayload('fixed-point format',
      FixedPoint(integerWidth: 3, fractionWidth: 4, signed: false));
  _checkPayload(
      'floating-point flags',
      FloatingPoint(
          exponentWidth: 3,
          mantissaWidth: 4,
          explicitJBit: true,
          subNormalAsZero: true));
  _checkPayload('structure widened to Logic', _Packet() as Logic);
  _checkPayload('fixed point widened to Logic',
      FixedPoint(integerWidth: 3, fractionWidth: 4) as Logic);
  _checkPayload(
      'finite field widened to Logic',
      GfLogic(BinaryExtensionField(
          modulus: BinaryPolynomial(BigInt.from(0x11b)))) as Logic);
  _checkPayload(
      'enum',
      LogicEnum<_State>.withMapping({
        _State.first: 5,
        _State.second: 9,
        _State.third: 17,
      }));
  _checkPayload('rank-zero array',
      TypedLogicArray<FloatingPoint32, LogicValue>([], FloatingPoint32.new));
  _checkPayload('multidimensional array',
      TypedLogicArray<_Packet, LogicValue>([2, 2], _Packet.new));
  _checkPayload(
      'custom codec',
      TypedLogicArray<_Packet, _PacketValue>([2], _Packet.new,
          valueCodec: LogicValueCodec<_PacketValue>(
              decode: (value) => (bits: value),
              encode: (value) => value.bits)));

  test('swap resolves identical inputs with unknown control', () {
    final (first, second) = swap(Logic()..put(LogicValue.x),
        (Logic(width: 8)..put(5), Logic(width: 8)..put(5)));
    expect(first.value, LogicValue.ofInt(5, 8));
    expect(second.value, LogicValue.ofInt(5, 8));
  });

  test('swap rejects incompatible typed formats but permits packed bridges',
      () {
    final signed = FixedPoint(integerWidth: 3, fractionWidth: 4);
    final unsigned =
        FixedPoint(integerWidth: 4, fractionWidth: 4, signed: false);
    expect(() => swap(Logic(), (signed, unsigned)), throwsArgumentError);

    signed.fraction.put(1);
    signed.integer.put(2);
    final packed = Logic(width: 8)..put(0xa6);
    final (first, second) = swap<Logic>(Logic()..put(1), (signed, packed));
    expect(first, isA<FixedPoint>());
    expect(first.value, LogicValue.ofInt(0xa6, 8));
    expect(second.value, LogicValue.ofInt(0x21, 8));

    final firstField =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final secondField =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    expect(
        () => swap<Logic>(Logic(), (GfLogic(firstField), GfLogic(secondField))),
        throwsArgumentError);
  });

  test('condFlop rejects incompatible output and reset formats', () {
    final signed = FixedPoint(integerWidth: 3, fractionWidth: 4);
    final unsigned =
        FixedPoint(integerWidth: 4, fractionWidth: 4, signed: false);
    expect(() => condFlop(Logic(), signed, outputGenerator: unsigned.clone),
        throwsArgumentError);
    expect(
        () => condFlop(Logic(), signed, reset: Logic(), resetValue: unsigned),
        throwsArgumentError);
    expect(
        () => condFlop<Logic>(Logic(), signed,
            reset: Logic(),
            resetValue: unsigned,
            outputGenerator: ({name}) =>
                Logic(name: name, width: signed.width)),
        throwsArgumentError);
    expect(
        condFlop(Logic(), signed,
            reset: Logic(), resetValue: Logic(width: signed.width)),
        isA<FixedPoint>());
    expect(
        condFlop<Logic>(Logic(), signed,
            reset: Logic(),
            resetValue: signed.clone(),
            outputGenerator: ({name}) =>
                Logic(name: name, width: signed.width)),
        isA<Logic>());
    expect(
        condFlop<Logic>(Logic(), signed,
            reset: Logic(),
            resetValue: Logic(width: signed.width),
            outputGenerator: ({name}) =>
                Logic(name: name, width: signed.width)),
        isA<Logic>());
    expect(
        condFlop(null, signed,
            reset: Logic(),
            resetValue: unsigned,
            outputGenerator: unsigned.clone),
        same(signed));

    final firstField =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final secondField =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    expect(
        () => condFlop(Logic(), GfLogic(firstField),
            reset: Logic(), resetValue: GfLogic(secondField)),
        throwsArgumentError);
  });

  test('condFlop honors an explicit output schema only when clocked', () {
    var calls = 0;
    FloatingPoint32 generate({String? name}) {
      calls++;
      return FloatingPoint32(name: name);
    }

    final input = FloatingPoint32();
    expect(condFlop(null, input, outputGenerator: generate), same(input));
    expect(calls, 0);
    expect(condFlop(Logic(), input, outputGenerator: generate),
        isA<FloatingPoint32>());
    expect(calls, 1);
  });

  test('denormal selection preserves the floating-point runtime schema',
      () async {
    final input = _DazFloat();
    final result = input.resolveSubNormalAsZero();
    expect(result, isA<_DazFloat>());
    expect(result.explicitJBit, isTrue);
    expect(result.subNormalAsZero, isTrue);
    input.put(input.valuePopulator().ofInts(0, 1));
    await Simulator.tick();
    expect(result.value.toInt(), 0);
    input.put(input.valuePopulator().ofInts(1, 16));
    await Simulator.tick();
    expect(result.value, input.value);
  });

  test('NaN propagation selects typed operands and preserves their payload',
      () async {
    final first = FloatingPoint32()..put(0x7f800001);
    final second = FloatingPoint32()..put(0xffc00002);
    final result = FloatingPoint32().propagateNaN(first, second);
    expect(result, isA<FloatingPoint32>());
    await Simulator.tick();
    expect(result.value, LogicValue.ofInt(0x7fc00001, 32));
    first.put(0x3f800000);
    await Simulator.tick();
    expect(result.value, LogicValue.ofInt(0xffc00002, 32));
  });

  test('null-clock condFlop retains static type and aliases its input', () {
    final input = FloatingPoint32();
    final FloatingPoint32 bypass =
        condFlop(null, input, en: Logic(), reset: Logic(), resetValue: 0);
    expect(bypass, same(input));
    final literal = Const(9, width: 8);
    final Const constantBypass = condFlop(null, literal);
    expect(constantBypass, same(literal));
  });

  test('scalar constants can explicitly request a driveable Logic result',
      () async {
    final dut = _ConstantFlop();
    await dut.build();
    await _compare(dut, [
      Vector({'clk': 0}, {}),
      Vector({'clk': 1}, {'result': 9}),
      Vector({'clk': 0}, {'result': 9}),
    ]);
    final (first, second) =
        swap<Logic>(Logic()..put(1), (Const(5, width: 8), Const(9, width: 8)));
    expect(first.value.toInt(), 9);
    expect(second.value.toInt(), 5);
  });

  for (final kind in ['conditional', 'value', 'exponent']) {
    test('$kind floating-point swap carries structured metadata', () async {
      final dut =
          _MetadataSwap(kind, FixedPoint(integerWidth: 3, fractionWidth: 4));
      await dut.build();
      // ignore: omit_local_variable_types, verifies static payload type
      final FloatingPoint32 first = dut.sorter.outA;
      expect(first, isA<FloatingPoint32>());
      for (final port in [
        dut.sorter.input('inMetaA'),
        dut.sorter.input('inMetaB'),
        dut.sorter.outMetaA!,
        dut.sorter.outMetaB!,
      ]) {
        expect(port, isA<FixedPoint>());
        final metadata = port as FixedPoint;
        expect(metadata.signed, isTrue);
        expect(metadata.integerWidth, 3);
        expect(metadata.fractionWidth, 4);
      }
      final unchanged = kind == 'conditional';
      await _compare(dut, [
        Vector({
          'select': 0,
          'a': 0x3f800000,
          'b': 0x40000000,
          'metaA': 5,
          'metaB': 9,
        }, {
          'first': unchanged ? 0x3f800000 : 0x40000000,
          'second': unchanged ? 0x40000000 : 0x3f800000,
          'firstMeta': unchanged ? 5 : 9,
          'secondMeta': unchanged ? 9 : 5,
        }),
        Vector({
          'select': 1
        }, {
          'first': 0x40000000,
          'second': 0x3f800000,
          'firstMeta': 9,
          'secondMeta': 5,
        }),
      ]);
    });
  }

  _checkMetadata('structure', _Packet(), systemC: true);
  _checkMetadata<Logic>('runtime structure', _Packet());
  _checkMetadata(
      'enum',
      LogicEnum<_State>.withMapping({
        _State.first: 0xa1,
        _State.second: 0xb2,
        _State.third: 0xc3,
      }));
  _checkMetadata(
      'rank-zero', TypedLogicArray<_Packet, LogicValue>([], _Packet.new));
  _checkMetadata(
      'unpacked array',
      TypedLogicArray<_Packet, LogicValue>([2, 2], _Packet.new,
          numUnpackedDimensions: 2));
  _checkMetadata(
      'custom codec',
      TypedLogicArray<_Packet, _PacketValue>([2], _Packet.new,
          valueCodec: LogicValueCodec<_PacketValue>(
              decode: (bits) => (bits: bits), encode: (value) => value.bits)));

  test('floating-point metadata rejects incompatible layouts and codecs', () {
    final a = FloatingPoint32();
    final b = FloatingPoint32();
    expect(() => FloatingPointSort(a, b, metaA: _Packet()),
        throwsA(isA<RohdHclException>()));
    expect(
        () => FloatingPointSort(a, b, metaA: _Packet(), metaB: Logic(width: 8)),
        throwsA(isA<RohdHclException>()));
    expect(
        () => FloatingPointSort(a, b,
            metaA: TypedLogicArray<_Packet, LogicValue>([2, 2], _Packet.new),
            metaB: TypedLogicArray<_Packet, LogicValue>([4], _Packet.new)),
        throwsA(isA<RohdHclException>()));
    final first = LogicEnum<_State>.withMapping({
      _State.first: 1,
      _State.second: 2,
      _State.third: 3,
    });
    final second = LogicEnum<_State>.withMapping({
      _State.first: 2,
      _State.second: 1,
      _State.third: 3,
    });
    expect(() => FloatingPointSort(a, b, metaA: first, metaB: second),
        throwsA(isA<RohdHclException>()));
    final codec = LogicValueCodec<_PacketValue>(
        decode: (bits) => (bits: bits), encode: (value) => value.bits);
    final otherCodec = LogicValueCodec<_PacketValue>(
        decode: (bits) => (bits: bits), encode: (value) => value.bits);
    expect(
        () => FloatingPointSort(a, b,
            metaA: TypedLogicArray<_Packet, _PacketValue>([2], _Packet.new,
                valueCodec: codec),
            metaB: TypedLogicArray<_Packet, _PacketValue>([2], _Packet.new,
                valueCodec: otherCodec)),
        throwsA(isA<RohdHclException>()));
  });

  test('floating-point swap without metadata keeps optional outputs absent',
      () {
    final sorter = FloatingPointSort<FloatingPoint32, _Packet>(
        FloatingPoint32(), FloatingPoint32());
    expect(sorter.outMetaA, isNull);
    expect(sorter.outMetaB, isNull);
    expect(sorter.outputs, isNot(contains('outMetaA')));
  });

  test('floating-point swaps reject incompatible formats of the same width',
      () {
    final a = FloatingPoint(exponentWidth: 3, mantissaWidth: 3);
    final differentLayout = FloatingPoint(exponentWidth: 2, mantissaWidth: 4);
    final differentSemantics = FloatingPoint(
        exponentWidth: 3, mantissaWidth: 3, subNormalAsZero: true);
    expect(() => FloatingPointConditionalSwap(a, differentLayout, Logic()),
        throwsA(isA<RohdHclException>()));
    expect(() => FloatingPointSort(a, differentSemantics),
        throwsA(isA<RohdHclException>()));
    expect(() => FloatingPointSortByExp(a, differentSemantics),
        throwsA(isA<RohdHclException>()));
    expect(() => FloatingPointUtilities.sort((a, differentSemantics)),
        throwsA(isA<RohdHclException>()));
    expect(() => FloatingPointUtilities.sortByExp((a, differentSemantics)),
        throwsA(isA<RohdHclException>()));
    expect(() => FloatingPointUtilities.sort((a, differentLayout)),
        throwsA(isA<RohdHclException>()));
  });

  test('floating-point sort utility retains its static subtype', () {
    final a = FloatingPoint32()
      ..put(FloatingPoint32Value.populator().ofDouble(1));
    final b = FloatingPoint32()
      ..put(FloatingPoint32Value.populator().ofDouble(2));
    // ignore: omit_local_variable_types, verifies static payload type
    final FloatingPoint32 larger =
        FloatingPointUtilities.sort((a, b)).sorted.$1;
    // ignore: omit_local_variable_types, verifies static payload type
    final FloatingPoint32 smaller =
        FloatingPointUtilities.sortByExp((a, b)).sorted.$2;
    expect(larger.floatingPointValue.toDouble(), 2);
    expect(smaller.floatingPointValue.toDouble(), 1);
  });
}
