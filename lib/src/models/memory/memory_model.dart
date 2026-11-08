// Copyright (C) 2021-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_model.dart
// A model for `Memory`
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';

/// Static configuration for a behavioral model of a [RegisterFile].
class RegisterFileModelConfiguration {
  /// Number of implemented entries.
  final int numEntries;

  /// Reset values in entry order.
  final List<LogicValue> resetValues;

  /// Creates a configuration with one reset value per entry.
  RegisterFileModelConfiguration({
    required this.numEntries,
    required Iterable<LogicValue> resetValues,
  }) : resetValues = List.unmodifiable(resetValues) {
    if (numEntries < 1 || this.resetValues.length != numEntries) {
      throw ArgumentError('Register-file reset values must match its size.');
    }
  }
}

class _PendingMemoryRead {
  final int port;
  final LogicValue value;
  int remaining;
  bool scheduled = false;

  _PendingMemoryRead(this.port, this.value, this.remaining);

  _PendingMemoryRead copy() => _PendingMemoryRead(port, value, remaining);
}

/// Detached memory state including delayed reads and their output values.
class MemoryModelImage {
  /// Stored words and symbolic uncertain-address writes.
  final MemoryStorageImage storage;

  final int _addressWidth;
  final int _dataWidth;
  final int _readLatency;
  final int _writePortCount;
  final bool _asyncReset;
  final RegisterFileModelConfiguration? _registerFile;
  final List<String> _portShapes;
  final List<LogicValue> _readOutputs;
  final List<_PendingMemoryRead> _pending;

  /// Number of sampled reads that have not yet updated their outputs.
  int get pendingReadCount => _pending.length;

  MemoryModelImage._({
    required this.storage,
    required int addressWidth,
    required int dataWidth,
    required int readLatency,
    required int writePortCount,
    required bool asyncReset,
    required RegisterFileModelConfiguration? registerFile,
    required List<String> portShapes,
    required List<LogicValue> readOutputs,
    required List<_PendingMemoryRead> pending,
  })  : _addressWidth = addressWidth,
        _dataWidth = dataWidth,
        _readLatency = readLatency,
        _writePortCount = writePortCount,
        _asyncReset = asyncReset,
        _registerFile = registerFile,
        _portShapes = List.unmodifiable(portShapes),
        _readOutputs = List.unmodifiable(readOutputs),
        _pending = List.unmodifiable(pending.map((read) => read.copy()));
}

/// A model of a [Memory] which uses a software-based [SparseMemoryStorage] to
/// store data.
///
/// This is useful to mimic a large memory.  This is *not* synthesizable, it is
/// only a model. Ports preserve payload type [T]; storage retains lossless
/// four-state bit patterns rather than converting through semantic values.
class MemoryModel<T extends Logic> extends Memory<T>
    implements
        BehavioralModel,
        BehavioralModelProvider,
        StateTransactionProvider<MemoryModelImage>,
        StateTransactionCapabilityProvider {
  /// The memory storage underlying this model.
  late final MemoryStorage storage;

  /// If `true`, a positive edge on reset will reset the memory asynchronously.
  final bool asyncReset;

  final bool _usesDefaultStorage;

  /// Register-file semantics, or null for the general sparse-memory model.
  final RegisterFileModelConfiguration? registerFile;

  @override
  final int readLatency;

  final List<_PendingMemoryRead> _pendingReads = [];
  int _readGeneration = 0;

  @override
  late final MemoryModelDescription description = MemoryModelDescription(
      addressWidth: addrWidth,
      dataWidth: dataWidth,
      readLatency: readLatency,
      asyncReset: asyncReset,
      registerFile: registerFile,
      writeMasked: [
        for (final port in wrPorts) port is MaskedDataPortInterface<T>
      ],
      readMasked: [
        for (final port in rdPorts) port is MaskedDataPortInterface<T>
      ]);

  @override
  BehavioralModel get behavioralModel => this;

  @override
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) {
    if (!_usesDefaultStorage ||
        T != Logic ||
        [...wrPorts, ...rdPorts]
            .any((port) => port.data.runtimeType != Logic)) {
      throw UnsupportedError('MemoryModel SystemC requires default storage and '
          'plain Logic payloads; custom behavior requires a portable '
          'provider.');
    }
    return description.generateSystemC(className: className, options: options);
  }

  @override
  StateTransactionCapabilities get stateTransactionCapabilities =>
      StateTransactionCapabilities.software;

  @override
  late final StateTransactionEndpoint<MemoryModelImage> stateTransactions =
      SoftwareStateTransactionAdapter(snapshot: snapshot, restore: restore);

  /// Creates a new [MemoryModel].
  ///
  /// If no [storage] is provided, a default storage will be created.
  MemoryModel(
    super.clk,
    super.reset,
    super.writePorts,
    super.readPorts, {
    this.readLatency = 1,
    this.asyncReset = true,
    MemoryStorage? storage,
    this.registerFile,
    super.name = 'memory_model',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  })  : _usesDefaultStorage = storage == null,
        super(
            definitionName: definitionName ??
                'MemoryModel_W${writePorts.length}_R${readPorts.length}') {
    if (registerFile != null) {
      if (readLatency != 0 || asyncReset || storage != null) {
        throw ArgumentError(
            'Register-file modeling requires zero read latency, '
            'synchronous reset, and default storage.');
      }
      if (registerFile!.resetValues.any((value) => value.width != dataWidth)) {
        throw ArgumentError('Register-file reset value width does not match.');
      }
      if (rdPorts.any((port) => port is MaskedDataPortInterface<T>)) {
        throw ArgumentError('RegisterFile does not support masked read ports.');
      }
    }
    this.storage = storage ??
        SparseMemoryStorage(addrWidth: addrWidth, dataWidth: dataWidth);

    _buildLogic();
  }

  /// Models the finite, synchronously reset, combinational-read [RegisterFile].
  ///
  /// Reset values are static and given per entry. A null list resets to zero.
  MemoryModel.registerFile(
    Logic clk,
    Logic reset,
    List<DataPortInterface<T>> writePorts,
    List<DataPortInterface<T>> readPorts, {
    int numEntries = 8,
    List<LogicValue>? resetValues,
    String name = 'memory_model',
    bool reserveName = false,
    bool reserveDefinitionName = false,
    String? definitionName,
  }) : this(
          clk,
          reset,
          writePorts,
          readPorts,
          readLatency: 0,
          asyncReset: false,
          registerFile: RegisterFileModelConfiguration(
            numEntries: numEntries,
            resetValues: resetValues ??
                List.filled(
                    numEntries,
                    LogicValue.filled(
                        writePorts.isNotEmpty
                            ? writePorts.first.dataWidth
                            : readPorts.isNotEmpty
                                ? readPorts.first.dataWidth
                                : 1,
                        LogicValue.zero)),
          ),
          name: name,
          reserveName: reserveName,
          reserveDefinitionName: reserveDefinitionName,
          definitionName: definitionName,
        );

  void _buildRegisterFileLogic() {
    final config = registerFile!;
    clk.posedge.listen((event) {
      if (reset.previousValue == LogicValue.one) {
        storage.reset();
        for (var index = 0; index < config.numEntries; index++) {
          if (BigInt.from(index) < BigInt.one << addrWidth) {
            storage.setData(LogicValue.ofInt(index, addrWidth),
                normalizeStoredValue(config.resetValues[index]));
          }
        }
      } else {
        for (var index = 0; index < config.numEntries; index++) {
          if (BigInt.from(index) >= BigInt.one << addrWidth) {
            continue;
          }
          final address = LogicValue.ofInt(index, addrWidth);
          final old = storage.getData(address) ??
              LogicValue.filled(dataWidth, LogicValue.x);
          for (final port in wrPorts) {
            final pattern = port.addr.previousValue!;
            var selection = port.en.previousValue!;
            for (var bit = 0; bit < addrWidth; bit++) {
              final candidate = pattern[bit];
              selection &= !candidate.isValid
                  ? LogicValue.x
                  : candidate == address[bit]
                      ? LogicValue.one
                      : LogicValue.zero;
            }
            if (selection == LogicValue.zero) {
              continue;
            }
            final input = port.data.previousValue!;
            final mask = port is MaskedDataPortInterface<T>
                ? port.mask.previousValue!
                : null;
            final result = mask == null
                ? selection == LogicValue.one
                    ? input
                    : LogicValue.filled(dataWidth, LogicValue.x)
                : [
                    for (var byte = 0; byte < mask.width; byte++)
                      if (mask[byte] == LogicValue.zero)
                        old.getRange(byte * 8, (byte + 1) * 8)
                      else if (selection != LogicValue.one ||
                          mask[byte] != LogicValue.one)
                        LogicValue.filled(8, LogicValue.x)
                      else
                        input.getRange(byte * 8, (byte + 1) * 8)
                  ].rconcat();
            storage.setData(address, normalizeStoredValue(result));
          }
        }
      }
      rdPorts.forEach(_updateRegisterFileRead);
    });
    for (final port in rdPorts) {
      port.en.glitch.listen((_) => _updateRegisterFileRead(port));
      port.addr.glitch.listen((_) => _updateRegisterFileRead(port));
    }
    Simulator.injectAction(() => rdPorts.forEach(_updateRegisterFileRead));
  }

  void _updateRegisterFileRead(DataPortInterface<T> port) {
    final enable = port.en.value;
    final address = port.addr.value;
    final LogicValue result;
    if (enable == LogicValue.zero) {
      result = LogicValue.filled(dataWidth, LogicValue.zero);
    } else if (enable != LogicValue.one || !address.isValid) {
      result = LogicValue.filled(dataWidth, LogicValue.x);
    } else if (address.toBigInt() >= BigInt.from(registerFile!.numEntries)) {
      result = LogicValue.filled(dataWidth, LogicValue.zero);
    } else {
      result = storage.getData(address) ??
          LogicValue.filled(dataWidth, LogicValue.x);
    }
    _putReadData(port, result);
  }

  void _buildLogic() {
    if (registerFile != null) {
      _buildRegisterFileLogic();
      return;
    }
    if (asyncReset) {
      reset.posedge.listen((event) {
        storage.reset();
      });
    }

    // on posedge of clock, sample write ports and save to memory
    clk.posedge.listen((event) {
      for (final pending in List<_PendingMemoryRead>.of(_pendingReads)) {
        if (pending.remaining > 0) {
          pending.remaining--;
          if (pending.remaining == 0) {
            _scheduleRead(pending);
          }
        }
      }
      if (reset.previousValue == LogicValue.one) {
        storage.reset();
        return;
      }
      for (final wrPort in wrPorts) {
        final enable = wrPort.en.previousValue!;
        if (enable == LogicValue.zero) {
          continue;
        }

        final address = wrPort.addr.previousValue!;
        final data = wrPort.data.previousValue!;
        final mask = wrPort is MaskedDataPortInterface<T>
            ? wrPort.mask.previousValue!
            : null;
        if (mask != null && mask.isZero) {
          continue;
        }
        if (!address.isValid) {
          final affectedBits = mask == null
              ? LogicValue.filled(dataWidth, LogicValue.one)
              : [
                  for (var index = 0; index < dataWidth ~/ 8; index++)
                    LogicValue.filled(
                        8,
                        mask[index] == LogicValue.zero
                            ? LogicValue.zero
                            : LogicValue.one)
                ].rconcat();
          storage.writeUncertainAddress(address, affectedBits);
          continue;
        }

        if (!enable.isValid || (mask != null && !mask.isValid)) {
          storage.onInvalidWrite();
        }
        if (mask == null) {
          storage.writeData(
              address,
              enable.isValid
                  ? data
                  : LogicValue.filled(dataWidth, LogicValue.x));
        } else {
          final needsOld = List.generate(mask.width, (index) => mask[index])
              .contains(LogicValue.zero);
          final old = needsOld
              ? storage.readData(address)
              : LogicValue.filled(dataWidth, LogicValue.x);
          storage.writeData(
            address,
            [
              for (var index = 0; index < dataWidth ~/ 8; index++)
                if (mask[index] == LogicValue.zero)
                  old.getRange(index * 8, (index + 1) * 8)
                else if (!enable.isValid || !mask[index].isValid)
                  LogicValue.filled(8, LogicValue.x)
                else
                  data.getRange(index * 8, (index + 1) * 8)
            ].rconcat(),
          );
        }
      }

      for (final (index, rdPort) in rdPorts.indexed) {
        if (readLatency > 0) {
          // if we have at least 1 cycle, then we wait to update the data
          if (!rdPort.en.previousValue!.isValid ||
              !rdPort.en.previousValue!.toBool() ||
              !rdPort.addr.previousValue!.isValid) {
            _updateRead(
                index, LogicValue.filled(rdPort.dataWidth, LogicValue.x));
          } else {
            _updateRead(index, storage.readData(rdPort.addr.previousValue!));
          }
        } else {
          // if we have instant read latency, we may need to update the read
          // data in zero-latency after updating a write
          _updateReadZeroLatency(rdPort);
        }
      }
    });

    // if latency is 0, we need to update immediately
    if (readLatency == 0) {
      for (final rdPort in rdPorts) {
        rdPort.en.glitch.listen((args) => _updateReadZeroLatency(rdPort));
        rdPort.addr.glitch.listen((args) => _updateReadZeroLatency(rdPort));
      }
    }
  }

  /// Updates read data for [rdPort] immediately (as if combinationally).
  void _updateReadZeroLatency(DataPortInterface<T> rdPort) {
    if (!rdPort.en.value.isValid ||
        !rdPort.en.value.toBool() ||
        !rdPort.addr.value.isValid) {
      _putReadData(rdPort, LogicValue.filled(rdPort.dataWidth, LogicValue.x));
    } else {
      _putReadData(rdPort, storage.readData(rdPort.addr.value));
    }
  }

  /// Drives stored bits without invoking a structure's semantic value API.
  void _putReadData(DataPortInterface<T> rdPort, LogicValue value) =>
      putPackedLogicValue(rdPort.data, value);

  void _updateRead(int port, LogicValue data) {
    final pending = _PendingMemoryRead(port, data, readLatency - 1);
    _pendingReads.add(pending);
    if (pending.remaining == 0) {
      _scheduleRead(pending);
    }
  }

  void _scheduleRead(_PendingMemoryRead pending) {
    if (pending.scheduled) {
      return;
    }
    pending.scheduled = true;
    final generation = _readGeneration;
    Simulator.injectAction(() {
      if (generation == _readGeneration && _pendingReads.remove(pending)) {
        _putReadData(rdPorts[pending.port], pending.value);
      }
    });
  }

  LogicValue _rawValue(Logic data) => data is LogicStructure
      ? data.leafElements.map((leaf) => leaf.value).toList().rconcat()
      : data.value;

  String _writePortShape(DataPortInterface<T> port) {
    final maskWidth = port is MaskedDataPortInterface<T> ? port.mask.width : 0;
    return 'w:${payloadShapeIdentity(port.data)}:$maskWidth';
  }

  List<String> get _portShapes => [
        for (final port in rdPorts) 'r:${payloadShapeIdentity(port.data)}',
        for (final port in wrPorts) _writePortShape(port),
      ];

  /// Captures storage, read outputs and all outstanding delayed reads.
  MemoryModelImage snapshot() => MemoryModelImage._(
        storage: MemoryStorageState(storage).snapshot(),
        addressWidth: addrWidth,
        dataWidth: dataWidth,
        readLatency: readLatency,
        writePortCount: wrPorts.length,
        asyncReset: asyncReset,
        registerFile: registerFile,
        portShapes: _portShapes,
        readOutputs: [for (final port in rdPorts) _rawValue(port.data)],
        pending: _pendingReads,
      );

  /// Restores a compatible image; external clock and port inputs are not saved.
  void restore(MemoryModelImage image) {
    if (image._addressWidth != addrWidth ||
        image._dataWidth != dataWidth ||
        image._readLatency != readLatency ||
        image._writePortCount != wrPorts.length ||
        image._asyncReset != asyncReset ||
        !_sameRegisterFile(image._registerFile) ||
        image._readOutputs.length != rdPorts.length ||
        !_samePortShapes(image._portShapes)) {
      throw ArgumentError('Memory model image configuration does not match.');
    }
    MemoryStorageState(storage).load(image.storage, replace: true);
    _readGeneration++;
    _pendingReads
      ..clear()
      ..addAll(image._pending.map((read) => read.copy()));
    for (final (index, value) in image._readOutputs.indexed) {
      _putReadData(rdPorts[index], value);
    }
    for (final pending in _pendingReads) {
      if (pending.remaining == 0) {
        _scheduleRead(pending);
      }
    }
  }

  bool _sameRegisterFile(RegisterFileModelConfiguration? other) {
    final current = registerFile;
    if (current == null || other == null) {
      return current == other;
    }
    if (current.numEntries != other.numEntries) {
      return false;
    }
    for (var i = 0; i < current.numEntries; i++) {
      if (current.resetValues[i] != other.resetValues[i]) {
        return false;
      }
    }
    return true;
  }

  bool _samePortShapes(List<String> shapes) {
    final actual = _portShapes;
    if (shapes.length != actual.length) {
      return false;
    }
    for (var index = 0; index < shapes.length; index++) {
      if (shapes[index] != actual[index]) {
        return false;
      }
    }
    return true;
  }
}
