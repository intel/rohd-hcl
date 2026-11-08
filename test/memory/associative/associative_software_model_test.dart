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

void main() {
  tearDown(Simulator.reset);

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
          AssociativeMatcher(query: query, storedKeys: keys, validMask: valid);
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
        2, (_) => AssociativeUpdatePortInterface(keyWidth: 4, indexWidth: 2));
    final lookups = List.generate(
        2,
        (_) => AssociativeLookupPortInterface(
            keyWidth: 4, indexWidth: 2, matchEntryCount: 3));
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
