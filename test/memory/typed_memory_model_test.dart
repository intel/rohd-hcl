// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_memory_model_test.dart
// Tests for the typed memory model.
//
// 2026 October 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:test/test.dart';

class _Word extends LogicStructure {
  _Word({String? name})
      : super([
          FixedPoint(integerWidth: 3, fractionWidth: 4, name: 'payload'),
          Logic(name: 'tag', width: 8),
        ], name: name ?? 'word');

  @override
  _Word clone({String? name}) => _Word(name: name ?? this.name);
}

enum _Phase { idle, busy, done }

typedef _WordValue = ({LogicValue bits});

const _codec = LogicValueCodec<_WordValue>(decode: _decode, encode: _encode);
_WordValue _decode(LogicValue bits) => (bits: bits);
LogicValue _encode(_WordValue value) => value.bits;

class _Fixture<T extends Logic> {
  final clk = Logic()..put(0);
  final reset = Logic()..put(0);
  late final Logic data;
  late final MaskedDataPortInterface<T> write;
  late final DataPortInterface<T> read;
  late final MemoryModel<T> model;

  _Fixture(T schema, int latency, {required bool asyncReset}) {
    data = Logic(width: schema.width)..put(0);
    write = MaskedDataPortInterface<T>.typed(schema, 3)
      ..en.put(0)
      ..addr.put(2)
      ..mask.put(LogicValue.one, fill: true);
    write.data <= data;
    read = DataPortInterface<T>.typed(schema, 3)
      ..en.put(0)
      ..addr.put(2);
    model = MemoryModel<T>(clk, reset, [write], [read],
        readLatency: latency,
        asyncReset: asyncReset,
        storage: SparseMemoryStorage(
            addrWidth: 3,
            dataWidth: schema.width,
            onInvalidRead: (_, width) =>
                LogicValue.filled(width, LogicValue.x)));
  }

  Future<void> update(void Function() action) async {
    Simulator.injectAction(action);
    await Simulator.tick();
  }

  Future<void> cycles(int count) async {
    for (var i = 0; i < count; i++) {
      clk.inject(1);
      await Simulator.tick();
      clk.inject(0);
      await Simulator.tick();
    }
  }
}

void _check<T extends Logic>(String label, T schema) {
  for (final latency in [0, 1, 2]) {
    for (final asyncReset in [false, true]) {
      // Exercise raw readback, byte masks, four-state data, and reset timing.
      test('$label latency=$latency asyncReset=$asyncReset', () async {
        final fixture = _Fixture<T>(schema, latency, asyncReset: asyncReset);
        final model = fixture.model;
        // ignore: omit_local_variable_types, verifies static payload type
        final T payload = model.reads.single.data;
        expect(payload.runtimeType, schema.runtimeType);
        expect(sameDeclaredPayloadShape(payload, schema), isTrue);
        expect(
            sameDeclaredPayloadShape(model.input('wr_data_0'), schema), isTrue);
        expect(sameDeclaredPayloadShape(model.output('rd_data_0'), schema),
            isTrue);
        await model.build();
        final known = LogicValue.ofBigInt(
            (BigInt.one << (schema.width - 1)) | BigInt.from(0x96a5),
            schema.width);
        final unknown = LogicValue.filled(schema.width, LogicValue.x);
        await fixture.cycles(latency + 1);
        await fixture.update(() {
          fixture.data.put(known);
          fixture.write.en.put(1);
        });
        await fixture.cycles(1);
        expect(model.storage.readData(LogicValue.ofInt(2, 3)), known);
        await fixture.update(() {
          fixture.write.en.put(0);
          fixture.read.en.put(1);
        });
        expect(payload.value, latency == 0 ? known : unknown);
        for (var cycle = 1; cycle <= latency; cycle++) {
          await fixture.cycles(1);
          expect(payload.value, cycle < latency ? unknown : known,
              reason: 'Read response must arrive at cycle $latency.');
        }

        await fixture.update(() {
          fixture.data.put(0x5a);
          fixture.write.en.put(1);
          fixture.write.mask.put(1);
        });
        await fixture.cycles(latency + 1);
        final masked = LogicValue.ofBigInt(
            (known.toBigInt() & ~BigInt.from(0xff)) | BigInt.from(0x5a),
            schema.width);
        expect(payload.value, masked);
        final mixed = LogicValue.ofString(
            List.generate(schema.width, (i) => '10xz'[i % 4]).join());
        await fixture.update(() {
          fixture.data.put(mixed);
          fixture.write.mask.put(LogicValue.one, fill: true);
        });
        await fixture.cycles(latency + 1);
        // Enum wires normalize invalid encodings, including partial X/Z, to X.
        final storedMixed = schema is LogicEnum ? unknown : mixed;
        expect(payload.value, storedMixed);
        expect(model.storage.readData(LogicValue.ofInt(2, 3)), storedMixed);

        await fixture.update(() {
          fixture.write.en.put(0);
          fixture.read.en.put(0);
        });
        await fixture.cycles(latency + 1);
        expect(payload.value, unknown);
        await fixture.update(() {
          fixture.read.en.put(1);
          fixture.read.addr.put(LogicValue.x, fill: true);
        });
        await fixture.cycles(latency + 1);
        expect(payload.value, unknown);

        await fixture.update(() => fixture.reset.put(1));
        expect(model.storage.isEmpty, asyncReset);
        await fixture.cycles(1);
        expect(model.storage.isEmpty, isTrue);
      });
    }
  }
}

void main() {
  tearDown(Simulator.reset);
  _check('scalar', Logic(width: 16));
  _check('nested fixed-point structure', _Word());
  _check('fixed-point', FixedPoint(integerWidth: 7, fractionWidth: 8));
  _check('floating-point', FloatingPoint32());
  _check<Logic>('runtime structure', _Word());
  _check(
      'enum',
      LogicEnum<_Phase>.withMapping({
        _Phase.idle: 0xa5,
        _Phase.busy: 0x5a,
        _Phase.done: 0x80,
      }));
  _check('rank-zero', TypedLogicArray<_Word, LogicValue>([], _Word.new));
  _check(
      'multidimensional unpacked',
      TypedLogicArray<_Word, LogicValue>([2, 2], _Word.new,
          numUnpackedDimensions: 2));
  _check('custom codec',
      TypedLogicArray<_Word, _WordValue>([2], _Word.new, valueCodec: _codec));
  _check('wide scalar', Logic(width: 160));

  test('read-only typed memory model preserves raw preloaded values', () async {
    final schema = FixedPoint(integerWidth: 3, fractionWidth: 4);
    final read = DataPortInterface<FixedPoint>.typed(schema, 2)
      ..en.put(0)
      ..addr.put(0);
    final storage = SparseMemoryStorage(addrWidth: 2, dataWidth: 8)
      ..writeData(LogicValue.ofInt(0, 2), LogicValue.ofInt(0xa5, 8));
    final model = MemoryModel<FixedPoint>(
        Logic()..put(0), Logic()..put(0), [], [read],
        storage: storage, readLatency: 0);
    await model.build();
    read.en.inject(1);
    await Simulator.tick();
    expect(model.reads.single.data.fixedPointValue.value,
        LogicValue.ofInt(0xa5, 8));
  });

  test('floating-point memory does not quiet NaNs or merge signed zeros',
      () async {
    final encodings = [0x7fc000a5, 0x7f8000a5, 0, 0x80000000];
    final storage = SparseMemoryStorage(addrWidth: 2, dataWidth: 32);
    for (var i = 0; i < encodings.length; i++) {
      storage.writeData(
          LogicValue.ofInt(i, 2), LogicValue.ofInt(encodings[i], 32));
    }
    final read = DataPortInterface<FloatingPoint32>.typed(FloatingPoint32(), 2)
      ..en.put(0)
      ..addr.put(0);
    final model = MemoryModel<FloatingPoint32>(
        Logic()..put(0), Logic()..put(0), [], [read],
        storage: storage, readLatency: 0);
    await model.build();
    for (var i = 0; i < encodings.length; i++) {
      Simulator.injectAction(() {
        read.en.put(1);
        read.addr.put(i);
      });
      await Simulator.tick();
      expect(model.reads.single.data.value, LogicValue.ofInt(encodings[i], 32));
    }
  });
}
