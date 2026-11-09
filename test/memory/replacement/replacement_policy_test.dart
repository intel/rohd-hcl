// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// replacement_policy_test.dart
// Reference and simulator tests for cache replacement policies.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Harness extends Module {
  _Harness(int count, {required bool tree, bool behavioral = false}) {
    final width = max(1, (count - 1).bitLength);
    final accesses = [
      for (var index = 0; index < 2; index++) ReplacementAccessInterface(count)
    ];
    final allocations = [
      for (var index = 0; index < 2; index++)
        ReplacementAllocationInterface(count)
    ];
    for (var index = 0; index < 2; index++) {
      accesses[index].en <= addInput('hitEn$index', Logic());
      accesses[index].index <=
          addInput('hitIndex$index', Logic(width: width), width: width);
      allocations[index].en <= addInput('allocEn$index', Logic());
      allocations[index].commit <= addInput('allocCommit$index', Logic());
    }
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final valid = addInput('valid', Logic(width: count), width: count);
    final eligible = addInput('eligible', Logic(width: count), width: count);
    final ReplacementPolicy policy;
    if (behavioral) {
      policy = BehavioralReplacementPolicy(
          clk: clk,
          reset: reset,
          validMask: valid,
          eligibleMask: eligible,
          accesses: accesses,
          allocations: allocations,
          entryCount: count,
          kind: tree
              ? BehavioralReplacementKind.treePseudoLru
              : BehavioralReplacementKind.roundRobin);
    } else if (tree) {
      policy = TreePseudoLruReplacement(
          clk: clk,
          reset: reset,
          validMask: valid,
          eligibleMask: eligible,
          accesses: accesses,
          allocations: allocations,
          entryCount: count);
    } else {
      policy = RoundRobinReplacement(
          clk: clk,
          reset: reset,
          validMask: valid,
          eligibleMask: eligible,
          accesses: accesses,
          allocations: allocations,
          entryCount: count);
    }
    addOutput('invalidAccess') <= policy.invalidAccess;
    addOutput('invalidCommit') <= policy.invalidCommit;
    for (var index = 0; index < 2; index++) {
      addOutput('grant$index') <= allocations[index].valid;
      addOutput('victim$index', width: width) <= allocations[index].index;
      addOutput('evict$index') <= allocations[index].evict;
    }
  }
}

class _Reference {
  final int count;
  final bool tree;
  late final List<int> bits = List.filled(max(1, count - 1), 0);
  int pointer = 0;

  _Reference(this.count, {required this.tree});

  void access(int index) {
    if (!tree || count == 1) {
      return;
    }
    var low = 0;
    var high = count;
    var node = 0;
    while (high - low > 1) {
      final middle = (low + high) ~/ 2;
      if (index < middle) {
        bits[node] = 1;
        high = middle;
        node = node * 2 + 1;
      } else {
        bits[node] = 0;
        low = middle;
        node = node * 2 + 2;
      }
    }
  }

  int select(Set<int> candidates) {
    if (!tree) {
      for (var offset = 0; offset < count; offset++) {
        final index = (pointer + offset) % count;
        if (candidates.contains(index)) {
          return index;
        }
      }
      throw StateError('Expected at least one candidate.');
    }
    var low = 0;
    var high = count;
    var node = 0;
    while (high - low > 1) {
      final middle = (low + high) ~/ 2;
      final leftAvailable =
          candidates.any((index) => index < middle && index >= low);
      final rightAvailable =
          candidates.any((index) => index >= middle && index < high);
      final right = rightAvailable && (bits[node] == 1 || !leftAvailable);
      if (right) {
        low = middle;
        node = node * 2 + 2;
      } else {
        high = middle;
        node = node * 2 + 1;
      }
    }
    return low;
  }

  Map<String, int> step({
    required int valid,
    required int eligible,
    required List<({bool en, int index})> hits,
    required List<bool> allocations,
    required List<bool> commits,
  }) {
    var invalid = false;
    for (final hit in hits) {
      if (hit.en) {
        if (hit.index >= count) {
          invalid = true;
        } else {
          access(hit.index);
        }
      }
    }
    final result = <String, int>{'invalidAccess': invalid ? 1 : 0};
    final reserved = <int>{};
    var invalidCommit = false;
    for (var port = 0; port < allocations.length; port++) {
      final available = {
        for (var index = 0; index < count; index++)
          if ((eligible & (1 << index)) != 0 && !reserved.contains(index)) index
      };
      final unused = {
        for (final index in available)
          if ((valid & (1 << index)) == 0) index
      };
      final candidates = unused.isEmpty ? available : unused;
      final grant = allocations[port] && candidates.isNotEmpty;
      final selected = grant ? select(candidates) : 0;
      result['grant$port'] = grant ? 1 : 0;
      result['victim$port'] = selected;
      result['evict$port'] = grant && (valid & (1 << selected)) != 0 ? 1 : 0;
      if (commits[port] && !grant) {
        invalidCommit = true;
      }
      if (grant) {
        reserved.add(selected);
        if (commits[port]) {
          if (tree) {
            access(selected);
          } else {
            pointer = (selected + 1) % count;
          }
        }
      }
    }
    result['invalidCommit'] = invalidCommit ? 1 : 0;
    return result;
  }
}

class _AssociativeHarness extends Module {
  _AssociativeHarness() {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final allocate = addInput('allocate', Logic());
    final invalidate = addInput('invalidate', Logic());
    final invalidIndex = addInput('invalidIndex', Logic(width: 2), width: 2);
    final update = AssociativeUpdatePortInterface(keyWidth: 8, indexWidth: 2);
    final lookup = AssociativeLookupPortInterface(keyWidth: 8, indexWidth: 2);
    lookup.en <= addInput('lookupEn', Logic());
    lookup.key <= addInput('lookupKey', Logic(width: 8), width: 8);
    final memory = ParallelAssociativeMemory(
      clk: clk,
      reset: reset,
      updates: [update],
      lookups: [lookup],
      entryCount: 3,
      enableValidTracking: true,
      contract: const AssociativeMemoryContract(
        lookupLatency: 0,
        updateLatency: 0,
        duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
        matchSelection: AssociativeMatchSelection.lowestIndex,
        resultShape: AssociativeResultShape.selectedIndex,
        lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
        updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
        resetBehavior: AssociativeMemoryResetBehavior.clearValidity,
        implementationKind: AssociativeMemoryImplementationKind.synthesizable,
      ),
    );
    final access = ReplacementAccessInterface(3);
    access.en <= lookup.en & lookup.hit;
    access.index <= lookup.index;
    final allocation = ReplacementAllocationInterface(3);
    allocation.en <= allocate & ~invalidate;
    allocation.commit <= allocation.valid;
    RoundRobinReplacement(
        clk: clk,
        reset: reset,
        validMask: memory.validMask!,
        eligibleMask: Const(7, width: 3),
        accesses: [access],
        allocations: [allocation],
        entryCount: 3);
    update.en <= allocation.valid | invalidate;
    update.index <= mux(invalidate, invalidIndex, allocation.index);
    update.entryValid <= ~invalidate;
    update.key <= addInput('newKey', Logic(width: 8), width: 8);
    addOutput('mask', width: 3) <= memory.validMask!;
    addOutput('grant') <= allocation.valid;
    addOutput('victim', width: 2) <= allocation.index;
    addOutput('evict') <= allocation.evict;
    addOutput('hit') <= lookup.hit;
    addOutput('hitIndex', width: 2) <= lookup.index;
  }
}

class _DeferredMiterHarness extends Module {
  _DeferredMiterHarness(int count,
      {required bool tree, required bool behavioral}) {
    final width = max(1, (count - 1).bitLength);
    final accesses = List.generate(2, (_) => ReplacementAccessInterface(count));
    final commits = List.generate(2, (_) => ReplacementCommitInterface(count));
    final allocations =
        List.generate(2, (_) => ReplacementAllocationInterface(count));
    for (var i = 0; i < 2; i++) {
      accesses[i].en <= addInput('a${i}_en', Logic());
      accesses[i].index <=
          addInput('a${i}_index', Logic(width: width), width: width);
      commits[i].en <= addInput('c${i}_en', Logic());
      commits[i].index <=
          addInput('c${i}_index', Logic(width: width), width: width);
      allocations[i].en <= addInput('q${i}_en', Logic());
      allocations[i].commit <= addInput('q${i}_commit', Logic());
    }
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final valid = addInput('valid', Logic(width: count), width: count);
    final eligible = addInput('eligible', Logic(width: count), width: count);
    final factory = behavioral
        ? CacheReplacement.behavioral(tree
            ? BehavioralReplacementKind.treePseudoLru
            : BehavioralReplacementKind.roundRobin)
        : tree
            ? CacheReplacement.treePseudoLru
            : CacheReplacement.roundRobin;
    final policy = factory.buildWithCommits!(
      clk: clk,
      reset: reset,
      validMask: valid,
      eligibleMask: eligible,
      accesses: accesses,
      commits: commits,
      allocations: allocations,
      entryCount: count,
      name: 'policy',
    );
    addOutput('invalidAccess') <= policy.invalidAccess;
    addOutput('invalidCommit') <= policy.invalidCommit;
    for (var i = 0; i < 2; i++) {
      addOutput('grant$i') <= allocations[i].valid;
      addOutput('index$i', width: width) <= allocations[i].index;
      addOutput('evict$i') <= allocations[i].evict;
    }
  }
}

void main() {
  tearDown(Simulator.reset);

  for (final (count, tree) in [
    (1, false),
    (3, false),
    (4, false),
    (1, true),
    (4, true),
    (8, true)
  ]) {
    for (final behavioral in [false, true]) {
      test(
          '${tree ? 'tree PLRU' : 'round robin'} with $count entries '
          'behavioral=$behavioral', () async {
        final dut = _Harness(count, tree: tree, behavioral: behavioral);
        await dut.build();
        final reference = _Reference(count, tree: tree);
        final random = Random(213 + count);
        final mask = (1 << count) - 1;
        final vectors = <Vector>[
          Vector({
            'clk': 0,
            'reset': 1,
            'valid': 0,
            'eligible': mask,
            'hitEn0': 0,
            'hitEn1': 0,
            'hitIndex0': 0,
            'hitIndex1': 0,
            'allocEn0': 0,
            'allocEn1': 0,
            'allocCommit0': 0,
            'allocCommit1': 0,
          }, {}),
          Vector({'clk': 1}, {}),
        ];
        for (var cycle = 0; cycle < 40; cycle++) {
          final valid = cycle == 0 ? 0 : random.nextInt(mask + 1);
          final eligible = cycle == 1 ? 0 : random.nextInt(mask + 1);
          final hits = [
            for (var index = 0; index < 2; index++)
              (
                en: random.nextBool(),
                index: random.nextInt(1 << max(1, (count - 1).bitLength))
              )
          ];
          final allocations = [
            cycle < 2 || random.nextBool(),
            cycle < 2 || random.nextBool()
          ];
          final commits = [random.nextBool(), random.nextBool()];
          vectors
            ..add(Vector(
                {
                  'clk': 0,
                  'reset': 0,
                  'valid': valid,
                  'eligible': eligible,
                  for (var index = 0; index < 2; index++) ...{
                    'hitEn$index': hits[index].en ? 1 : 0,
                    'hitIndex$index': hits[index].index,
                    'allocEn$index': allocations[index] ? 1 : 0,
                    'allocCommit$index': commits[index] ? 1 : 0,
                  }
                },
                reference.step(
                    valid: valid,
                    eligible: eligible,
                    hits: hits,
                    allocations: allocations,
                    commits: commits)))
            ..add(Vector({'clk': 1}, {}));
        }
        await SimCompare.checkFunctionalVector(dut, vectors);
        if (!behavioral) {
          SimCompare.checkIverilogVector(dut, vectors);
          if ((!tree && count == 3) || (tree && count == 4)) {
            expect(SimCompare.checkSystemCVector(dut, vectors), isTrue);
          }
        }
      });
    }
  }

  for (final tree in [false, true]) {
    test('behavioral replacement matches RTL with deferred commits tree=$tree',
        () async {
      final count = tree ? 4 : 3;
      final rtl = _DeferredMiterHarness(count, tree: tree, behavioral: false);
      final software =
          _DeferredMiterHarness(count, tree: tree, behavioral: true);
      await rtl.build();
      await software.build();
      final random = Random(322);
      for (var cycle = 0; cycle < 100; cycle++) {
        final time = 2 + cycle * 4;
        final inputs = <String, int>{
          'clk': 0,
          'reset': cycle == 0 ? 1 : 0,
          'valid': random.nextInt(1 << count),
          'eligible': random.nextInt(1 << count),
          for (var i = 0; i < 2; i++) ...{
            'a${i}_en': random.nextInt(2),
            'a${i}_index': random.nextInt(4),
            'c${i}_en': random.nextInt(2),
            'c${i}_index': random.nextInt(4),
            'q${i}_en': random.nextInt(2),
            'q${i}_commit': random.nextInt(2),
          },
        };
        void compare(String phase) {
          for (final entry in rtl.outputs.entries) {
            expect(software.output(entry.key).value, entry.value.value,
                reason: '${entry.key} differs at cycle $cycle $phase');
          }
        }

        Simulator.registerAction(time, () {
          for (final entry in inputs.entries) {
            rtl.input(entry.key).put(entry.value);
            software.input(entry.key).put(entry.value);
          }
        });
        if (cycle > 0) {
          Simulator.registerAction(time + 1, () => compare('before'));
        }
        Simulator.registerAction(time + 2, () {
          rtl.input('clk').put(1);
          software.input('clk').put(1);
        });
        Simulator.registerAction(time + 3, () => compare('after'));
      }
      await Simulator.run();
    });
  }

  test('tree PLRU rejects non-power-of-two entry counts', () {
    expect(() => _Harness(3, tree: true), throwsArgumentError);
  });

  test('uncommitted victims do not advance policy state', () async {
    final dut = _Harness(3, tree: false);
    await dut.build();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'valid': 7,
        'eligible': 7,
        'hitEn0': 0,
        'hitEn1': 0,
        'hitIndex0': 0,
        'hitIndex1': 0,
        'allocEn0': 0,
        'allocEn1': 0,
        'allocCommit0': 0,
        'allocCommit1': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector(
          {'clk': 0, 'reset': 0, 'allocEn0': 1}, {'grant0': 1, 'victim0': 0}),
      Vector({'clk': 1}, {'victim0': 0}),
      Vector({'clk': 0, 'allocCommit0': 1}, {'victim0': 0}),
      Vector({'clk': 1}, {'victim0': 1}),
      Vector({'clk': 0, 'allocEn0': 0}, {'grant0': 0, 'invalidCommit': 1}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('replacement composes with associative-memory validity', () async {
    final dut = _AssociativeHarness();
    await dut.build();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'allocate': 0,
        'invalidate': 0,
        'invalidIndex': 0,
        'newKey': 0,
        'lookupEn': 0,
        'lookupKey': 0,
      }, {}),
      Vector({'clk': 1}, {'mask': 0}),
      Vector({'clk': 0, 'reset': 0, 'allocate': 1, 'newKey': 0x11},
          {'grant': 1, 'victim': 0, 'evict': 0}),
      Vector({'clk': 1}, {'mask': 1, 'victim': 1, 'evict': 0}),
      Vector({'clk': 0, 'newKey': 0x22}, {}),
      Vector({'clk': 1}, {'mask': 3, 'victim': 2, 'evict': 0}),
      Vector({'clk': 0, 'newKey': 0x33}, {}),
      Vector({'clk': 1}, {'mask': 7, 'victim': 0, 'evict': 1}),
      Vector({
        'clk': 0,
        'allocate': 0,
        'invalidate': 1,
        'invalidIndex': 1,
      }, {}),
      Vector({'clk': 1}, {'mask': 5}),
      Vector({
        'clk': 0,
        'allocate': 1,
        'invalidate': 0,
        'newKey': 0x44,
        'lookupEn': 1,
        'lookupKey': 0x11
      }, {
        'hit': 1,
        'hitIndex': 0,
        'grant': 1,
        'victim': 1,
        'evict': 0,
      }),
      Vector({'clk': 1}, {'mask': 7}),
      Vector({'clk': 0, 'allocate': 0, 'lookupKey': 0x44},
          {'hit': 1, 'hitIndex': 1}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });
}
