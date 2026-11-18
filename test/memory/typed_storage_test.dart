// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_storage_test.dart
// Tests for typed storage modules.
//
// 2026 October 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

// Exercise the legacy FIFO with typed payloads.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/synchronous_associative_lookup_port_interface.dart'
    as general;
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

class _WrongWidthClone extends Logic {
  _WrongWidthClone({super.name, super.width = 8});

  @override
  _WrongWidthClone clone({String? name}) =>
      _WrongWidthClone(name: name ?? this.name, width: width + 1);
}

class _WrongEvictionWidth extends Logic {
  _WrongEvictionWidth({super.name, super.width = 8});

  @override
  _WrongEvictionWidth clone({String? name}) => _WrongEvictionWidth(
      name: name ?? this.name,
      width: name == 'evictionData' ? width + 1 : width);
}

class _MisclonedField extends GfLogic {
  final BinaryExtensionField cloneField;
  final int clonesBeforeChange;

  _MisclonedField(super.field, this.cloneField,
      {this.clonesBeforeChange = 0, super.name});

  @override
  _MisclonedField clone({String? name}) => _MisclonedField(
      clonesBeforeChange == 0 ? cloneField : field, cloneField,
      clonesBeforeChange: clonesBeforeChange == 0 ? 0 : clonesBeforeChange - 1,
      name: name ?? this.name);
}

class _MisclonedNet extends LogicNet implements PayloadShapeMetadata {
  final int clonesBeforeChange;

  @override
  final String payloadShapeMetadata;

  _MisclonedNet(this.payloadShapeMetadata,
      {this.clonesBeforeChange = 0, super.name})
      : super(width: 8);

  @override
  _MisclonedNet clone({String? name}) => _MisclonedNet(
      clonesBeforeChange == 0 ? 'changed' : payloadShapeMetadata,
      clonesBeforeChange: clonesBeforeChange == 0 ? 0 : clonesBeforeChange - 1,
      name: name ?? this.name);
}

enum _Phase { idle, busy, done }

typedef _WordValue = ({LogicValue low, LogicValue high});

_WordValue _decodeWord(LogicValue value) =>
    (low: value.getRange(0, 4), high: value.getRange(4, 8));

LogicValue _encodeWord(_WordValue value) =>
    LogicValue.of([value.high, value.low]);

const _wordCodec =
    LogicValueCodec<_WordValue>(decode: _decodeWord, encode: _encodeWord);

class _PortRegistration extends Module {}

class _MemoryControlOnly extends Interface<DataPortGroup> {
  _MemoryControlOnly() {
    setPorts(
        [Logic.port('en'), Logic.port('addr', 2)], [DataPortGroup.control]);
  }

  @override
  _MemoryControlOnly clone() => _MemoryControlOnly();
}

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

class _PackedBridgeHarness extends Module {
  late final RegisterFile<Logic> rf;

  _PackedBridgeHarness() {
    final packedWrite = DataPortInterface<Logic>(8, 2);
    final typedWrite = DataPortInterface<Logic>.typed(_Word(), 2);
    final typedRead = DataPortInterface<Logic>.typed(_Word(), 2);
    packedWrite.en <= addInput('write', Logic());
    packedWrite.addr <= addInput('address', Logic(width: 2), width: 2);
    packedWrite.data <= addInput('data', Logic(width: 8), width: 8);
    typedWrite.en <= Const(0);
    typedWrite.addr <= Const(0, width: 2);
    typedWrite.data <= Const(0, width: 8);
    typedRead.en <= addInput('read', Logic());
    typedRead.addr <= packedWrite.addr;
    rf = RegisterFile<Logic>(
      addInput('clk', Logic()),
      addInput('reset', Logic()),
      [packedWrite, typedWrite],
      [typedRead],
      numEntries: 3,
    );
    addOutput('result', width: 8) <= typedRead.data;
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

class _ReadyValidQueueHarness<T extends Logic> extends Module {
  late final ReadyValidQueue<T> queue;

  _ReadyValidQueueHarness(T schema, ReadyValidQueueStorage storage) {
    final upstream = ReadyValidInterface<T>(schema.cloneTyped());
    final downstream = ReadyValidInterface<T>(schema.cloneTyped());
    upstream.data <=
        addInput('data', Logic(width: schema.width), width: schema.width);
    upstream.valid <= addInput('write', Logic());
    downstream.ready <= addInput('read', Logic());
    queue = ReadyValidQueue<T>(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      upstream: upstream,
      downstream: downstream,
      depth: 1,
      storage: storage,
    );
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
    expect(samePayloadShape(dut.rf.rdData(0), schema), isTrue);
    expect(samePayloadShape(dut.rf.input('wr_data_0'), schema), isTrue);
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
      expect(samePayloadShape(dut.binding.output, schema), isTrue);
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

  test('memory and cache schemas reject width-changing scalar clones', () {
    final bad = _WrongWidthClone();
    final good = Logic(width: 8);
    final constructors = <void Function()>[
      () => DataPortInterface<_WrongWidthClone>.typed(bad, 2),
      () => MaskedDataPortInterface<_WrongWidthClone>.typed(bad, 2),
      () => TypedAssociativeUpdatePortInterface(bad, indexWidth: 2),
      () => TypedAssociativeLookupPortInterface(bad, indexWidth: 2),
      () =>
          general.SynchronousAssociativeLookupPortInterface(bad, indexWidth: 2),
      () => TypedAssociativeIndexedSideReadResponse(bad),
      () => TagInterface<_WrongWidthClone>.typed(2, bad),
      () => CacheLookupPort(addressWidth: 8, dataSchema: bad),
      () => CacheFillPort(addressWidth: 8, dataSchema: bad),
      () => CacheFillPort(addressWidth: 8, dataSchema: _WrongEvictionWidth()),
      for (var position = 0; position < 3; position++)
        () => CacheTransactionRequest<Logic, Logic, Logic>(
              addressWidth: 8,
              tokenWidth: 2,
              dataSchema: position == 0 ? bad : good,
              writeMaskWidth: 1,
              lineMetadataSchema: position == 1 ? bad : good,
              contextSchema: position == 2 ? bad : good,
            ),
      for (var position = 0; position < 4; position++)
        () => CacheTransactionResponse<Logic, Logic, Logic, Logic>(
              tokenWidth: 2,
              dataSchema: position == 0 ? bad : good,
              lineMetadataSchema: position == 1 ? bad : good,
              contextSchema: position == 2 ? bad : good,
              resultSchema: position == 3 ? bad : good,
            ),
      for (var position = 0; position < 3; position++)
        () => CacheTransactionEviction<Logic, Logic, Logic>(
              addressWidth: 8,
              tokenWidth: 2,
              dataSchema: position == 0 ? bad : good,
              lineMetadataSchema: position == 1 ? bad : good,
              contextSchema: position == 2 ? bad : good,
            ),
    ];
    for (final (index, construct) in constructors.indexed) {
      expect(construct, throwsA(isA<RohdHclException>()),
          reason: 'schema constructor $index must reject a changed width');
    }
  });

  final firstField =
      BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(0x11b)));
  final secondField =
      BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(0x11d)));
  final malformedSchema = _MisclonedField(firstField, secondField);
  final schemaConstructors = <String, Object Function()>{
    'memory': () => DataPortInterface<Logic>.typed(malformedSchema, 2),
    'masked memory': () =>
        MaskedDataPortInterface<Logic>.typed(malformedSchema, 2),
    'CAM tag': () => TagInterface<Logic>.typed(2, malformedSchema),
    'associative update': () => TypedAssociativeUpdatePortInterface<Logic>(
        malformedSchema,
        indexWidth: 2),
    'associative lookup': () => TypedAssociativeLookupPortInterface<Logic>(
        malformedSchema,
        indexWidth: 2),
    'synchronous lookup': () =>
        general.SynchronousAssociativeLookupPortInterface<Logic>(
            malformedSchema,
            indexWidth: 2),
    'associative side read': () =>
        TypedAssociativeIndexedSideReadResponse<Logic>(malformedSchema),
    'cache lookup': () =>
        CacheLookupPort<Logic>(addressWidth: 2, dataSchema: malformedSchema),
    'cache fill': () =>
        CacheFillPort<Logic>(addressWidth: 2, dataSchema: malformedSchema),
  };
  for (final entry in schemaConstructors.entries) {
    test('${entry.key} rejects a clone with changed payload metadata', () {
      expect(entry.value, throwsA(isA<LogicConstructionException>()));
    });
  }

  for (final output in [false, true]) {
    for (final unchangedClones in output ? [1] : [1, 2]) {
      test(
          'memory ${output ? 'output' : 'input'} rejects a changed port clone '
          'after $unchangedClones unchanged clones', () {
        final schema = _MisclonedField(firstField, secondField,
            clonesBeforeChange: unchangedClones);
        final target = DataPortInterface<Logic>.typed(schema, 2);
        final packedSource = DataPortInterface<Logic>(schema.width, 2);
        expect(
            () => target.connectIO(_PortRegistration(), packedSource,
                inputTags: output ? null : [DataPortGroup.data],
                outputTags: output ? [DataPortGroup.data] : null),
            throwsA(anyOf(
                isA<LogicConstructionException>(), isA<PortTypeException>())));
      });
    }
  }
  for (final unchangedClones in [1, 2]) {
    test('memory inout rejects a changed clone after $unchangedClones clones',
        () {
      final schema =
          _MisclonedNet('original', clonesBeforeChange: unchangedClones);
      final target = DataPortInterface<Logic>.typed(schema, 2);
      final source = DataPortInterface<Logic>.typed(LogicNet(width: 8), 2);
      expect(
          () => target.connectIO(_PortRegistration(), source,
              inOutTags: [DataPortGroup.data]),
          throwsA(anyOf(
              isA<LogicConstructionException>(), isA<PortTypeException>())));
    });
  }

  test('memory output rejects a constant clone flattened by registration', () {
    final schema = LogicStructure([Const(0, width: 8)], name: 'data');
    final target = DataPortInterface<Logic>.typed(schema, 2);
    final source = DataPortInterface<Logic>(8, 2);
    expect(
        () => target.connectIO(_PortRegistration(), source,
            outputTags: [DataPortGroup.data]),
        throwsA(isA<RohdHclException>()));
  });

  test('unselected memory payloads do not constrain port registration', () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));

    final memoryTarget = DataPortInterface<Logic>.typed(GfLogic(first), 2);
    final memorySource = DataPortInterface<Logic>.typed(GfLogic(second), 2);
    final memoryModule = _PortRegistration();
    memoryTarget.connectIO(memoryModule, memorySource,
        inputTags: [DataPortGroup.control]);
    expect(memoryModule.inputs.keys, containsAll(['en', 'addr']));
    expect(memoryModule.inputs, isNot(contains('data')));
    final controlOnly = _PortRegistration();
    DataPortInterface<Logic>.typed(GfLogic(first), 2).connectIO(
        controlOnly, _MemoryControlOnly(),
        inputTags: [DataPortGroup.control]);
    expect(controlOnly.inputs.keys, containsAll(['en', 'addr']));
    expect(
        () => DataPortInterface<Logic>.typed(GfLogic(first), 2).connectIO(
            _PortRegistration(), memorySource,
            inputTags: [DataPortGroup.data]),
        throwsA(isA<PortTypeException>()));
    expect(
        () => DataPortInterface<Logic>.typed(GfLogic(first), 2).connectIO(
            _PortRegistration(), memorySource,
            outputTags: [DataPortGroup.data]),
        throwsA(isA<PortTypeException>()));

    final updateTarget = TypedAssociativeUpdatePortInterface<Logic>(
        GfLogic(first),
        indexWidth: 2);
    final updateSource = TypedAssociativeUpdatePortInterface<Logic>(
        GfLogic(second),
        indexWidth: 2);
    final updateModule = _PortRegistration();
    updateTarget.connectIO(updateModule, updateSource,
        inputTags: [DataPortGroup.control]);
    expect(updateModule.inputs.keys, containsAll(['en', 'index']));
    expect(updateModule.inputs, isNot(contains('key')));
    expect(
        () => TypedAssociativeUpdatePortInterface<Logic>(GfLogic(first),
                indexWidth: 2)
            .connectIO(_PortRegistration(), updateSource,
                inputTags: [DataPortGroup.data]),
        throwsA(isA<PortTypeException>()));

    final lookupTarget = TypedAssociativeLookupPortInterface<Logic>(
        GfLogic(first),
        indexWidth: 2);
    final lookupSource = TypedAssociativeLookupPortInterface<Logic>(
        GfLogic(second),
        indexWidth: 2);
    final lookupModule = _PortRegistration();
    lookupTarget.connectIO(lookupModule, lookupSource,
        outputTags: [DataPortGroup.data]);
    expect(lookupModule.outputs.keys, containsAll(['hit', 'index']));
    expect(lookupModule.inputs, isNot(contains('key')));
    expect(
        () => TypedAssociativeLookupPortInterface<Logic>(GfLogic(first),
                indexWidth: 2)
            .connectIO(_PortRegistration(), lookupSource,
                inputTags: [DataPortGroup.control]),
        throwsA(isA<PortTypeException>()));

    final camTarget = TagInterface<Logic>.typed(2, GfLogic(first));
    final camSource = TagInterface<Logic>.typed(2, GfLogic(second));
    final camModule = _PortRegistration();
    camTarget.connectIO(camModule, camSource, outputTags: [DataPortGroup.data]);
    expect(camModule.outputs.keys, containsAll(['hit', 'idx']));
    expect(camModule.inputs, isNot(contains('tag')));
    expect(
        () => TagInterface<Logic>.typed(2, GfLogic(first)).connectIO(
            _PortRegistration(), camSource,
            inputTags: [DataPortGroup.control]),
        throwsA(isA<PortTypeException>()));
  });

  test('typed memory inout connects nets bidirectionally', () {
    final external = DataPortInterface<LogicNet>.typed(LogicNet(width: 3), 2);
    final module = _PortRegistration();
    final internal =
        module.addInterfacePorts(external, inOutTags: [DataPortGroup.data]);
    final outsideDrive = Logic(width: 3)
      ..put(LogicValue.filled(3, LogicValue.z));
    final insideDrive = Logic(width: 3)
      ..put(LogicValue.filled(3, LogicValue.z));
    external.data <= outsideDrive;
    internal.data <= insideDrive;

    insideDrive.put(5);
    expect(external.data.value.toInt(), 5);
    insideDrive.put(LogicValue.filled(3, LogicValue.z));
    outsideDrive.put(3);
    expect(internal.data.value.toInt(), 3);
  });

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
      expect(samePayloadShape(dut.fifo.upstream.data, schema), isTrue);
      expect(samePayloadShape(dut.fifo.downstream.data, schema), isTrue);
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
      expect(samePayloadShape(dut.fifo.downstream.data, schema), isTrue);
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

  for (final storage in ReadyValidQueueStorage.values) {
    test('ready/valid queue $storage retains typed array codec', () async {
      final schema = TypedLogicArray<_Word, _WordValue>([2], _Word.new,
          valueCodec: _wordCodec);
      final dut = _ReadyValidQueueHarness(schema, storage);
      expect(samePayloadShape(dut.queue.upstream.data, schema), isTrue);
      expect(samePayloadShape(dut.queue.downstream.data, schema), isTrue);
      expect(dut.queue.downstream.data.valueCodec, same(_wordCodec));
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

  test('packed memory port cannot hide incompatible declared formats', () {
    for (final behavioral in [false, true]) {
      for (final packedIsWrite in [false, true]) {
        final packed = DataPortInterface<Logic>(8, 2);
        final signed = DataPortInterface<Logic>.typed(
            FixedPoint(integerWidth: 3, fractionWidth: 4), 2);
        final unsigned = DataPortInterface<Logic>.typed(
            FixedPoint(integerWidth: 4, fractionWidth: 4, signed: false), 2);
        final writes = packedIsWrite ? [packed] : <DataPortInterface<Logic>>[];
        final reads =
            packedIsWrite ? [signed, unsigned] : [packed, signed, unsigned];
        expect(
          () => behavioral
              ? MemoryModel<Logic>.registerFile(Logic(), Logic(), writes, reads,
                  numEntries: 3)
              : RegisterFile<Logic>(Logic(), Logic(), writes, reads,
                  numEntries: 3),
          throwsA(isA<RohdHclException>()),
          reason: 'behavioral=$behavioral packedIsWrite=$packedIsWrite',
        );
      }
    }

    final first = TypedLogicArray<Logic, LogicValue>(
        [2], ({name}) => Logic(width: 4, name: name));
    final second = TypedLogicArray<Logic, LogicValue>(
        [4], ({name}) => Logic(width: 2, name: name));
    expect(
      () => RegisterFile<Logic>(
        Logic(),
        Logic(),
        [DataPortInterface<Logic>(8, 2)],
        [
          DataPortInterface<Logic>.typed(first, 2),
          DataPortInterface<Logic>.typed(second, 2),
        ],
      ),
      throwsA(isA<RohdHclException>()),
    );
  });

  test('packed-first memory accepts matching typed payloads', () async {
    final dut = _PackedBridgeHarness();
    expect(dut.rf.rdData(0), isA<_Word>());
    final model = MemoryModel<Logic>.registerFile(
      Logic(),
      Logic(),
      [
        DataPortInterface<Logic>(8, 2),
        DataPortInterface<Logic>.typed(_Word(), 2),
      ],
      [DataPortInterface<Logic>.typed(_Word(), 2)],
      numEntries: 3,
    );
    expect(model.input('wr_data_1'), isA<_Word>());
    await _compare(dut, [
      Vector({
        'clk': 0,
        'reset': 1,
        'write': 0,
        'read': 1,
        'address': 1,
        'data': 0xab,
      }, {}),
      Vector({'clk': 1}, {'result': 0}),
      Vector({'clk': 0, 'reset': 0, 'write': 1}, {}),
      Vector({'clk': 1}, {'result': 0xab}),
      Vector({'clk': 0, 'write': 0}, {'result': 0xab}),
    ]);
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
    expect(samePayloadShape(first, renamed), isTrue);
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
