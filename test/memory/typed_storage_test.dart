// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_storage_test.dart
// Tests for typed storage modules.
//
// 2026 October 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:test/test.dart';

class _Word extends LogicStructure {
  Logic get low => elements[0];
  Logic get high => elements[1];

  _Word({String? name})
      : super([Logic(name: 'low', width: 4), Logic(name: 'high', width: 4)],
            name: name ?? 'word');

  @override
  _Word clone({String? name}) => _Word(name: name ?? this.name);
}

enum _Phase { idle, busy, done }

typedef _WordValue = ({LogicValue low, LogicValue high});

_WordValue _decodeWord(LogicValue value) =>
    (low: value.getRange(0, 4), high: value.getRange(4, 8));

LogicValue _encodeWord(_WordValue value) =>
    LogicValue.of([value.high, value.low]);

const _wordCodec =
    LogicValueCodec<_WordValue>(decode: _decodeWord, encode: _encodeWord);

class _RegisterHarness<T extends Logic> extends Module {
  late final RegisterFile<T> rf;

  _RegisterHarness(T schema, {bool masked = false}) {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final first = masked
        ? MaskedDataPortInterface<T>.typed(schema, 2)
        : DataPortInterface<T>.typed(schema, 2);
    final second = DataPortInterface<T>.typed(schema, 2);
    final read = DataPortInterface<T>.typed(schema, 2);
    first.data <=
        addInput('data', Logic(width: schema.width), width: schema.width);
    second.data <=
        addInput('secondData', Logic(width: schema.width), width: schema.width);
    first.en <= addInput('write', Logic());
    second.en <= addInput('secondWrite', Logic());
    first.addr <= addInput('address', Logic(width: 2), width: 2);
    second.addr <= first.addr;
    read.addr <= first.addr;
    read.en <= addInput('read', Logic());
    if (first is MaskedDataPortInterface<T>) {
      first.mask <=
          addInput('mask', Logic(width: schema.width ~/ 8),
              width: schema.width ~/ 8);
    }
    rf = RegisterFile<T>(clk, reset, [first, second], [read],
        numEntries: 3, resetValue: [1, 2, 1]);
    addOutput('result', width: schema.width) <= rf.rdData(0);
  }
}

class _FifoHarness<T extends Logic> extends Module {
  late final FifoCoreBinding<T> binding;

  _FifoHarness(T schema, int depth) {
    final data = schema.cloneTyped(name: 'payload');
    data <= addInput('data', Logic(width: schema.width), width: schema.width);
    binding = FifoCoreFunctor<T>(depth: depth, generateBypass: true).construct(
        FifoCoreRequest<T>(
            clk: addInput('clk', Logic()),
            reset: addInput('reset', Logic()),
            enqueue: addInput('write', Logic()),
            dequeue: addInput('read', Logic()),
            payload: data),
        name: 'core');
    addOutput('result', width: schema.width) <= binding.output;
    addOutput('full') <= binding.full;
    addOutput('empty') <= binding.empty;
  }
}

class _ReadyValidHarness<T extends Logic> extends Module {
  late final ReadyValidFifo<T> fifo;

  _ReadyValidHarness(T schema) {
    final upstream = ReadyValidInterface<T>(schema.cloneTyped());
    final downstream = ReadyValidInterface<T>(schema.cloneTyped());
    upstream.data <=
        addInput('data', Logic(width: schema.width), width: schema.width);
    upstream.valid <= addInput('write', Logic());
    downstream.ready <= addInput('read', Logic());
    fifo = ReadyValidFifo<T>(
        clk: addInput('clk', Logic()),
        reset: addInput('reset', Logic()),
        upstream: upstream,
        downstream: downstream,
        depth: 3);
    addOutput('result', width: schema.width) <= downstream.data;
    addOutput('valid') <= downstream.valid;
    addOutput('ready') <= upstream.ready;
  }
}

Future<void> _compare(Module dut, List<Vector> vectors,
    {bool verilator = false, bool systemC = false}) async {
  await dut.build();
  await SimCompare.checkFunctionalVector(dut, vectors);
  if (systemC) {
    expect(SimCompare.checkSystemCVector(dut, vectors), isTrue);
  } else if (verilator) {
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
  } else {
    SimCompare.checkIverilogVector(dut, vectors);
  }
}

void _checkStorage<T extends Logic>(String label, T schema,
    {bool verilator = false, bool systemC = false}) {
  final backend =
      systemC ? 'SystemC' : (verilator ? 'Icarus and Verilator' : 'Icarus');
  // Exercise reset, synchronous writes, disabled/out-of-range reads, and
  // simultaneous writes to the same entry (the later port wins).
  test('$label register file functional and $backend', () async {
    final dut = _RegisterHarness<T>(schema);
    expect(sameDeclaredPayloadShape(dut.rf.rdData(0), schema), isTrue);
    expect(sameDeclaredPayloadShape(dut.rf.input('wr_data_0'), schema), isTrue);
    await _compare(
        dut,
        [
          Vector({
            'clk': 0,
            'reset': 1,
            'address': 0,
            'write': 0,
            'secondWrite': 0,
            'data': 1,
            'secondData': 2,
            'read': 1,
          }, {}),
          Vector({'clk': 1}, {'result': 1}),
          Vector({'clk': 0, 'reset': 0, 'address': 1}, {'result': 2}),
          Vector({'write': 1, 'secondWrite': 1}, {'result': 2}),
          Vector({'clk': 1}, {'result': 2}),
          Vector({'clk': 0, 'secondWrite': 0}, {}),
          Vector({'clk': 1}, {'result': 1}),
          Vector({'clk': 0, 'write': 0, 'read': 0}, {'result': 0}),
          Vector({'read': 1, 'address': 3}, {'result': 0}),
          Vector({'address': 1}, {'result': 1}),
          Vector({'reset': 1}, {}),
          Vector({'clk': 1}, {'result': 2}),
        ],
        verilator: verilator,
        systemC: systemC);
    expect(dut.rf.getData(LogicValue.ofInt(1, 2))!.toInt(), 2);
    dut.rf.setData(LogicValue.ofInt(1, 2), LogicValue.ofInt(1, schema.width));
    expect(dut.rf.getData(LogicValue.ofInt(1, 2))!.toInt(), 1);
  });

  for (final depth in [1, 3]) {
    // Fill, replace while full, drain in order, then bypass while empty.
    test('$label FIFO depth $depth functional and $backend', () async {
      final dut = _FifoHarness<T>(schema, depth);
      expect(sameDeclaredPayloadShape(dut.binding.output, schema), isTrue);
      final vectors = [
        Vector({'clk': 0, 'reset': 1, 'data': 1, 'write': 0, 'read': 0}, {}),
        Vector({'clk': 1}, {'empty': 1}),
        Vector({'clk': 0, 'reset': 0, 'write': 1}, {}),
        for (var i = 0; i < depth; i++) ...[
          Vector({'clk': 1}, {'result': 1}),
          Vector({'clk': 0}, {}),
        ],
        Vector({'write': 1, 'read': 1, 'data': 2}, {'full': 1, 'result': 1}),
        Vector({'clk': 1}, {'full': 1, 'result': depth == 1 ? 2 : 1}),
        Vector({'clk': 0, 'write': 0}, {}),
        for (var i = 1; i < depth; i++) ...[
          Vector({'clk': 1}, {'result': i == depth - 1 ? 2 : 1}),
          Vector({'clk': 0}, {}),
        ],
        Vector({'clk': 1}, {'empty': 1}),
        Vector({'clk': 0, 'write': 1, 'data': 1}, {'result': 1}),
        Vector({'clk': 1}, {'empty': 1, 'result': 1}),
      ];
      await _compare(dut, vectors, verilator: verilator, systemC: systemC);
    });
  }
}

void main() {
  tearDown(Simulator.reset);

  for (final schema in <Logic>[
    Logic(width: 8),
    LogicEnum<_Phase>(_Phase.values),
    _Word(),
    TypedLogicArray<_Word, LogicValue>([], _Word.new),
    TypedLogicArray<_Word, _WordValue>([2], _Word.new, valueCodec: _wordCodec),
  ]) {
    // A full FIFO cannot replace an entry on the same cycle it dequeues.
    test('ready/valid ${schema.runtimeType} full backpressure', () async {
      final dut = _ReadyValidHarness(schema);
      expect(sameDeclaredPayloadShape(dut.fifo.upstream.data, schema), isTrue);
      expect(
          sameDeclaredPayloadShape(dut.fifo.downstream.data, schema), isTrue);
      await _compare(dut, [
        Vector({'clk': 0, 'reset': 1, 'data': 1, 'write': 0, 'read': 0}, {}),
        Vector({'clk': 1}, {'valid': 0}),
        Vector({'clk': 0, 'reset': 0, 'write': 1}, {'ready': 1}),
        Vector({'clk': 1}, {'valid': 1, 'result': 1}),
        Vector({'clk': 0, 'data': 2}, {}),
        Vector({'clk': 1}, {'result': 1}),
        Vector({'clk': 0, 'data': 1}, {}),
        Vector({'clk': 1}, {'ready': 0, 'result': 1}),
        Vector({'clk': 0, 'read': 1, 'data': 2}, {'ready': 0}),
        Vector({'clk': 1}, {'ready': 1, 'result': 2}),
        Vector({'clk': 0, 'write': 0}, {}),
        Vector({'clk': 1}, {'valid': 1, 'result': 1}),
        Vector({'clk': 0}, {}),
        Vector({'clk': 1}, {'valid': 0}),
      ]);
    });
  }

  _checkStorage('plain', Logic(width: 8));
  _checkStorage('plain SystemC', Logic(width: 8), systemC: true);
  _checkStorage('structure', _Word());
  _checkStorage('enum', LogicEnum<_Phase>(_Phase.values));
  _checkStorage('legacy array', LogicArray([2, 2], 2));
  _checkStorage(
      'unpacked typed array',
      TypedLogicArray<_Word, LogicValue>([2, 2], _Word.new,
          numUnpackedDimensions: 1),
      verilator: true);
  _checkStorage(
      'unpacked SystemC',
      TypedLogicArray<_Word, LogicValue>([2, 2], _Word.new,
          numUnpackedDimensions: 1),
      systemC: true);
  _checkStorage(
      'custom codec',
      TypedLogicArray<_Word, _WordValue>([2], _Word.new,
          valueCodec: _wordCodec));
  for (final dimensions in [
    <int>[],
    [2, 2]
  ]) {
    final schema = TypedLogicArray<_Word, LogicValue>(dimensions, _Word.new);
    _checkStorage('typed $dimensions', schema);

    // Hold the consumer stalled across several cycles before draining.
    test('ready/valid typed $dimensions functional and Icarus', () async {
      final dut = _ReadyValidHarness(schema);
      expect(
          sameDeclaredPayloadShape(dut.fifo.downstream.data, schema), isTrue);
      await _compare(dut, [
        Vector({'clk': 0, 'reset': 1, 'data': 1, 'write': 0, 'read': 0}, {}),
        Vector({'clk': 1}, {'valid': 0}),
        Vector({'clk': 0, 'reset': 0, 'write': 1}, {'ready': 1}),
        Vector({'clk': 1}, {'valid': 1, 'result': 1}),
        Vector({'clk': 0, 'write': 0, 'data': 2}, {'result': 1}),
        Vector({'clk': 1}, {'valid': 1, 'result': 1}),
        Vector({'clk': 0, 'read': 1}, {'result': 1}),
        Vector({'clk': 1}, {'valid': 0}),
      ]);
    });
  }

  // Merge bytes with the original entry rather than replacing the whole word.
  test('typed masked writes preserve untouched bytes', () async {
    final schema = TypedLogicArray<_Word, LogicValue>([2], _Word.new);
    await _compare(_RegisterHarness(schema, masked: true), [
      Vector({
        'clk': 0,
        'reset': 1,
        'address': 0,
        'write': 0,
        'secondWrite': 0,
        'data': 0xabcd,
        'secondData': 0,
        'read': 1,
        'mask': 1,
      }, {}),
      Vector({'clk': 1}, {'result': 1}),
      Vector({'clk': 0, 'reset': 0, 'write': 1}, {}),
      Vector({'clk': 1}, {'result': 0xcd}),
      Vector({'clk': 0, 'mask': 2}, {}),
      Vector({'clk': 1}, {'result': 0xabcd}),
    ]);
  });

  test('memory rejects equal-width incompatible array layouts', () {
    final first = TypedLogicArray<_Word, LogicValue>([2, 2], _Word.new);
    final second = TypedLogicArray<_Word, LogicValue>([4], _Word.new);
    expect(
        () => RegisterFile(
            Logic(),
            Logic(),
            [DataPortInterface.typed(first, 2)],
            [DataPortInterface.typed(second, 2)]),
        throwsA(isA<RohdHclException>()));
    expect(payloadShapeIdentity(first), isNot(payloadShapeIdentity(second)));
  });

  test('typed memory clones preserve codec and reject incompatible codecs', () {
    final schema = TypedLogicArray<_Word, _WordValue>([2], _Word.new,
        valueCodec: _wordCodec);
    final differentCodec = LogicValueCodec<_WordValue>(
        decode: (value) =>
            (low: value.getRange(0, 4), high: value.getRange(4, 8)),
        encode: _encodeWord);
    final incompatible = TypedLogicArray<_Word, _WordValue>([2], _Word.new,
        valueCodec: differentCodec);
    final port = DataPortInterface.typed(schema, 2);
    expect(port.data.valueCodec, same(_wordCodec));
    expect(port.clone().data.valueCodec, same(_wordCodec));
    expect(port.data, isNot(same(schema)));
    expect(
        () => RegisterFile(Logic(), Logic(), [port],
            [DataPortInterface.typed(incompatible, 2)]),
        throwsA(isA<RohdHclException>()));
  });

  test('ready/valid typed layout ignores axis names but retains dimensions',
      () {
    final first = TypedLogicArray<_Word, LogicValue>([2, 2], _Word.new,
        dimensionNames: ['rows', 'columns']);
    final renamed = TypedLogicArray<_Word, LogicValue>([2, 2], _Word.new,
        dimensionNames: ['x', 'y']);
    final reshaped = TypedLogicArray<_Word, LogicValue>([4], _Word.new);
    expect(sameDeclaredPayloadShape(first, renamed), isTrue);
    expect(payloadShapeIdentity(first), payloadShapeIdentity(renamed));
    expect(
        () => ReadyValidFifo(
            clk: Logic(),
            reset: Logic(),
            upstream: ReadyValidInterface(first),
            downstream: ReadyValidInterface(reshaped)),
        throwsA(isA<PortTypeException>()));
  });
}
