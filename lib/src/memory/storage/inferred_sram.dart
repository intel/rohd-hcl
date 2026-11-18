// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// inferred_sram.dart
// Single-port synchronous inferred SRAM.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/memory/behavioral/behavioral_model.dart';
import 'package:rohd_hcl/src/memory/contracts/memory.dart';
import 'package:rohd_hcl/src/memory/contracts/memory_array.dart';
import 'package:rohd_hcl/src/memory/state/state_transactions.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';
import 'package:rohd_hcl/src/memory/storage/inferred_sram_systemc.dart';
import 'package:rohd_hcl/src/models/memory/memory_storage_state.dart';
import 'package:rohd_hcl/src/models/sparse_memory_storage.dart';

String _sramDefinition<T extends Logic>(
    int entryCount, List<DataPortInterface<T>> writes) {
  if (writes.length != 1) {
    throw ArgumentError('An inferred SRAM requires exactly one write port.');
  }
  final port = writes.single;
  return 'InferredSram_E${entryCount}_A${port.addrWidth}_D${port.dataWidth}_'
      '${payloadShapeIdentity(port.data)}';
}

bool _hasUnpackedPayload(Logic signal) {
  if (signal is TypedLogicArray && signal.numUnpackedDimensions > 0) {
    return true;
  }
  return signal is LogicStructure && signal.elements.any(_hasUnpackedPayload);
}

String _sramVerilog(
        String definitionType, int addrWidth, int dataWidth, int entryCount) =>
    '''
module $definitionType (
  input logic clk, input logic reset,
  input logic wr_en_0, input logic [${addrWidth - 1}:0] wr_addr_0,
  input logic [${dataWidth - 1}:0] wr_data_0,
  input logic rd_en_0, input logic [${addrWidth - 1}:0] rd_addr_0,
  output logic [${dataWidth - 1}:0] rd_data_0
);
  logic [${dataWidth - 1}:0] memory [0:${entryCount - 1}];
  always @(posedge clk) begin
    if (reset)
      rd_data_0 <= '0;
    else if (wr_en_0)
      memory[wr_addr_0] <= wr_data_0 ^ {$dataWidth{1'b0}};
    else if (rd_en_0)
      rd_data_0 <= memory[rd_addr_0];
  end
endmodule
''';

class _PackedSramCell extends Module with SystemVerilog {
  final int addrWidth;
  final int dataWidth;
  final int entryCount;

  Logic get readData => output('rd_data_0');

  _PackedSramCell(
    Logic clk,
    Logic reset,
    DataPortInterface<Logic> write,
    DataPortInterface<Logic> read, {
    required this.entryCount,
  })  : addrWidth = write.addrWidth,
        dataWidth = write.dataWidth,
        super(
            name: 'sram_cell',
            definitionName: 'InferredSramCell_E${entryCount}_'
                'A${write.addrWidth}_D${write.dataWidth}') {
    addInput('clk', clk);
    addInput('reset', reset);
    addInput('wr_en_0', write.en);
    addInput('wr_addr_0', write.addr, width: addrWidth);
    addInput('wr_data_0', write.data.packed, width: dataWidth);
    addInput('rd_en_0', read.en);
    addInput('rd_addr_0', read.addr, width: addrWidth);
    addOutput('rd_data_0', width: dataWidth);
  }

  @override
  String definitionVerilog(String definitionType) =>
      _sramVerilog(definitionType, addrWidth, dataWidth, entryCount);
}

/// A detached SRAM execution image, including the registered read output.
class InferredSramImage {
  final int _entryCount;
  final int _addressWidth;
  final int _dataWidth;
  final List<Logic> _schemas;
  final MemoryStorageImage _storage;
  final LogicValue _output;

  InferredSramImage._(this._entryCount, this._addressWidth, this._dataWidth,
      List<Logic> schemas, this._storage, this._output)
      : _schemas = List.unmodifiable(schemas);
}

/// A synchronous, single-port SRAM described as an inferable Verilog array.
///
/// At most one read or write may be enabled per cycle. Reads take one edge
/// and hold their result when disabled. Reset clears the read output but not
/// the SRAM contents. Uninitialized and out-of-range reads return X; writes to
/// an unknown or out-of-range address do not modify storage.
///
/// The array declaration is intended for synthesis-tool SRAM inference;
/// technology-specific macro mapping is determined by the synthesis flow.
class InferredSram<T extends Logic> extends Memory<T>
    with SystemVerilog
    implements
        BehavioralModel,
        BehavioralModelProvider,
        StateTransactionProvider<InferredSramImage>,
        StateTransactionCapabilityProvider {
  /// Number of words in the array.
  final int entryCount;

  late final SparseMemoryStorage _storage;
  late final MemoryStorageState _raw;
  late final Logic _readValue;
  late final bool _usesPackedCell;

  @override
  late final InferredSramDescription description = InferredSramDescription(
      addressWidth: addrWidth, dataWidth: dataWidth, entryCount: entryCount);

  @override
  BehavioralModel get behavioralModel => this;

  @override
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) =>
      description.generateSystemC(className: className, options: options);

  @override
  int get readLatency => 1;

  @override
  StateTransactionCapabilities get stateTransactionCapabilities =>
      StateTransactionCapabilities.software;

  @override
  late final StateTransactionEndpoint<InferredSramImage> stateTransactions =
      SoftwareStateTransactionAdapter(snapshot: snapshot, restore: restore);

  /// Creates an SRAM with one read port and one write port.
  InferredSram(super.clk, super.reset, super.writePorts, super.readPorts,
      {required this.entryCount, super.name = 'inferred_sram'})
      : super(definitionName: _sramDefinition(entryCount, writePorts)) {
    if (numWrites != 1 ||
        numReads != 1 ||
        entryCount < 1 ||
        BigInt.from(entryCount) > (BigInt.one << addrWidth) ||
        wrPorts.single is MaskedDataPortInterface<T> ||
        rdPorts.single is MaskedDataPortInterface<T>) {
      throw ArgumentError('An inferred SRAM needs one unmasked read and write '
          'port with valid geometry.');
    }
    _storage = SparseMemoryStorage(addrWidth: addrWidth, dataWidth: dataWidth);
    _raw = MemoryStorageState(_storage);
    _usesPackedCell = _hasUnpackedPayload(wrPorts.single.data) ||
        _hasUnpackedPayload(rdPorts.single.data);
    if (_usesPackedCell) {
      final cell = _PackedSramCell(clk, reset, wrPorts.single, rdPorts.single,
          entryCount: entryCount);
      _readValue = cell.readData;
      rdPorts.single.data <= _readValue;
    } else {
      _readValue = rdPorts.single.data;
    }
    putPackedLogicValue(_readValue, LogicValue.filled(dataWidth, LogicValue.x));
    clk.posedge.listen((_) {
      if (reset.previousValue == LogicValue.one) {
        putPackedLogicValue(
            _readValue, LogicValue.filled(dataWidth, LogicValue.zero));
        return;
      }
      final write = wrPorts.single;
      if (write.en.previousValue == LogicValue.one) {
        final address = write.addr.previousValue!;
        if (address.isValid && address.toBigInt() < BigInt.from(entryCount)) {
          _storage.setData(
              address, normalizeStoredValue(write.data.previousValue!));
        }
      } else {
        final read = rdPorts.single;
        if (read.en.previousValue == LogicValue.one) {
          final address = read.addr.previousValue!;
          final value =
              address.isValid && address.toBigInt() < BigInt.from(entryCount)
                  ? _storage.getData(address)
                  : null;
          putPackedLogicValue(
              _readValue, value ?? LogicValue.filled(dataWidth, LogicValue.x));
        }
      }
    });
  }

  void _checkAddress(int address) {
    if (address < 0 || address >= entryCount) {
      throw RangeError.range(address, 0, entryCount - 1, 'address');
    }
  }

  /// Inspects an entry without using the hardware port.
  LogicValue? peek(int address) {
    _checkAddress(address);
    return _raw.peek(address);
  }

  /// Inspects an entry using an arbitrary-width address.
  LogicValue? peekBigInt(BigInt address) {
    if (address.isNegative || address >= BigInt.from(entryCount)) {
      throw RangeError('Address $address is outside SRAM geometry.');
    }
    return _raw.peekBigInt(address);
  }

  /// Initializes an entry without using the hardware port.
  void poke(int address, LogicValue value) {
    _checkAddress(address);
    _raw.poke(address, value);
  }

  /// Initializes an entry using an arbitrary-width address.
  void pokeBigInt(BigInt address, LogicValue value) {
    if (address.isNegative || address >= BigInt.from(entryCount)) {
      throw RangeError('Address $address is outside SRAM geometry.');
    }
    _raw.pokeBigInt(address, value);
  }

  /// Captures the array contents and registered read result.
  InferredSramImage snapshot() => InferredSramImage._(
      entryCount,
      addrWidth,
      dataWidth,
      [
        cloneTypedPayload(wrPorts.single.data),
        cloneTypedPayload(rdPorts.single.data)
      ],
      _raw.snapshot(),
      rdPorts.single.data.value);

  /// Atomically restores an array and read result with matching port schemas.
  void restore(InferredSramImage image) {
    if (image._entryCount != entryCount ||
        image._addressWidth != addrWidth ||
        image._dataWidth != dataWidth ||
        !samePayloadSchemas(
            image._schemas, [wrPorts.single.data, rdPorts.single.data]) ||
        image._output.width != dataWidth ||
        image._storage.uncertainWrites.isNotEmpty ||
        image._storage.entries.keys
            .any((address) => address >= BigInt.from(entryCount))) {
      throw ArgumentError.value(image, 'image', 'Incompatible SRAM state.');
    }
    _raw.load(image._storage, replace: true);
    putPackedLogicValue(_readValue, image._output);
  }

  @override
  // Unpacked payloads need a structural bridge to the packed SRAM cell.
  DefinitionGenerationType get generatedDefinitionType => _usesPackedCell
      ? DefinitionGenerationType.standard
      : DefinitionGenerationType.custom;

  @override
  String definitionVerilog(String definitionType) =>
      _sramVerilog(definitionType, addrWidth, dataWidth, entryCount);
}

/// Creates a single-port, one-cycle inferred SRAM factory.
MemoryArrayFunctor<T> inferredSramArray<T extends Logic>() =>
    MemoryArrayFunctor<T>(
      identity: 'inferredSram1p',
      capabilities: const MemoryArrayCapabilities(
        readLatency: 1,
        readCollision: MemoryArrayReadCollision.unspecified,
        writeCollision: MemoryArrayWriteCollision.disallow,
        supportsMaskedWrites: false,
        implementation: MemoryArrayImplementation.synthesizable,
        maxReadPorts: 1,
        maxWritePorts: 1,
        maxConcurrentReads: 1,
        maxConcurrentWrites: 1,
        maxConcurrentAccesses: 1,
      ),
      build: ({
        required clk,
        required reset,
        required writePorts,
        required readPorts,
        required entryCount,
        required name,
      }) =>
          InferredSram<T>(clk, reset, writePorts, readPorts,
              entryCount: entryCount, name: name),
    );
