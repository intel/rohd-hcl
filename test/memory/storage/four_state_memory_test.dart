// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// four_state_memory_test.dart
// Four-state transaction tests for memory implementations.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _RegisterFileFixture {
  final clk = Logic()..put(0);
  final reset = Logic()..put(0);
  final write = MaskedDataPortInterface(16, 2)
    ..en.put(0)
    ..addr.put(0)
    ..data.put(0)
    ..mask.put(3);
  late final RegisterFile<Logic> memory;

  _RegisterFileFixture() {
    memory = RegisterFile<Logic>(clk, reset, [write], [], numEntries: 4);
  }

  Future<void> cycle() async {
    await Simulator.tick();
    clk.inject(1);
    await Simulator.tick();
    clk.inject(0);
    await Simulator.tick();
  }

  LogicValue word(int index) => memory.getData(LogicValue.ofInt(index, 2))!;
}

class _RegisterFileHarness extends Module {
  _RegisterFileHarness({bool masked = true}) {
    final write = masked
        ? MaskedDataPortInterface<Logic>(16, 2)
        : DataPortInterface<Logic>(16, 2);
    final reads = List.generate(4, (index) {
      final read = DataPortInterface(16, 2);
      read.en <= Const(1);
      read.addr <= Const(index, width: 2);
      return read;
    });
    final dynamicRead = DataPortInterface(16, 2);
    dynamicRead.en <= addInput('readEnable', Logic());
    dynamicRead.addr <= addInput('readAddress', Logic(width: 2), width: 2);
    write.en <= addInput('writeEnable', Logic());
    write.addr <= addInput('writeAddress', Logic(width: 2), width: 2);
    write.data <= addInput('writeData', Logic(width: 16), width: 16);
    if (write is MaskedDataPortInterface<Logic>) {
      write.mask <= addInput('writeMask', Logic(width: 2), width: 2);
    }
    RegisterFile<Logic>(
      addInput('clk', Logic()),
      addInput('reset', Logic()),
      [write],
      [...reads, dynamicRead],
      numEntries: 4,
    );
    for (var index = 0; index < reads.length; index++) {
      addOutput('word$index', width: 16) <= reads[index].data;
    }
    addOutput('readData', width: 16) <= dynamicRead.data;
  }
}

class _MemoryModelFixture {
  final clk = Logic()..put(0);
  final reset = Logic()..put(0);
  final write = MaskedDataPortInterface(16, 2)
    ..en.put(0)
    ..addr.put(0)
    ..data.put(0)
    ..mask.put(3);
  late final SparseMemoryStorage storage;
  late final MemoryModel<Logic> memory;
  int invalidWrites = 0;

  _MemoryModelFixture() {
    storage = SparseMemoryStorage(
      addrWidth: 2,
      dataWidth: 16,
      onInvalidWrite: () => invalidWrites++,
      onInvalidRead: (_, width) => LogicValue.ofInt(0, width),
    );
    memory = MemoryModel<Logic>(clk, reset, [write], [],
        storage: storage, asyncReset: false);
  }

  Future<void> cycle() async {
    await Simulator.tick();
    clk.inject(1);
    await Simulator.tick();
    clk.inject(0);
    await Simulator.tick();
  }

  LogicValue word(int index) => storage.readData(LogicValue.ofInt(index, 2));
}

class _AssociativeFixture extends Module {
  _AssociativeFixture() {
    final update = AssociativeUpdatePortInterface(keyWidth: 4, indexWidth: 2);
    final lookup = AssociativeLookupPortInterface(keyWidth: 4, indexWidth: 2);
    update.en <= addInput('writeEnable', Logic());
    update.index <= addInput('writeIndex', Logic(width: 2), width: 2);
    update.key <= addInput('writeKey', Logic(width: 4), width: 4);
    update.entryValid <= addInput('writeValid', Logic());
    lookup.en <= Const(1);
    lookup.key <= addInput('query', Logic(width: 4), width: 4);
    final memory = ParallelAssociativeMemory(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      updates: [update],
      lookups: [lookup],
      entryCount: 4,
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
    addOutput('validMask', width: 4) <= memory.validMask!;
    addOutput('hit') <= lookup.hit;
  }
}

void main() {
  tearDown(Simulator.reset);

  for (final masked in [false, true]) {
    test(
        'all-X write enable and address poison every register-file entry '
        '(masked=$masked)', () async {
      final clk = Logic()..put(0);
      final reset = Logic()..put(0);
      final write = (masked
          ? (MaskedDataPortInterface<Logic>(16, 2)..mask.put(3))
          : DataPortInterface<Logic>(16, 2))
        ..en.put(0)
        ..addr.put(0)
        ..data.put(0);
      final modelReads = List.generate(
          4,
          (index) => DataPortInterface<Logic>(16, 2)
            ..en.put(1)
            ..addr.put(index));
      final rtlReads = List.generate(4, (index) {
        final read = DataPortInterface<Logic>(16, 2);
        read.en <= modelReads[index].en;
        read.addr <= modelReads[index].addr;
        return read;
      });
      final model = MemoryModel<Logic>.registerFile(
          clk, reset, [write], modelReads,
          numEntries: 4);
      final rtl =
          RegisterFile<Logic>(clk, reset, [write], rtlReads, numEntries: 4);
      await model.build();
      await rtl.build();

      Future<void> cycle() async {
        await Simulator.tick();
        clk.inject(1);
        await Simulator.tick();
        clk.inject(0);
        await Simulator.tick();
      }

      reset.inject(1);
      await cycle();
      reset.inject(0);
      write
        ..en.inject(1)
        ..addr.inject(2)
        ..data.inject(0x1234);
      await cycle();
      expect(modelReads[2].data.value, LogicValue.ofInt(0x1234, 16));
      expect(rtlReads[2].data.value, LogicValue.ofInt(0x1234, 16));
      write
        ..en.inject(LogicValue.x)
        ..addr.inject(LogicValue.ofString('xx'));
      await cycle();
      final unknown = LogicValue.filled(16, LogicValue.x);
      for (var index = 0; index < 4; index++) {
        final address = LogicValue.ofInt(index, 2);
        expect(rtl.getData(address), unknown, reason: 'RTL word $index');
        expect(model.storage.getData(address), unknown,
            reason: 'Model word $index');
        expect(rtlReads[index].data.value, unknown, reason: 'RTL read $index');
        expect(modelReads[index].data.value, unknown,
            reason: 'Model read $index');
      }
    });

    test('all-X write enable and address match Icarus (masked=$masked)',
        () async {
      final memory = _RegisterFileHarness(masked: masked);
      await memory.build();
      final vectors = [
        Vector({
          'clk': 0,
          'reset': 1,
          'writeEnable': 0,
          'writeAddress': 0,
          'writeData': 0x1234,
          if (masked) 'writeMask': 3,
          'readEnable': 0,
          'readAddress': 0,
        }, {}),
        Vector({'clk': 1}, {}),
        Vector({
          'clk': 0,
          'reset': 0,
          'writeEnable': 1,
          'writeAddress': 2,
        }, {}),
        Vector(
            {'clk': 1}, {'word0': 0, 'word1': 0, 'word2': 0x1234, 'word3': 0}),
        Vector({
          'clk': 0,
          'writeEnable': LogicValue.x,
          'writeAddress': LogicValue.ofString('xx'),
        }, {}),
        Vector({
          'clk': 1
        }, {
          for (var index = 0; index < 4; index++)
            'word$index': LogicValue.filled(16, LogicValue.x),
        }),
      ];
      await SimCompare.checkFunctionalVector(memory, vectors);
      SimCompare.checkIverilogVector(memory, vectors);
    });
  }

  for (final latency in [0, 1, 2]) {
    test('all-X sparse write is visible at read latency $latency', () async {
      final clk = Logic()..put(0);
      final reset = Logic()..put(0);
      final write = DataPortInterface<Logic>(16, 2)
        ..en.put(0)
        ..addr.put(0)
        ..data.put(0);
      final reads = List.generate(
          3,
          (index) => DataPortInterface<Logic>(16, 2)
            ..en.put(1)
            ..addr.put(index));
      var invalidWrites = 0;
      final storage = SparseMemoryStorage(
        addrWidth: 2,
        dataWidth: 16,
        onInvalidWrite: () => invalidWrites++,
        onInvalidRead: (_, width) => LogicValue.ofInt(0, width),
      )
        ..setData(LogicValue.ofInt(0, 2), LogicValue.ofInt(0x1234, 16))
        ..setData(LogicValue.ofInt(1, 2), LogicValue.ofInt(0xabcd, 16));
      final model = MemoryModel<Logic>(clk, reset, [write], reads,
          readLatency: latency, asyncReset: false, storage: storage);
      await model.build();

      Future<void> cycles(int count) async {
        for (var cycle = 0; cycle < count; cycle++) {
          await Simulator.tick();
          clk.inject(1);
          await Simulator.tick();
          clk.inject(0);
          await Simulator.tick();
        }
      }

      await cycles(latency + 1);
      expect(reads[0].data.value, LogicValue.ofInt(0x1234, 16));
      expect(reads[1].data.value, LogicValue.ofInt(0xabcd, 16));
      expect(reads[2].data.value, LogicValue.ofInt(0, 16));
      write
        ..en.inject(LogicValue.x)
        ..addr.inject(LogicValue.ofString('xx'));
      await cycles(1);
      write.en.inject(0);
      await cycles(latency + 1);
      final unknown = LogicValue.filled(16, LogicValue.x);
      for (final read in reads) {
        expect(read.data.value, unknown);
      }
      expect(invalidWrites, 1);

      write
        ..en.inject(1)
        ..addr.inject(1)
        ..data.inject(0xbeef);
      await cycles(1);
      write.en.inject(0);
      await cycles(latency + 1);
      expect(reads[0].data.value, unknown);
      expect(reads[1].data.value, LogicValue.ofInt(0xbeef, 16));
      expect(reads[2].data.value, unknown);
      expect(invalidWrites, 1);
    });
  }

  test('unknown write enable affects only the addressed entry', () async {
    final fixture = _RegisterFileFixture();
    await fixture.memory.build();
    fixture.reset.inject(1);
    await fixture.cycle();
    fixture.reset.inject(0);
    fixture.write.en.inject(LogicValue.x);
    fixture.write.addr.inject(1);
    fixture.write.data.inject(0xffff);
    await fixture.cycle();

    expect(fixture.word(0), LogicValue.ofInt(0, 16));
    expect(fixture.word(1), LogicValue.filled(16, LogicValue.x));
    expect(fixture.word(2), LogicValue.ofInt(0, 16));
    expect(fixture.word(3), LogicValue.ofInt(0, 16));
  });

  test('partly unknown write address affects compatible entries', () async {
    final fixture = _RegisterFileFixture();
    await fixture.memory.build();
    fixture.reset.inject(1);
    await fixture.cycle();
    fixture.reset.inject(0);
    fixture.write.en.inject(1);
    fixture.write.addr.inject(LogicValue.ofString('0x'));
    fixture.write.data.inject(0xffff);
    await fixture.cycle();

    expect(fixture.word(0), LogicValue.filled(16, LogicValue.x));
    expect(fixture.word(1), LogicValue.filled(16, LogicValue.x));
    expect(fixture.word(2), LogicValue.ofInt(0, 16));
    expect(fixture.word(3), LogicValue.ofInt(0, 16));
  });

  test('unknown byte mask affects only the corresponding byte', () async {
    final fixture = _RegisterFileFixture();
    await fixture.memory.build();
    fixture.reset.inject(1);
    await fixture.cycle();
    fixture.reset.inject(0);
    fixture.write.en.inject(1);
    fixture.write.addr.inject(1);
    fixture.write.mask.inject(LogicValue.ofString('1x'));
    fixture.write.data.inject(0xffff);
    await fixture.cycle();

    expect(fixture.word(0), LogicValue.ofInt(0, 16));
    expect(fixture.word(1), LogicValue.ofString('11111111xxxxxxxx'));
  });

  test('register file normalizes high impedance on writes and state access',
      () async {
    final fixture = _RegisterFileFixture();
    await fixture.memory.build();
    fixture.reset.inject(1);
    await fixture.cycle();
    fixture.reset.inject(0);
    fixture.write.en.inject(1);
    fixture.write.addr.inject(1);
    fixture.write.data.inject(LogicValue.ofString('10xz10xz10xz10xz'));
    await fixture.cycle();
    final expected = LogicValue.ofString('10xx10xx10xx10xx');
    expect(fixture.word(1), expected);

    fixture.memory.setData(
        LogicValue.ofInt(2, 2), LogicValue.ofString('10xz10xz10xz10xz'));
    expect(fixture.word(2), expected);
  });

  test('register-file and shift-register reset values normalize Z', () async {
    final clk = Logic()..put(0);
    final reset = Logic()..put(0);
    final write = DataPortInterface(4, 1)..en.put(0);
    final registerFile = RegisterFile<Logic>(clk, reset, [write], [],
        numEntries: 1, resetValue: LogicValue.ofString('10xz'));
    final shift = ShiftRegister<Logic>(Logic(width: 4),
        clk: clk,
        depth: 1,
        reset: reset,
        resetValue: LogicValue.ofString('10xz'));
    await registerFile.build();
    await shift.build();
    reset.inject(1);
    await Simulator.tick();
    clk.inject(1);
    await Simulator.tick();
    expect(registerFile.getData(LogicValue.ofInt(0, 1)),
        LogicValue.ofString('10xx'));
    expect(shift.dataOut.value, LogicValue.ofString('10xx'));
  });

  test('sparse storage and raw state loads normalize high impedance', () {
    final storage = SparseMemoryStorage(addrWidth: 2, dataWidth: 4);
    final state = MemoryStorageState(storage);
    final value = LogicValue.ofString('10xz');
    final expected = LogicValue.ofString('10xx');
    storage.setData(LogicValue.ofInt(0, 2), value);
    state
      ..poke(1, value)
      ..load(MemoryStorageImage({2: value}));

    for (var address = 0; address < 3; address++) {
      expect(state.peek(address), expected);
    }
    expect(state.snapshot().entries,
        {for (var index = 0; index < 3; index++) BigInt.from(index): expected});
  });

  test('model preserves unaffected words and bytes on uncertain writes',
      () async {
    final fixture = _MemoryModelFixture();
    await fixture.memory.build();
    for (var index = 0; index < 4; index++) {
      fixture.storage
          .setData(LogicValue.ofInt(index, 2), LogicValue.ofInt(0x1234, 16));
    }

    fixture.write.en.inject(LogicValue.x);
    fixture.write.addr.inject(1);
    fixture.write.mask.inject(1);
    await fixture.cycle();
    expect(fixture.word(0), LogicValue.ofInt(0x1234, 16));
    expect(fixture.word(1), LogicValue.ofString('00010010xxxxxxxx'));
    expect(fixture.word(2), LogicValue.ofInt(0x1234, 16));

    fixture.write.en.inject(1);
    fixture.write.addr.inject(2);
    fixture.write.mask.inject(LogicValue.ofString('1x'));
    fixture.write.data.inject(0xabcd);
    await fixture.cycle();
    expect(fixture.word(2), LogicValue.ofString('10101011xxxxxxxx'));
    expect(fixture.word(3), LogicValue.ofInt(0x1234, 16));
    expect(fixture.invalidWrites, 2);
  });

  test('model tracks uncertain address writes to unallocated words', () async {
    final fixture = _MemoryModelFixture();
    await fixture.memory.build();
    fixture.storage
        .setData(LogicValue.ofInt(0, 2), LogicValue.ofInt(0xabcd, 16));
    fixture.write.en.inject(1);
    fixture.write.addr.inject(LogicValue.ofString('0x'));
    fixture.write.mask.inject(1);
    fixture.write.data.inject(0xffff);
    await fixture.cycle();
    expect(fixture.word(0), LogicValue.ofString('10101011xxxxxxxx'));
    expect(fixture.word(1), LogicValue.ofString('00000000xxxxxxxx'));
    expect(fixture.word(2), LogicValue.ofInt(0, 16));
    expect(fixture.invalidWrites, 1);
    expect(MemoryStorageState(fixture.storage).snapshot().uncertainWrites,
        hasLength(1));
    fixture.reset.inject(1);
    await fixture.cycle();
    expect(fixture.storage.isEmpty, isTrue);
    expect(fixture.word(1), LogicValue.ofInt(0, 16));
  });

  test('multiport uncertain writes respect port order and permit recovery',
      () async {
    final clk = Logic()..put(0);
    final reset = Logic()..put(0);
    final writes = List.generate(
        2,
        (_) => MaskedDataPortInterface<Logic>(16, 2)
          ..en.put(0)
          ..addr.put(0)
          ..data.put(0)
          ..mask.put(3));
    final reads = List.generate(
        2,
        (index) => DataPortInterface<Logic>(16, 2)
          ..en.put(1)
          ..addr.put(index));
    var invalidWrites = 0;
    final storage = SparseMemoryStorage(
      addrWidth: 2,
      dataWidth: 16,
      onInvalidWrite: () => invalidWrites++,
      onInvalidRead: (_, width) => LogicValue.ofInt(0, width),
    );
    final memory = MemoryModel<Logic>(clk, reset, writes, reads,
        storage: storage, asyncReset: false);
    await memory.build();
    for (var index = 0; index < 4; index++) {
      storage.setData(LogicValue.ofInt(index, 2), LogicValue.ofInt(0x1234, 16));
    }

    Future<void> cycle() async {
      await Simulator.tick();
      clk.inject(1);
      await Simulator.tick();
      clk.inject(0);
      await Simulator.tick();
    }

    LogicValue word(int index) => storage.readData(LogicValue.ofInt(index, 2));

    writes[0]
      ..en.inject(LogicValue.x)
      ..addr.inject(LogicValue.ofString('0x'))
      ..mask.inject(1);
    writes[1]
      ..en.inject(1)
      ..addr.inject(1)
      ..data.inject(0xabcd);
    await cycle();
    expect(word(0), LogicValue.ofString('00010010xxxxxxxx'));
    expect(word(1), LogicValue.ofInt(0xabcd, 16));
    expect(word(2), LogicValue.ofInt(0x1234, 16));
    expect(reads[0].data.value, word(0));
    expect(reads[1].data.value, word(1));
    expect(invalidWrites, 1);

    writes[0]
      ..en.inject(1)
      ..addr.inject(1)
      ..data.inject(0x5678)
      ..mask.inject(3);
    writes[1]
      ..en.inject(1)
      ..addr.inject(LogicValue.ofString('0z'))
      ..mask.inject(2);
    await cycle();
    expect(word(0), LogicValue.filled(16, LogicValue.x));
    expect(word(1), LogicValue.ofString('xxxxxxxx01111000'));
    expect(word(2), LogicValue.ofInt(0x1234, 16));
    expect(reads[0].data.value, word(0));
    expect(reads[1].data.value, word(1));
    expect(invalidWrites, 2);

    writes[0].en.inject(0);
    writes[1]
      ..en.inject(LogicValue.x)
      ..mask.inject(0);
    await cycle();
    expect(word(1), LogicValue.ofString('xxxxxxxx01111000'));
    expect(invalidWrites, 2);

    writes[1]
      ..en.inject(1)
      ..addr.inject(1)
      ..data.inject(0xbeef)
      ..mask.inject(3);
    await cycle();
    expect(word(1), LogicValue.ofInt(0xbeef, 16));
    expect(word(0), LogicValue.filled(16, LogicValue.x));
    expect(reads[1].data.value, word(1));
    expect(invalidWrites, 2);
  });

  test('symbolic sparse writes survive snapshot and restore', () {
    var invalidWrites = 0;
    SparseMemoryStorage makeStorage() => SparseMemoryStorage(
          addrWidth: 32,
          dataWidth: 16,
          onInvalidWrite: () => invalidWrites++,
          onInvalidRead: (_, width) => LogicValue.ofInt(0x1234, width),
        );
    final storage = makeStorage()
      ..setData(LogicValue.ofInt(0, 32), LogicValue.ofInt(0xbeef, 16));
    final state = MemoryStorageState(storage);
    storage.writeUncertainAddress(
        LogicValue.ofString('${'0' * 30}0x'), LogicValue.ofInt(0xff, 16));
    expect(storage.readData(LogicValue.ofInt(0, 32)),
        LogicValue.ofString('10111110xxxxxxxx'));
    expect(storage.readData(LogicValue.ofInt(1, 32)),
        LogicValue.ofString('00010010xxxxxxxx'));
    expect(storage.readData(LogicValue.ofInt(2, 32)),
        LogicValue.ofInt(0x1234, 16));
    expect(invalidWrites, 1);
    final image = state.snapshot();
    expect(image.uncertainWrites, hasLength(1));
    expect(image.uncertainWrites.clear, throwsUnsupportedError);

    final restored = makeStorage();
    MemoryStorageState(restored).load(image, replace: true);
    for (var index = 0; index < 3; index++) {
      expect(restored.readData(LogicValue.ofInt(index, 32)),
          storage.readData(LogicValue.ofInt(index, 32)));
    }
    restored.writeData(LogicValue.ofInt(1, 32), LogicValue.ofInt(0x5678, 16));
    expect(restored.readData(LogicValue.ofInt(1, 32)),
        LogicValue.ofInt(0x5678, 16));
  });

  test('unknown addresses require a matcher for custom alignment', () {
    final address = LogicValue.ofString('0x1');
    final storage = SparseMemoryStorage(
      addrWidth: 3,
      dataWidth: 8,
      alignAddress: (address) => address & LogicValue.ofInt(6, 3),
      onInvalidWrite: () {},
      onInvalidRead: (_, width) => LogicValue.ofInt(0, width),
    );
    expect(
        () => storage.writeUncertainAddress(address, LogicValue.ofInt(0xff, 8)),
        throwsUnsupportedError);
    expect(storage.isEmpty, isTrue);

    final matchingStorage = SparseMemoryStorage(
      addrWidth: 3,
      dataWidth: 8,
      alignAddress: (address) => address & LogicValue.ofInt(6, 3),
      unknownAddressMatcher: (pattern, physical) =>
          physical[0] == LogicValue.zero &&
          (pattern[2] == physical[2] || !pattern[2].isValid),
      unknownAddressMappingId: 'align-even-3-bit',
      onInvalidWrite: () {},
      onInvalidRead: (_, width) => LogicValue.ofInt(0, width),
    )..writeUncertainAddress(address, LogicValue.ofInt(0xff, 8));
    expect(matchingStorage.readData(LogicValue.ofInt(1, 3)),
        LogicValue.filled(8, LogicValue.x));
    expect(matchingStorage.readData(LogicValue.ofInt(3, 3)),
        LogicValue.filled(8, LogicValue.x));
    expect(matchingStorage.readData(LogicValue.ofInt(5, 3)),
        LogicValue.ofInt(0, 8));
    final identityStorage = SparseMemoryStorage(
      addrWidth: 3,
      dataWidth: 8,
      onInvalidWrite: () {},
    )..writeUncertainAddress(address, LogicValue.ofInt(0xff, 8));
    final before = MemoryStorageState(matchingStorage).snapshot();
    expect(
        () => MemoryStorageState(matchingStorage).load(
            MemoryStorageState(identityStorage).snapshot(),
            replace: true),
        throwsArgumentError);
    expect(MemoryStorageState(matchingStorage).snapshot().uncertainWrites,
        before.uncertainWrites);
  });

  test('unknown write address has the same affected words in Icarus', () async {
    final memory = _RegisterFileHarness();
    await memory.build();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'writeEnable': 0,
        'writeAddress': 0,
        'writeData': 0xffff,
        'writeMask': 3,
        'readEnable': 0,
        'readAddress': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'writeEnable': 1,
        'writeAddress': LogicValue.ofString('0x'),
      }, {}),
      Vector({
        'clk': 1
      }, {
        'word0': LogicValue.filled(16, LogicValue.x),
        'word1': LogicValue.filled(16, LogicValue.x),
        'word2': 0,
        'word3': 0,
      }),
      Vector({'clk': 0, 'reset': 1, 'writeEnable': 0}, {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'writeEnable': LogicValue.x,
        'writeAddress': 2,
        'writeMask': 1,
      }, {}),
      Vector({
        'clk': 1
      }, {
        'word0': 0,
        'word1': 0,
        'word2': LogicValue.ofString('00000000xxxxxxxx'),
        'word3': 0,
      }),
      Vector({'clk': 0, 'reset': 1, 'writeEnable': 0}, {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'writeEnable': 1,
        'writeAddress': 3,
        'writeMask': LogicValue.ofString('1x'),
        'writeData': LogicValue.ofString('11111111zzzzzzzz'),
      }, {}),
      Vector({
        'clk': 1
      }, {
        'word0': 0,
        'word1': 0,
        'word2': 0,
        'word3': LogicValue.ofString('11111111xxxxxxxx'),
      }),
      Vector({
        'clk': 0,
        'writeEnable': 0,
        'readEnable': LogicValue.x,
        'readAddress': 0,
      }, {
        'readData': LogicValue.filled(16, LogicValue.x),
      }),
      Vector({
        'readEnable': 1,
        'readAddress': LogicValue.ofString('0x'),
      }, {
        'readData': LogicValue.filled(16, LogicValue.x),
      }),
      Vector({
        'readEnable': 0,
      }, {
        'readData': 0,
      }),
    ];
    await SimCompare.checkFunctionalVector(memory, vectors);
    SimCompare.checkIverilogVector(memory, vectors);
  });

  test('associative updates limit uncertainty to matching indices', () async {
    final memory = _AssociativeFixture();
    await memory.build();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'writeEnable': 0,
        'writeIndex': 0,
        'writeKey': 0,
        'writeValid': 1,
        'query': 0,
      }, {}),
      Vector({'clk': 1}, {'validMask': 0}),
      Vector({
        'clk': 0,
        'reset': 0,
        'writeEnable': 1,
        'writeIndex': LogicValue.ofString('0x'),
      }, {}),
      Vector({'clk': 1}, {'validMask': LogicValue.ofString('00xx')}),
      Vector({'clk': 0, 'writeEnable': 1, 'writeIndex': 3, 'writeKey': 7}, {}),
      Vector({'clk': 1}, {'validMask': LogicValue.ofString('10xx')}),
    ];
    await SimCompare.checkFunctionalVector(memory, vectors);
    SimCompare.checkIverilogVector(memory, vectors);
  });
}
