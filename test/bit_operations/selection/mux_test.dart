// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// mux_test.dart
// Tests for OneHotMux and PriorityMux.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Payload extends LogicStructure {
  _Payload({String name = 'payload', String tagName = 'tag'})
      : super([Logic(name: tagName, width: 2), Logic(name: 'value', width: 2)],
            name: name);

  @override
  _Payload clone({String? name}) =>
      _Payload(name: name ?? this.name, tagName: elements.first.name);
}

class _MisclonedField extends GfLogic {
  final BinaryExtensionField cloneField;

  _MisclonedField(super.field, this.cloneField, {super.name});

  @override
  _MisclonedField clone({String? name}) =>
      _MisclonedField(cloneField, cloneField, name: name ?? this.name);
}

class _SecondCloneField extends GfLogic {
  final BinaryExtensionField replacement;
  final bool preserveNext;

  _SecondCloneField(super.field, this.replacement,
      {this.preserveNext = true, super.name});

  @override
  _SecondCloneField clone({String? name}) =>
      _SecondCloneField(preserveNext ? field : replacement, replacement,
          preserveNext: false, name: name ?? this.name);
}

class _MisclonedRecord extends LogicStructure {
  final BinaryExtensionField cloneField;

  _MisclonedRecord(BinaryExtensionField field, this.cloneField,
      {bool constant = true, String? name})
      : super([
          if (constant) Const(1) else Logic(name: 'flag'),
          GfLogic(field, name: 'field'),
        ], name: name ?? 'record');

  @override
  _MisclonedRecord clone({String? name}) =>
      _MisclonedRecord(cloneField, cloneField,
          constant: false, name: name ?? this.name);
}

class _ErasedRecord extends LogicStructure {
  _ErasedRecord({String? name})
      : super([Logic(name: 'value', width: 3)], name: name ?? 'record');

  @override
  LogicStructure clone({String? name}) =>
      LogicStructure([Logic(name: 'value', width: 3)], name: name ?? this.name);
}

FixedPoint _fixedConstant(int value) =>
    FixedPoint.constant(FixedPointValue.withSignedness(
        integer: LogicValue.ofInt(value >> 4, 4),
        fraction: LogicValue.ofInt(value & 0xf, 4)));

class _ConstantPriorityHarness extends Module {
  late final TypedPriorityMux<Logic> mux;

  _ConstantPriorityHarness() {
    mux = TypedPriorityMux<Logic>(
      addInput('sel', Logic(width: 2), width: 2),
      [_fixedConstant(0x12), _fixedConstant(0x34)],
      _fixedConstant(0x56),
    );
    addOutput('out', width: 8) <= mux.result;
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  const caseWidth = 4;
  const numCases = 3;
  // Overlapping bit patterns so the OR and the priority ordering both show.
  const cases = [0x3, 0xC, 0x6];

  test('OneHotMux ORs the cases whose selector bit is set', () async {
    final selector = Logic(name: 'selector', width: numCases);
    final inputs = [
      for (var i = 0; i < numCases; i++) Logic(name: 'case$i', width: caseWidth)
    ];
    final dut = OneHotMux(selector, inputs);
    await dut.build();

    // Every selector value: none set, each single bit, and all set.
    final vectors = [
      for (var sel = 0; sel < (1 << numCases); sel++)
        Vector({
          'selector': sel,
          for (var i = 0; i < numCases; i++) 'case$i': cases[i],
        }, {
          'result': [
            for (var i = 0; i < numCases; i++)
              if ((sel >> i) & 1 == 1) cases[i]
          ].fold(0, (a, b) => a | b),
        })
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
  });

  test('OneHotMux rejects invalid case and selector widths', () {
    expect(
      () => OneHotMux(Logic(), []),
      throwsA(predicate(
          (e) => e is Exception && e.toString().contains('At least one case'))),
    );
    expect(
      () => OneHotMux(Logic(width: 2), [Logic(width: 2), Logic(width: 3)]),
      throwsA(isA<Exception>()),
    );
    expect(
      () => OneHotMux(Logic(), [Logic(width: 2), Logic(width: 2)]),
      throwsA(isA<Exception>()),
    );
  });

  test('PriorityMux picks the lowest set selector bit, else the default',
      () async {
    const defaultValue = 0xE;
    final selector = Logic(name: 'selector', width: numCases);
    final inputs = [
      for (var i = 0; i < numCases; i++) Logic(name: 'case$i', width: caseWidth)
    ];
    final dflt = Logic(name: 'defaultValue', width: caseWidth);
    // Exercise the existing flat compatibility API.
    // ignore: deprecated_member_use_from_same_package
    final dut = PriorityMux(selector, inputs, dflt);
    await dut.build();

    final vectors = [
      for (var sel = 0; sel < (1 << numCases); sel++)
        Vector({
          'selector': sel,
          'defaultValue': defaultValue,
          for (var i = 0; i < numCases; i++) 'case$i': cases[i],
        }, {
          'result': sel == 0
              ? defaultValue
              : cases[[
                  for (var i = 0; i < numCases; i++)
                    if ((sel >> i) & 1 == 1) i
                ].first],
        })
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
  });

  test('typed priority mux preserves structured cases and result', () async {
    final selector = Logic(width: 2);
    final dut = TypedPriorityMux<_Payload>(
        selector, [_Payload(), _Payload()], _Payload());
    expect(dut.input('case0'), isA<_Payload>());
    expect(dut.input('defaultValue'), isA<_Payload>());
    expect(dut.result, isA<_Payload>());
    await dut.build();
    final vectors = [
      Vector({'selector': 0, 'case0': 3, 'case1': 12, 'defaultValue': 5},
          {'result': 5}),
      Vector({'selector': 2}, {'result': 12}),
      Vector({'selector': 3}, {'result': 3}),
      Vector({'selector': LogicValue.ofString('x0')},
          {'result': LogicValue.ofString('x10x')}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('typed priority mux rejects incompatible payload layouts', () {
    expect(
      () => TypedPriorityMux<_Payload>(
          Logic(), [_Payload(tagName: 'other')], _Payload()),
      throwsArgumentError,
    );
    expect(
      () => TypedPriorityMux<Logic>(Logic(), [_fixedConstant(0x12)],
          FixedPoint(integerWidth: 4, fractionWidth: 4, signed: false)),
      throwsArgumentError,
    );
  });

  test('typed priority mux accepts matching constant and driveable payloads',
      () {
    final dut = TypedPriorityMux<FixedPoint>(Logic(), [_fixedConstant(0x12)],
        FixedPoint(integerWidth: 3, fractionWidth: 4));
    expect(dut.input('case0'), isA<FixedPoint>());
    expect(dut.input('defaultValue'), isA<FixedPoint>());
    expect(dut.result, isA<FixedPoint>());
  });

  test('typed input registration rejects scalar clone metadata changes', () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    final scalar = _MisclonedField(first, second);
    expect(() => TypedPriorityMux<Logic>(Logic(), [scalar], scalar),
        throwsA(isA<PortTypeException>()));
  });

  test('typed priority mux rejects changed result clone metadata', () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    expect(
        () => TypedPriorityMux<Logic>(
            Logic(), [GfLogic(first)], _SecondCloneField(first, second)),
        throwsA(isA<LogicConstructionException>()));
  });

  test('typed input registration rejects structured clone metadata changes',
      () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    final structured = _MisclonedRecord(first, second);
    expect(() => TypedPriorityMux<Logic>(Logic(), [structured], structured),
        throwsA(isA<PortTypeException>()));
  });

  test('typed input registration rejects a clone that erases its type', () {
    final record = _ErasedRecord();
    expect(() => TypedPriorityMux<Logic>(Logic(), [record], record),
        throwsA(isA<PortTypeException>()));
  });

  test('typed priority mux retains constant structures widened to Logic',
      () async {
    final dut = _ConstantPriorityHarness();
    for (final port in [
      dut.mux.input('case0'),
      dut.mux.input('case1'),
      dut.mux.input('defaultValue'),
      dut.mux.result,
    ]) {
      expect(port, isA<FixedPoint>());
      final fixed = port as FixedPoint;
      expect(fixed.signed, isTrue);
      expect(fixed.integerWidth, 3);
      expect(fixed.fractionWidth, 4);
    }
    final vectors = [
      Vector({'sel': 0}, {'out': 0x56}),
      Vector({'sel': 1}, {'out': 0x12}),
      Vector({'sel': 2}, {'out': 0x34}),
      Vector({'sel': 3}, {'out': 0x12}),
      Vector({'sel': LogicValue.ofString('x0')},
          {'out': LogicValue.ofString('0xx101x0')}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('legacy priority mux keeps flat structured inputs and result', () {
    // Verify the compatibility API with structured caller signals.
    // ignore: deprecated_member_use_from_same_package
    final dut = PriorityMux(Logic(), [_Payload()], _Payload());
    expect(dut.input('case0'), isNot(isA<LogicStructure>()));
    expect(dut.result, isNot(isA<LogicStructure>()));
    expect(identical(dut.result, dut.output('result')), isTrue);
  });
}
