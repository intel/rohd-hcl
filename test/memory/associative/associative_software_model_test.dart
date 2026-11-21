// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// associative_software_model_test.dart
// Tests clock-stepped associative software models.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/memory/associative/associative_match_selector.dart'
    as general;
import 'package:rohd_hcl/memory/associative/associative_matcher.dart'
    as general;
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

AssociativeMemoryRequest _config({
  int keyWidth = 4,
  int indexWidth = 2,
  int lookupLatency = 0,
  int updateLatency = 0,
  AssociativeMatchSelection selection = AssociativeMatchSelection.lowestIndex,
  AssociativeMatchMode mode = AssociativeMatchMode.exact,
  AssociativeDuplicateKeyPolicy duplicates =
      AssociativeDuplicateKeyPolicy.allow,
  AssociativeLookupUpdatePolicy visibility =
      AssociativeLookupUpdatePolicy.lookupAfterUpdate,
  AssociativeUpdateCollisionPolicy collision =
      AssociativeUpdateCollisionPolicy.highestPortWins,
}) =>
    AssociativeMemoryRequest(
      keyWidth: keyWidth,
      indexWidth: indexWidth,
      entryCount: 3,
      updatePortCount: 2,
      lookupPortCount: 2,
      lookupLatency: lookupLatency,
      updateLatency: updateLatency,
      duplicateKeyPolicy: duplicates,
      matchSelection: selection,
      resultShape: AssociativeResultShape.matchVectorAndSelectedIndex,
      matchMode: mode,
      lookupUpdatePolicy: visibility,
      updateCollisionPolicy: collision,
      requiredResetBehavior: AssociativeMemoryResetBehavior.clearValidity,
    );

LogicValue _v(int value) => LogicValue.ofInt(value, 4);
AssociativeSoftwareLookup _query(int key) =>
    AssociativeSoftwareLookup(key: _v(key));
AssociativeSoftwareUpdate _write(int index, int key, {bool valid = true}) =>
    AssociativeSoftwareUpdate(
        index: index, key: _v(key), valid: LogicValue.ofBool(valid));

class _Key extends LogicStructure {
  _Key({String name = 'key', String secondName = 'second'})
      : super([Logic(name: 'first', width: 2), Logic(name: secondName)],
            name: name);

  Logic get first => elements[0];
  Logic get second => elements[1];

  @override
  _Key clone({String? name}) =>
      _Key(name: name ?? this.name, secondName: second.name);
}

class _NamedKey extends LogicStructure {
  final String suffix;

  _NamedKey({String name = 'key', this.suffix = 'bits'})
      : super([Logic(name: '${name}_$suffix', width: 4)], name: name);

  @override
  _NamedKey clone({String? name}) =>
      _NamedKey(name: name ?? this.name, suffix: suffix);
}

enum _Priority { low, high }

LogicEnum<_Priority> _priority({String? name}) =>
    LogicEnum.withMapping({_Priority.high: 2, _Priority.low: 1},
        width: 2, name: name);

class _EnumKey extends LogicStructure {
  _EnumKey({String? name})
      : super([_priority(name: 'priority'), Logic(name: 'tag')],
            name: name ?? 'enumKey');

  LogicEnum<_Priority> get priority => elements.first as LogicEnum<_Priority>;

  @override
  _EnumKey clone({String? name}) => _EnumKey(name: name ?? this.name);
}

class _EnumSelectorHarness extends Module {
  _EnumSelectorHarness({required bool nested}) {
    final inputs = List.generate(
        2,
        (index) => addInput('value$index', Logic(width: nested ? 3 : 2),
            width: nested ? 3 : 2));
    final matches = addInput('matchMask', Logic(width: 2), width: 2);
    final general.AssociativeMatchSelector selector;
    if (nested) {
      selector = general.AssociativeMatchSelector<_EnumKey>(
        matchVector: matches,
        selectionValues: [
          _EnumKey()..gets(inputs[0]),
          _EnumKey()..gets(inputs[1]),
        ],
        preference: (
                {required candidateValue,
                required selectedValue,
                required candidateIndex,
                required selectedIndex,
                required name}) =>
            candidateValue.priority.lt(selectedValue.priority),
      );
    } else {
      selector = general.AssociativeMatchSelector<LogicEnum<_Priority>>(
        matchVector: matches,
        selectionValues: [
          _priority()..gets(inputs[0]),
          _priority()..gets(inputs[1]),
        ],
      );
    }
    addOutput('valid') <= selector.valid;
    addOutput('index') <= selector.selectedIndex;
    addOutput('oneHot', width: 2) <= selector.selectedOneHot;
  }
}

class _SignedSelectorHarness extends Module {
  _SignedSelectorHarness() {
    final values = List.generate(2, (index) {
      final bits = addInput('value$index', Logic(width: 4), width: 4);
      return FixedPoint(integerWidth: 2, fractionWidth: 1)..gets(bits);
    });
    final selector = general.AssociativeMatchSelector<FixedPoint>(
      matchVector: addInput('matchMask', Logic(width: 2), width: 2),
      selectionValues: values,
    );
    addOutput('valid') <= selector.valid;
    addOutput('index') <= selector.selectedIndex;
    addOutput('oneHot', width: 2) <= selector.selectedOneHot;
  }
}

FixedPoint _constantPriority(int integer) =>
    FixedPoint.constant(FixedPointValue.withSignedness(
        integer: LogicValue.ofInt(integer, 3),
        fraction: LogicValue.ofInt(0, 1)));

class _ConstantAssociativeHarness extends Module {
  late final general.AssociativeMatcher<Logic> matcher;
  late final general.AssociativeMatchSelector<Logic> selector;

  _ConstantAssociativeHarness() {
    final mask = addInput('mask', Logic(width: 2), width: 2);
    final values = [_constantPriority(1), _constantPriority(7)];
    matcher = general.AssociativeMatcher<Logic>(
      query: _constantPriority(7),
      storedKeys: values,
      validMask: mask,
      comparator: (
          {required query, required stored, required index, required name}) {
        expect(query, isA<FixedPoint>());
        expect(stored, isA<FixedPoint>());
        return query.eq(stored);
      },
    );
    selector = general.AssociativeMatchSelector<Logic>(
      matchVector: mask,
      selectionValues: values,
      preference: (
          {required candidateValue,
          required selectedValue,
          required candidateIndex,
          required selectedIndex,
          required name}) {
        expect(candidateValue, isA<FixedPoint>());
        expect(selectedValue, isA<FixedPoint>());
        return candidateValue.lt(selectedValue);
      },
    );
    addOutput('matchBits', width: 2) <= matcher.matchVector;
    addOutput('valid') <= selector.valid;
    addOutput('index') <= selector.selectedIndex;
    addOutput('oneHot', width: 2) <= selector.selectedOneHot;
  }
}

void main() {
  tearDown(Simulator.reset);

  test('typed associative paths accept parent-renamed payloads', () async {
    final first = _NamedKey(name: 'firstKey');
    final second = _NamedKey(name: 'secondKey');
    final matcher = general.AssociativeMatcher<_NamedKey>(
        query: first, storedKeys: [second], validMask: Logic());
    await matcher.build();
    final matchVectors = [
      Vector({'query': 3, 'storedKey_0': 3, 'validMask': 1},
          {'matchVector': 1, 'hit': 1, 'multipleMatches': 0}),
      Vector({'storedKey_0': 2}, {'matchVector': 0, 'hit': 0}),
    ];
    await SimCompare.checkFunctionalVector(matcher, matchVectors);
    SimCompare.checkIverilogVector(matcher, matchVectors);
    await Simulator.reset();

    final selector = general.AssociativeMatchSelector<_NamedKey>(
        matchVector: Logic(width: 2), selectionValues: [first, second]);
    await selector.build();
    final selectionVectors = [
      Vector({'matchVector': 3, 'selectionValue_0': 12, 'selectionValue_1': 3},
          {'valid': 1, 'selectedIndex': 1, 'selectedOneHot': 2}),
      Vector({'selectionValue_0': 1},
          {'valid': 1, 'selectedIndex': 0, 'selectedOneHot': 1}),
    ];
    await SimCompare.checkFunctionalVector(selector, selectionVectors);
    SimCompare.checkIverilogVector(selector, selectionVectors);

    final incompatible = _NamedKey(name: 'otherKey', suffix: 'other');
    expect(
        () => general.AssociativeMatcher<_NamedKey>(
            query: first, storedKeys: [incompatible], validMask: Logic()),
        throwsArgumentError);
    expect(
        () => general.AssociativeMatchSelector<_NamedKey>(
            matchVector: Logic(width: 2),
            selectionValues: [first, incompatible]),
        throwsArgumentError);
  });

  test('typed associative components preserve widened constant structures',
      () async {
    final dut = _ConstantAssociativeHarness();
    expect(dut.matcher.input('query'), isA<FixedPoint>());
    expect(dut.matcher.input('storedKey_0'), isA<FixedPoint>());
    expect(dut.selector.input('selectionValue_0'), isA<FixedPoint>());
    final vectors = [
      Vector(
          {'mask': 0}, {'matchBits': 0, 'valid': 0, 'index': 0, 'oneHot': 0}),
      Vector(
          {'mask': 1}, {'matchBits': 0, 'valid': 1, 'index': 0, 'oneHot': 1}),
      Vector(
          {'mask': 2}, {'matchBits': 2, 'valid': 1, 'index': 1, 'oneHot': 2}),
      Vector(
          {'mask': 3}, {'matchBits': 2, 'valid': 1, 'index': 1, 'oneHot': 2}),
      Vector({
        'mask': LogicValue.ofString('x0')
      }, {
        'matchBits': LogicValue.ofString('x0'),
        'valid': LogicValue.x,
        'index': LogicValue.x,
        'oneHot': LogicValue.ofString('xx'),
      }),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('typed associative constant schemas retain format validation', () {
    final constant = _constantPriority(1);
    final matching = FixedPoint(integerWidth: 2, fractionWidth: 1);
    final incompatible =
        FixedPoint(integerWidth: 3, fractionWidth: 1, signed: false);
    final matcher = general.AssociativeMatcher<Logic>(
        query: constant, storedKeys: [matching], validMask: Logic());
    final selector = general.AssociativeMatchSelector<Logic>(
        matchVector: Logic(width: 2), selectionValues: [constant, matching]);
    expect(matcher.input('query'), isA<FixedPoint>());
    expect(selector.input('selectionValue_0'), isA<FixedPoint>());
    expect(
        () => general.AssociativeMatcher<Logic>(
            query: constant, storedKeys: [incompatible], validMask: Logic()),
        throwsArgumentError);
    expect(
        () => general.AssociativeMatchSelector<Logic>(
            matchVector: Logic(width: 2),
            selectionValues: [constant, incompatible]),
        throwsArgumentError);
  });

  test('typed selector compares structured fields and preserves its ports',
      () async {
    final values = List.generate(3, (_) => _Key());
    final matches = Logic(width: 3)..put(7);
    final selector = general.AssociativeMatchSelector<_Key>(
      matchVector: matches,
      selectionValues: values,
      selectionName: 'first',
      preference: (
              {required candidateValue,
              required selectedValue,
              required candidateIndex,
              required selectedIndex,
              required name}) =>
          candidateValue.first.lt(selectedValue.first),
    );
    expect(selector.input('selectionValue_0'), isA<_Key>());
    for (var index = 0; index < values.length; index++) {
      values[index].first.put([2, 1, 1][index]);
      values[index].second.put(index == 0 ? 0 : 1);
    }
    expect(selector.valid.value, LogicValue.one);
    expect(selector.selectedIndex.value, LogicValue.ofInt(1, 2));
    expect(selector.selectedOneHot.value, LogicValue.ofInt(2, 3));
    matches.put(4);
    expect(selector.selectedIndex.value, LogicValue.ofInt(2, 2));
    matches.put(0);
    expect(selector.valid.value, LogicValue.zero);
    expect(selector.selectedOneHot.value, LogicValue.ofInt(0, 3));
    await selector.build();
    expect(selector.dumpSystemVerilog(), contains('module AssociativeMatch'));
  });

  test('typed selector uses signed fixed-point ordering and checks formats',
      () {
    final values =
        List.generate(2, (_) => FixedPoint(integerWidth: 2, fractionWidth: 1));
    final selector = general.AssociativeMatchSelector<FixedPoint>(
      matchVector: Logic(width: 2)..put(3),
      selectionValues: values,
    );
    values[0].integer.put(1);
    values[1].integer.put(7);
    for (final value in values) {
      value.fraction.put(0);
    }
    expect(selector.input('selectionValue_0'), isA<FixedPoint>());
    expect(selector.selectedIndex.value, LogicValue.one);
    expect(
      () => general.AssociativeMatchSelector<FixedPoint>(
        matchVector: Logic(width: 2),
        selectionValues: [
          values[0],
          FixedPoint(integerWidth: 3, fractionWidth: 1, signed: false),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => general.AssociativeMatchSelector<_Key>(
        matchVector: Logic(width: 2),
        selectionValues: [_Key(), _Key(secondName: 'other')],
      ),
      throwsArgumentError,
    );
  });

  test('typed signed selection agrees with generated Verilog', () async {
    final dut = _SignedSelectorHarness();
    final vectors = [
      Vector({'matchMask': 3, 'value0': 2, 'value1': 14},
          {'valid': 1, 'index': 1, 'oneHot': 2}),
      Vector(
          {'value0': 12, 'value1': 2}, {'valid': 1, 'index': 0, 'oneHot': 1}),
      Vector(
          {'value0': 14, 'value1': 14}, {'valid': 1, 'index': 0, 'oneHot': 1}),
      Vector({'matchMask': 2}, {'valid': 1, 'index': 1, 'oneHot': 2}),
      Vector({'matchMask': 0}, {'valid': 0, 'index': 0, 'oneHot': 0}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  for (final nested in [false, true]) {
    test('typed selection accepts nonzero enum encodings nested=$nested',
        () async {
      final dut = _EnumSelectorHarness(nested: nested);
      final vectors = [
        Vector({'matchMask': 3, 'value0': 2, 'value1': 1},
            {'valid': 1, 'index': 1, 'oneHot': 2}),
        Vector(
            {'value0': 1, 'value1': 2}, {'valid': 1, 'index': 0, 'oneHot': 1}),
        Vector({'matchMask': 2}, {'valid': 1, 'index': 1, 'oneHot': 2}),
        Vector({
          'matchMask': LogicValue.ofString('x0')
        }, {
          'valid': LogicValue.x,
          'index': LogicValue.x,
          'oneHot': LogicValue.ofString('xx')
        }),
        Vector({'matchMask': 0}, {'valid': 0, 'index': 0, 'oneHot': 0}),
      ];
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  test('selector initializes enum array leaves with their lowest encoding', () {
    TypedLogicArray<LogicEnum<_Priority>, LogicValue> schema() =>
        TypedLogicArray<LogicEnum<_Priority>, LogicValue>([2], _priority);
    TypedLogicArray<LogicEnum<_Priority>, LogicValue>? initial;
    final selector = general.AssociativeMatchSelector(
      matchVector: Logic(width: 2)..put(0),
      selectionValues: [schema(), schema()],
      preference: (
          {required candidateValue,
          required selectedValue,
          required candidateIndex,
          required selectedIndex,
          required name}) {
        if (candidateIndex == 0) {
          initial = selectedValue;
        }
        return candidateValue.arrayElements.first
            .lt(selectedValue.arrayElements.first);
      },
    );
    expect(initial!.arrayElements.map((element) => element.value),
        [LogicValue.ofInt(1, 2), LogicValue.ofInt(1, 2)]);
    expect(selector.valid.value, LogicValue.zero);
    expect(selector.selectedIndex.value, LogicValue.zero);
  });

  test('typed scalar selector retains flat selector four-state behavior', () {
    final matches = Logic(width: 2);
    final values = List.generate(2, (_) => Logic(width: 2));
    final typed = general.AssociativeMatchSelector<Logic>(
        matchVector: matches, selectionValues: values);
    final flat =
        // Exercise the compatibility selector's original packed behavior.
        // ignore: deprecated_member_use_from_same_package
        AssociativeMatchSelector(matchVector: matches, selectionValues: values);
    for (final mask in ['00', '01', '11', 'x1', '1x', 'xx']) {
      matches.put(LogicValue.ofString(mask));
      for (final first in ['00', '01', 'x0', 'zz']) {
        values[0].put(LogicValue.ofString(first));
        for (final second in ['00', '10', '1x', 'zz']) {
          values[1].put(LogicValue.ofString(second));
          expect(typed.valid.value, flat.valid.value);
          expect(typed.selectedIndex.value, flat.selectedIndex.value,
              reason: '$mask $first $second');
          expect(typed.selectedOneHot.value, flat.selectedOneHot.value,
              reason: '$mask $first $second');
        }
      }
    }
  });

  test('typed matcher retains structured keys for custom comparisons',
      () async {
    final query = _Key();
    final stored = [_Key(), _Key()];
    final valid = Logic(width: 2)..put(3);
    final matcher = general.AssociativeMatcher<_Key>(
      query: query,
      storedKeys: stored,
      validMask: valid,
      comparisonName: 'first',
      comparator: (
              {required query,
              required stored,
              required index,
              required name}) =>
          query.first.eq(stored.first),
    );
    expect(matcher.input('query'), isA<_Key>());
    expect(matcher.input('storedKey_0'), isA<_Key>());
    query.first.put(2);
    stored[0].first.put(2);
    stored[1].first.put(1);
    expect(matcher.matchVector.value, LogicValue.ofInt(1, 2));
    await matcher.build();
    expect(matcher.dumpSystemVerilog(), contains('module AssociativeMatcher'));
  });

  test('typed matcher checks key shape and retains exact four-state matching',
      () {
    final query = _Key();
    expect(
      () => general.AssociativeMatcher<_Key>(
        query: query,
        storedKeys: [_Key(secondName: 'other')],
        validMask: Logic(),
      ),
      throwsArgumentError,
    );
    final stored = _Key();
    final matcher = general.AssociativeMatcher<_Key>(
      query: query,
      storedKeys: [stored],
      validMask: Logic()..put(1),
    );
    query.first.put(0);
    query.second.put(LogicValue.x);
    stored.first.put(1);
    stored.second.put(LogicValue.x);
    expect(matcher.hit.value, LogicValue.zero);
    stored.first.put(0);
    expect(matcher.hit.value, LogicValue.x);
  });

  test('legacy matcher keeps flattened key ports', () {
    // Verify the compatibility API rather than the typed replacement.
    // ignore: deprecated_member_use_from_same_package
    final matcher = AssociativeMatcher(
      query: _Key(),
      storedKeys: [_Key()],
      validMask: Logic(),
    );
    expect(matcher.input('query'), isNot(isA<LogicStructure>()));
    expect(matcher.input('storedKey_0'), isNot(isA<LogicStructure>()));
  });

  for (final visibility in [
    AssociativeLookupUpdatePolicy.lookupBeforeUpdate,
    AssociativeLookupUpdatePolicy.lookupAfterUpdate
  ]) {
    for (final collision in [
      AssociativeUpdateCollisionPolicy.lowestPortWins,
      AssociativeUpdateCollisionPolicy.highestPortWins
    ]) {
      test('wide masked pipeline snapshot $visibility $collision', () {
        const width = 80;
        LogicValue wide(BigInt value) => LogicValue.ofBigInt(value, width);
        final high = wide((BigInt.one << 79) | (BigInt.one << 64) | BigInt.one);
        final low = wide(BigInt.one);
        final fullMask = wide((BigInt.one << width) - BigInt.one);
        final model = AssociativeSoftwareModel(_config(
          keyWidth: width,
          indexWidth: width,
          lookupLatency: 1,
          updateLatency: 1,
          visibility: visibility,
          collision: collision,
          mode: AssociativeMatchMode.masked,
        ))
          ..step(lookups: [
            null,
            null
          ], updates: [
            AssociativeSoftwareUpdate(
                index: 1, key: high, valid: LogicValue.one),
            AssociativeSoftwareUpdate(
                index: 1, key: low, valid: LogicValue.one),
          ]);
        final saved = model.snapshotExecution();
        final lookups = [
          AssociativeSoftwareLookup(key: high, mask: fullMask),
          AssociativeSoftwareLookup(key: low, mask: fullMask),
        ];
        List<AssociativeSoftwareResult?> complete() {
          expect(model.step(lookups: lookups, updates: [null, null]),
              [null, null]);
          return model.step(lookups: [null, null], updates: [null, null]);
        }

        final results = complete();
        final before =
            visibility == AssociativeLookupUpdatePolicy.lookupBeforeUpdate;
        final lowPortWins =
            collision == AssociativeUpdateCollisionPolicy.lowestPortWins;
        expect(results[0]!.hit, LogicValue.ofBool(!before && lowPortWins));
        expect(results[1]!.hit, LogicValue.ofBool(!before && !lowPortWins));
        expect(model.entry(1).key, lowPortWins ? high : low);
        expect(model.peekBigInt(BigInt.one), lowPortWins ? high : low);
        expect(() => model.peekBigInt((BigInt.one << 75) | BigInt.one),
            throwsRangeError);

        model.restoreExecution(saved);
        expect(complete(), results);
        final masked = AssociativeSoftwareLookup(key: low, mask: low);
        model.step(lookups: [masked, null], updates: [null, null]);
        final match =
            model.step(lookups: [null, null], updates: [null, null]).first!;
        expect(match.hit, LogicValue.one);
        expect(match.index.toBigInt(), BigInt.one);
        expect(match.matchVector, LogicValue.ofInt(2, 3));
      });
    }
  }

  for (final selection in AssociativeMatchSelection.values) {
    test('four-state exact selection agrees with RTL: ${selection.name}', () {
      final model = AssociativeSoftwareModel(_config(selection: selection));
      final keys = List.generate(3, (_) => Logic(width: 4));
      final valid = Logic(width: 3);
      final query = Logic(width: 4);
      final matcher =
          // Exercise the compatibility matcher against the software model.
          // ignore: deprecated_member_use_from_same_package
          AssociativeMatcher(query: query, storedKeys: keys, validMask: valid);
      // Exercise the compatibility selector against the software model.
      // ignore: deprecated_member_use_from_same_package
      final selector = AssociativeMatchSelector(
        matchVector: matcher.matchVector,
        preference: selection == AssociativeMatchSelection.lowestIndex
            ? lowerAssociativeSelectionValue
            : higherAssociativeSelectionValue,
      );
      final rtlIndex =
          mux(matcher.hit, selector.selectedIndex, Const(0, width: 2));
      final values = [
        for (final text in ['0000', '1010', '10x0', '1z01', 'xxxx'])
          LogicValue.ofString(text)
      ];
      final validValues = [LogicValue.zero, LogicValue.one, LogicValue.x];
      final random = Random(123);
      for (var sample = 0; sample < 200; sample++) {
        final validity = <LogicValue>[];
        for (var index = 0; index < 3; index++) {
          final key = values[random.nextInt(values.length)];
          final bit = validValues[random.nextInt(validValues.length)];
          model.writeEntry(index, key: key, valid: bit);
          keys[index].put(model.entry(index).key);
          validity.add(bit);
        }
        valid.put(LogicValue.of(validity));
        final key = values[random.nextInt(values.length)];
        query.put(key);
        final result = model.step(
            lookups: [AssociativeSoftwareLookup(key: key), null],
            updates: [null, null])[0]!;
        expect(result.matchVector, matcher.matchVector.value,
            reason: '$sample');
        expect(result.hit, matcher.hit.value, reason: '$sample');
        expect(result.index, rtlIndex.value, reason: '$sample');
      }
    });
  }

  test('multiport updates and lookups agree with the parallel RTL', () async {
    final clk = Logic()..put(0);
    final reset = Logic()..put(0);
    final updates = List.generate(
        2,
        (_) => TypedAssociativeUpdatePortInterface(Logic(width: 4),
            indexWidth: 2));
    final lookups = List.generate(
        2,
        (_) => TypedAssociativeLookupPortInterface(Logic(width: 4),
            indexWidth: 2, matchEntryCount: 3));
    for (final update in updates) {
      update
        ..en.put(0)
        ..index.put(0)
        ..key.put(0)
        ..entryValid.put(0);
    }
    for (final lookup in lookups) {
      lookup
        ..en.put(1)
        ..key.put(0);
    }
    final memory = ParallelAssociativeMemory(
      clk: clk,
      reset: reset,
      updates: updates,
      lookups: lookups,
      entryCount: 3,
      contract: const AssociativeMemoryContract(
        lookupLatency: 0,
        updateLatency: 0,
        duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
        matchSelection: AssociativeMatchSelection.highestIndex,
        resultShape: AssociativeResultShape.matchVectorAndSelectedIndex,
        lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
        updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
        resetBehavior: AssociativeMemoryResetBehavior.clearValidity,
        implementationKind: AssociativeMemoryImplementationKind.synthesizable,
      ),
    );
    await memory.build();
    final model = AssociativeSoftwareModel(
        _config(selection: AssociativeMatchSelection.highestIndex));
    final random = Random(444);
    final values = [
      for (final text in ['0000', '1010', '10x0', '1z01', 'xxxx'])
        LogicValue.ofString(text)
    ];
    Simulator.registerAction(1, () => reset.put(1));
    Simulator.registerAction(2, () => clk.put(1));
    Simulator.registerAction(3, () => clk.put(0));
    Simulator.registerAction(4, () => reset.put(0));
    for (var cycle = 0; cycle < 100; cycle++) {
      final requests = List<AssociativeSoftwareUpdate?>.generate(2, (_) {
        if (random.nextBool()) {
          return null;
        }
        return AssociativeSoftwareUpdate(
            index: random.nextInt(3),
            key: values[random.nextInt(values.length)],
            valid: LogicValue.ofBool(random.nextBool()));
      });
      final queries = List.generate(
          2,
          (_) => AssociativeSoftwareLookup(
              key: values[random.nextInt(values.length)]));
      final time = 5 + cycle * 4;
      Simulator.registerAction(time, () {
        clk.put(0);
        for (var port = 0; port < 2; port++) {
          final request = requests[port];
          updates[port].en.put(request == null ? 0 : 1);
          if (request != null) {
            updates[port]
              ..index.put(request.index)
              ..key.put(request.key)
              ..entryValid.put(request.valid);
          }
          lookups[port].key.put(queries[port].key);
        }
      });
      Simulator.registerAction(time + 1, () => clk.put(1));
      Simulator.registerAction(time + 2, () {
        final results = model.step(lookups: queries, updates: requests);
        for (var port = 0; port < 2; port++) {
          expect(lookups[port].hit.value, results[port]!.hit,
              reason: 'cycle $cycle, port $port');
          expect(lookups[port].index.value, results[port]!.index,
              reason: 'cycle $cycle, port $port');
          expect(lookups[port].matchVector!.value, results[port]!.matchVector,
              reason: 'cycle $cycle, port $port');
        }
      });
    }
    await Simulator.run();
  });

  test('simultaneous updates, priority, and lookup visibility', () {
    for (final policy in [
      AssociativeLookupUpdatePolicy.lookupBeforeUpdate,
      AssociativeLookupUpdatePolicy.lookupAfterUpdate
    ]) {
      final model = AssociativeSoftwareModel(_config(visibility: policy));
      final result = model.step(
          lookups: [_query(5), _query(6)],
          updates: [_write(1, 5), _write(1, 6)]);
      expect(model.peek(1), _v(6));
      expect(result[0]!.hit, LogicValue.zero);
      expect(
          result[1]!.hit,
          policy == AssociativeLookupUpdatePolicy.lookupAfterUpdate
              ? LogicValue.one
              : LogicValue.zero);
      expect(
          result[1]!.index,
          LogicValue.ofInt(
              policy == AssociativeLookupUpdatePolicy.lookupAfterUpdate ? 1 : 0,
              2));
    }
  });

  test('masked and context-qualified matching are explicit', () {
    final model =
        AssociativeSoftwareModel(_config(mode: AssociativeMatchMode.masked))
          ..poke(2, _v(0xa));
    final result = model.step(lookups: [
      AssociativeSoftwareLookup(key: _v(0xb), mask: _v(0xe)),
      AssociativeSoftwareLookup(
          key: LogicValue.ofString('10x0'), mask: _v(0xd)),
    ], updates: [
      null,
      null
    ]);
    expect(result[0]!.matchVector, LogicValue.ofInt(4, 3));
    expect(result[1]!.hit, LogicValue.one);
    expect(() => model.step(lookups: [_query(1), null], updates: [null, null]),
        throwsArgumentError);
    expect(
        () => AssociativeSoftwareModel(
            _config(mode: AssociativeMatchMode.contextQualified)),
        throwsArgumentError);
    final qualified = AssociativeSoftwareModel(
        _config(mode: AssociativeMatchMode.contextQualified),
        matcher: ({required lookup, required storedKey, required index}) =>
            lookup.key.eq(storedKey) & lookup.context!)
      ..poke(0, _v(3));
    final denied = qualified.step(lookups: [
      AssociativeSoftwareLookup(key: _v(3), context: LogicValue.zero),
      AssociativeSoftwareLookup(key: _v(3), context: LogicValue.one),
    ], updates: [
      null,
      null
    ]);
    expect(denied[0]!.hit, LogicValue.zero);
    expect(denied[1]!.hit, LogicValue.one);
  });

  test('masked equality retains definite mismatches despite unknown bits', () {
    final model =
        AssociativeSoftwareModel(_config(mode: AssociativeMatchMode.masked))
          ..poke(0, _v(0));
    AssociativeSoftwareResult lookup(String key, String mask) =>
        model.step(lookups: [
          AssociativeSoftwareLookup(
              key: LogicValue.ofString(key), mask: LogicValue.ofString(mask)),
          null
        ], updates: [
          null,
          null
        ]).first!;
    expect(lookup('1x00', '1111').hit, LogicValue.zero);
    expect(lookup('0x00', '1111').hit, LogicValue.x);
    expect(lookup('0x00', '1011').hit, LogicValue.one);
  });

  test('duplicate validation distinguishes definite and possible mismatches',
      () {
    final model = AssociativeSoftwareModel(
        _config(duplicates: AssociativeDuplicateKeyPolicy.disallow))
      ..poke(0, LogicValue.ofString('0x00'))
      ..poke(1, LogicValue.ofString('1000'))
      ..poke(2, LogicValue.ofString('0z01'));
    final before = model.snapshot().entries;
    expect(() => model.poke(2, _v(0)), throwsStateError);
    expect(model.snapshot().entries, before);
  });

  test('snapshots replay delayed reads and writes across compatible models',
      () {
    final config = _config(lookupLatency: 2, updateLatency: 2);
    final model = AssociativeSoftwareModel(config)
      ..poke(0, _v(1))
      ..step(lookups: [_query(1), null], updates: [_write(1, 2), null]);
    final image = model.snapshotExecution();
    expect(() => model.poke(2, _v(4)), throwsStateError);
    expect(
        model.step(lookups: [null, null], updates: [null, null]), [null, null]);
    final result = model.step(lookups: [null, null], updates: [null, null]);
    expect(result[0]!.hit, LogicValue.one);
    expect(model.peek(1), _v(2));
    final restored = AssociativeSoftwareModel(config)..restoreExecution(image);
    expect(restored.step(lookups: [null, null], updates: [null, null]),
        [null, null]);
    expect(restored.step(lookups: [null, null], updates: [null, null]), result);
    expect(restored.snapshot().entries, model.snapshot().entries);
    final incompatible = AssociativeSoftwareModel(_config(lookupLatency: 1));
    expect(() => incompatible.restoreExecution(image), throwsArgumentError);
    expect(incompatible.cycle, 0);
  });

  test('duplicate and collision failures are atomic even for delayed writes',
      () {
    final model = AssociativeSoftwareModel(_config(
        updateLatency: 2,
        duplicates: AssociativeDuplicateKeyPolicy.disallow,
        collision: AssociativeUpdateCollisionPolicy.disallow));
    final before = model.snapshot();
    expect(
        () => model
            .step(lookups: [null, null], updates: [_write(0, 2), _write(0, 3)]),
        throwsStateError);
    expect(model.cycle, 0);
    expect(model.snapshot().entries, before.entries);
    model.step(lookups: [null, null], updates: [_write(0, 2), null]);
    expect(
        () => model.step(lookups: [null, null], updates: [_write(1, 2), null]),
        throwsStateError);
    expect(model.cycle, 1);
    model
      ..step(lookups: [null, null], updates: [null, null])
      ..step(lookups: [null, null], updates: [null, null]);
    expect(model.peek(0), _v(2));
    expect(model.peek(1), isNull);
  });

  test('raw image validation is atomic and reset cancels in-flight work', () {
    final model = AssociativeSoftwareModel(_config(lookupLatency: 3))
      ..poke(1, _v(7));
    final image = model.snapshot();
    expect(image.entries.clear, throwsUnsupportedError);
    final invalid = AssociativeSoftwareState(
        keyWidth: 4,
        entryCount: 3,
        entries: {
          0: (key: _v(3), valid: LogicValue.one),
          4: (key: _v(9), valid: LogicValue.one)
        });
    expect(() => model.load(invalid), throwsRangeError);
    expect(model.snapshot().entries, image.entries);
    model
      ..step(lookups: [_query(7), null], updates: [null, null])
      ..reset();
    expect(model.peek(1), isNull);
    for (var i = 0; i < 4; i++) {
      expect(model.step(lookups: [null, null], updates: [null, null]),
          [null, null]);
    }
  });

  test('raw overlay, replacement, and state transaction endpoint', () {
    final model = AssociativeSoftwareModel(_config())
      ..poke(0, _v(3))
      ..poke(2, _v(9));
    final partial = AssociativeSoftwareState(
        keyWidth: 4,
        entryCount: 3,
        entries: {1: (key: _v(7), valid: LogicValue.one)});
    model.load(partial);
    expect(
        [model.peek(0), model.peek(1), model.peek(2)], [_v(3), _v(7), _v(9)]);
    final endpoint = model.stateTransactions;
    final completion = endpoint.transact(
        StateTransactionRequest<AssociativeSoftwareExecutionImage>.snapshot(
            transactionId: 7));
    model.load(partial, replace: true);
    expect([model.peek(0), model.peek(1), model.peek(2)], [null, _v(7), null]);
    endpoint.transact(
        StateTransactionRequest<AssociativeSoftwareExecutionImage>.restore(
            transactionId: 8, image: completion.image!));
    expect(
        [model.peek(0), model.peek(1), model.peek(2)], [_v(3), _v(7), _v(9)]);
  });
}
