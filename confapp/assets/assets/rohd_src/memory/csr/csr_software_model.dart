// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_software_model.dart
// Software-held state for CSR models.
//
// 2026 October 16
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';

/// Detached CSR execution state, including sampled inputs and pending edges.
///
/// The image is tied to the originating model and does not capture external
/// signals or events. A caller must coordinate those separately.
class CsrSoftwareExecutionImage {
  final CsrSoftwareModel _owner;
  final Map<BigInt, LogicValue> _registers;
  final Map<Logic, LogicValue> _sampled;
  final Set<Logic> _deferred;
  final Set<Logic> _racing;
  final Set<BigInt> _activeHardwareWrites;
  final Set<BigInt> _deferredHardware;
  final bool _clockChanged;
  final bool _resetChanged;
  final LogicValue? _oldClock;
  final LogicValue? _oldReset;

  CsrSoftwareExecutionImage._(CsrSoftwareModel owner)
      : _owner = owner,
        _registers = owner.snapshot(),
        _sampled = Map.unmodifiable(owner._sampled),
        _deferred = Set.unmodifiable(owner._deferred),
        _racing = Set.unmodifiable(owner._racing),
        _activeHardwareWrites = Set.unmodifiable(owner._activeHardwareWrites),
        _deferredHardware = Set.unmodifiable(owner._deferredHardware),
        _clockChanged = owner._clockChanged,
        _resetChanged = owner._resetChanged,
        _oldClock = owner._oldClock,
        _oldReset = owner._oldReset;
}

/// Software-held state for an entire CSR top.
///
/// Addresses are the frontdoor's logical addresses (no implicit byte scaling).
/// Inspection and loading bypass architectural write effects. Hardware
/// frontdoor and backdoor writes retain their architectural semantics.
class CsrSoftwareModel
    implements
        BehavioralModel,
        MemoryStateAccess<Map<BigInt, LogicValue>>,
        StateTransactionProvider<CsrSoftwareExecutionImage>,
        StateTransactionCapabilityProvider {
  /// Frozen metadata shared with the portable SystemC generator.
  @override
  final CsrModelDescription description;

  /// Address increment between chunks of a register wider than a frontdoor.
  BigInt get logicalRegisterIncrement => description.logicalRegisterIncrement;

  final Map<BigInt, _CsrModelRegister> _registers = {};
  final Map<String, BigInt> _names = {};
  final Map<BigInt, (_CsrModelRegister, int)> _reads = {};
  final Map<BigInt, (_CsrModelRegister, int)> _writes = {};
  final Map<BigInt, CsrBackdoorInterface> _hardware = {};
  final Map<BigInt, ({Csr output, List<CsrFieldConfig> commands})>
      _hardwareReads = {};
  final Set<BigInt> _commandHardware = {};
  final Map<Logic, LogicValue> _sampled = {};
  final Set<Logic> _deferred = {};
  final Set<Logic> _racing = {};
  final Set<BigInt> _activeHardwareWrites = {};
  final Set<BigInt> _deferredHardware = {};
  final Map<Logic, BigInt> _hardwareEnables = {};
  final List<StreamSubscription<void>> _subscriptions = [];
  final List<void Function()> _cancelGlitches = [];
  final Logic _clk;
  final Logic _reset;
  final DataPortInterface? _frontRead;
  final DataPortInterface? _frontWrite;
  bool _clockChanged = false;
  bool _resetChanged = false;
  LogicValue? _oldClock;
  LogicValue? _oldReset;

  @override
  StateTransactionCapabilities get stateTransactionCapabilities =>
      StateTransactionCapabilities.software;

  @override
  late final StateTransactionEndpoint<CsrSoftwareExecutionImage>
      stateTransactions = SoftwareStateTransactionAdapter(
          snapshot: snapshotExecution, restore: restoreExecution);

  /// Constructs the software state and attaches one shared clock handler.
  ///
  /// [hardware] contains only selected, already connected hardware interfaces.
  CsrSoftwareModel({
    required this.description,
    required Logic clk,
    required Logic reset,
    required DataPortInterface? frontRead,
    required DataPortInterface? frontWrite,
    required Map<BigInt, CsrBackdoorInterface> hardware,
  })  : _clk = clk,
        _reset = reset,
        _frontRead = frontRead,
        _frontWrite = frontWrite {
    if (clk.width != 1 ||
        reset.width != 1 ||
        frontRead?.addrWidth != description.frontRead?.addressWidth ||
        frontRead?.dataWidth != description.frontRead?.dataWidth ||
        frontWrite?.addrWidth != description.frontWrite?.addressWidth ||
        frontWrite?.dataWidth != description.frontWrite?.dataWidth ||
        hardware.length != description.hardware.length ||
        hardware.keys
            .any((address) => !description.hardware.containsKey(address))) {
      throw ArgumentError('Runtime ports do not match the model description.');
    }
    for (final entry in hardware.entries) {
      final ports = description.hardware[entry.key]!;
      if (entry.value.hasRead != ports.hasRead ||
          entry.value.hasWrite != ports.hasWrite ||
          entry.value.config.width !=
              description.registers[entry.key]!.config.width) {
        throw ArgumentError(
            'Hardware view does not match the model description.');
      }
    }
    final largestAddress =
        description.registers.keys.reduce((a, b) => a > b ? a : b);
    final stores = <int, SparseMemoryStorage>{};
    for (final entry in description.registers.entries) {
      final width = entry.value.config.width;
      final storage = stores.putIfAbsent(
          width,
          () => SparseMemoryStorage(
              addrWidth: max(1, largestAddress.bitLength), dataWidth: width));
      _registers[entry.key] = _CsrModelRegister(entry.value, storage);
    }
    _names.addAll(description.names);
    _reads.addAll(description.reads.map((address, target) =>
        MapEntry(address, (_registers[target.$1.address]!, target.$2))));
    _writes.addAll(description.writes.map((address, target) =>
        MapEntry(address, (_registers[target.$1.address]!, target.$2))));
    _hardware.addAll(hardware);
    for (final entry in hardware.entries) {
      if (!entry.value.hasRead) {
        continue;
      }
      final register = _registers[entry.key]!;
      final commands = register.config.fields
          .where((field) => field.access == CsrFieldAccess.writeOnly)
          .toList(growable: false);
      _hardwareReads[entry.key] =
          (output: entry.value.rdData!, commands: commands);
      if (register.config.isFrontdoorWritable && commands.isNotEmpty) {
        _commandHardware.add(entry.key);
      }
    }
    for (final signal in [
      _reset,
      if (frontWrite != null) ...[
        frontWrite.en,
        frontWrite.addr,
        frontWrite.data,
      ],
      for (final interface in hardware.values)
        if (interface.hasWrite) ...[interface.wrEn!, interface.wrData!],
    ]) {
      _sampled[signal] = signal.value;
      _cancelGlitches.add(signal.glitch.listen((_) {
        if (Simulator.phase == SimulatorPhase.clkStable) {
          _deferred.add(signal);
        } else {
          _sampled[signal] = signal.value;
          if (Simulator.phase != SimulatorPhase.outOfTick) {
            _racing.add(signal);
          }
        }
      }).cancel);
    }
    _cancelGlitches.add(_clk.glitch.listen((event) {
      _oldClock ??= event.previousValue;
      _clockChanged = true;
    }).cancel);
    if (description.asyncReset) {
      _cancelGlitches.add(_reset.glitch.listen((event) {
        _oldReset ??= event.previousValue;
        _resetChanged = true;
      }).cancel);
    }
    _subscriptions.add(Simulator.clkStable.listen((_) => _tick()));
    _subscriptions.add(Simulator.postTick.listen((_) {
      for (final signal in _deferred) {
        _sampled[signal] = signal.value;
      }
      _deferred.clear();
      _racing.clear();
      for (final address in _deferredHardware) {
        _setHardwareActive(address, _hardware[address]!.wrEn!);
      }
      _deferredHardware.clear();
    }));
    if (frontRead != null) {
      _cancelGlitches
          .add(frontRead.addr.glitch.listen((_) => _driveRead()).cancel);
    }
    if (frontWrite != null && _commandHardware.isNotEmpty) {
      for (final signal in [frontWrite.en, frontWrite.addr, frontWrite.data]) {
        _cancelGlitches.add(signal.glitch
            .listen((_) => _driveHardware(_commandHardware))
            .cancel);
      }
    }
    for (final entry in hardware.entries) {
      final enable = entry.value.wrEn;
      if (enable != null) {
        _hardwareEnables[enable] = entry.key;
        void update() {
          if (Simulator.phase == SimulatorPhase.clkStable) {
            _deferredHardware.add(entry.key);
          } else {
            _setHardwareActive(entry.key, enable);
          }
        }

        update();
        _cancelGlitches.add(enable.glitch.listen((_) => update()).cancel);
      }
    }
    Simulator.registerEndOfSimulationAction(dispose);
    _driveRead();
    _driveHardware();
  }

  void _setHardwareActive(BigInt address, Logic enable) {
    if (enable.value == LogicValue.zero) {
      _activeHardwareWrites.remove(address);
    } else {
      _activeHardwareWrites.add(address);
    }
  }

  @override
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) =>
      description.generateSystemC(className: className, options: options);

  /// Number of registers held without signal-backed state.
  int get registerCount => _registers.length;

  /// Number of hardware-connected registers.
  int get hardwareRegisterCount => _hardware.length;

  /// Resolves a configured block/register name to its absolute logical address.
  BigInt addressOf(String block, String register) =>
      _names['$block/$register'] ??
      (throw ArgumentError('Unknown CSR $block/$register.'));

  _CsrModelRegister _at(BigInt address) =>
      _registers[address] ??
      (throw ArgumentError.value(address, 'address', 'Unknown CSR.'));

  /// Inspects raw state without allocating any hardware signals.
  @override
  LogicValue peek(int address) => peekBigInt(BigInt.from(address));

  @override
  LogicValue peekBigInt(BigInt address) => _at(address).value;

  /// Replaces raw state, bypassing frontdoor permissions and field effects.
  @override
  void poke(int address, LogicValue value) =>
      pokeBigInt(BigInt.from(address), value);

  @override
  void pokeBigInt(BigInt address, LogicValue value) {
    final register = _at(address);
    if (value.width != register.config.width) {
      throw ArgumentError('CSR value width does not match its register.');
    }
    register.value = normalizeStoredValue(value);
    _driveRead();
    _driveHardware([address]);
  }

  /// Captures all register state, keyed by absolute logical register address.
  @override
  Map<BigInt, LogicValue> snapshot() => Map.unmodifiable(
      _registers.map((address, entry) => MapEntry(address, entry.value)));

  /// Captures register state, sampled inputs, and pending simulator events.
  ///
  /// Calls must occur between simulator ticks. External signals are not part
  /// of this image and must be coordinated by the caller.
  CsrSoftwareExecutionImage snapshotExecution() {
    if (Simulator.phase != SimulatorPhase.outOfTick) {
      throw StateError('CSR execution snapshots require a tick boundary.');
    }
    return CsrSoftwareExecutionImage._(this);
  }

  /// Restores an execution image created by this model at a tick boundary.
  void restoreExecution(CsrSoftwareExecutionImage image) {
    if (Simulator.phase != SimulatorPhase.outOfTick) {
      throw StateError('CSR execution restore requires a tick boundary.');
    }
    if (!identical(image._owner, this)) {
      throw ArgumentError('CSR execution image belongs to another model.');
    }
    for (final entry in image._registers.entries) {
      if (_at(entry.key).config.width != entry.value.width) {
        throw ArgumentError('CSR execution image has invalid register widths.');
      }
    }
    for (final entry in image._registers.entries) {
      _registers[entry.key]!.value = entry.value;
    }
    _sampled
      ..clear()
      ..addAll(image._sampled);
    _deferred
      ..clear()
      ..addAll(image._deferred);
    _racing
      ..clear()
      ..addAll(image._racing);
    _activeHardwareWrites
      ..clear()
      ..addAll(image._activeHardwareWrites);
    _deferredHardware
      ..clear()
      ..addAll(image._deferredHardware);
    _clockChanged = image._clockChanged;
    _resetChanged = image._resetChanged;
    _oldClock = image._oldClock;
    _oldReset = image._oldReset;
    _driveRead();
    _driveHardware();
  }

  /// Loads validated raw state atomically.
  ///
  /// With [replace], unspecified registers take their architectural reset
  /// values. Otherwise they retain their state. Loading does not pulse command
  /// fields or perform W1C operations.
  @override
  void load(Map<BigInt, LogicValue> values, {bool replace = false}) {
    for (final entry in values.entries) {
      if (_at(entry.key).config.width != entry.value.width) {
        throw ArgumentError('CSR value width does not match its register.');
      }
    }
    if (replace) {
      _resetState();
    }
    for (final entry in values.entries) {
      _registers[entry.key]!.value = normalizeStoredValue(entry.value);
    }
    _driveRead();
    _driveHardware(replace ? null : values.keys);
  }

  void _resetState({bool unknown = false}) {
    for (final entry in _registers.values) {
      entry.value = unknown
          ? LogicValue.filled(entry.config.width, LogicValue.x)
          : LogicValue.ofInt(entry.config.resetValue, entry.config.width);
    }
  }

  void _tick() {
    if (!_clockChanged && !_resetChanged) {
      return;
    }
    final invalid = (_clockChanged &&
            (!(_oldClock?.isValid ?? false) || !_clk.value.isValid)) ||
        (_resetChanged &&
            (!(_oldReset?.isValid ?? false) || !_reset.value.isValid));
    final edge = (_clockChanged &&
            _oldClock == LogicValue.zero &&
            _clk.value == LogicValue.one) ||
        (_resetChanged &&
            _oldReset == LogicValue.zero &&
            _reset.value == LogicValue.one);
    _clockChanged = _resetChanged = false;
    _oldClock = _oldReset = null;
    Iterable<BigInt>? dirty = const [];
    if (invalid) {
      _resetState(unknown: true);
      dirty = null;
    } else if (edge) {
      for (final signal in _racing) {
        if (signal != _reset || !description.asyncReset) {
          _sampled[signal] = LogicValue.filled(signal.width, LogicValue.x);
          _deferred.add(signal);
          final address = _hardwareEnables[signal];
          if (address != null) {
            _activeHardwareWrites.add(address);
            _deferredHardware.add(address);
          }
        }
      }
      final reset = description.asyncReset ? _reset.value : _sampled[_reset]!;
      if (!reset.isValid) {
        _resetState(unknown: true);
        dirty = null;
      } else if (reset == LogicValue.one) {
        _resetState();
        dirty = null;
      } else {
        dirty = _write();
      }
    }
    _driveRead();
    _driveHardware(dirty);
  }

  Set<BigInt> _write() {
    final front = _frontWrite;
    final touched = <_CsrModelRegister>{};
    final dirty = <BigInt>{};
    if (front != null) {
      final enable = _sampled[front.en]!;
      final address = _sampled[front.addr]!;
      if (enable != LogicValue.zero) {
        if (address.isValid) {
          final target = _writes[address.toBigInt()];
          if (target != null) {
            final (entry, offset) = target;
            touched.add(entry);
            dirty.add(entry.description.address);
            entry.value = enable.isValid
                ? entry.write(_sampled[front.data]!, offset: offset)
                : LogicValue.filled(entry.config.width, LogicValue.x);
          }
        } else {
          for (final entry
              in _writes.values.map((target) => target.$1).toSet()) {
            touched.add(entry);
            dirty.add(entry.description.address);
            entry.value = LogicValue.filled(entry.config.width, LogicValue.x);
          }
        }
      }
    }
    for (final address in _activeHardwareWrites) {
      final entry = _registers[address]!;
      final hardware = _hardware[address]!;
      if (!touched.contains(entry)) {
        final enable = _sampled[hardware.wrEn]!;
        if (enable != LogicValue.zero) {
          dirty.add(address);
          entry.value = enable.isValid
              ? entry.write(_sampled[hardware.wrData]!, backdoor: true)
              : LogicValue.filled(entry.config.width, LogicValue.x);
        }
      }
    }
    return dirty;
  }

  void _driveRead() {
    final front = _frontRead;
    if (front == null) {
      return;
    }
    final address = front.addr.value;
    if (!address.isValid) {
      front.data.put(LogicValue.filled(front.dataWidth, LogicValue.x));
      return;
    }
    final target = _reads[address.toBigInt()];
    final value = target == null
        ? LogicValue.ofInt(0, front.dataWidth)
        : target.$1.value
            .getRange(target.$2,
                min(target.$2 + front.dataWidth, target.$1.config.width))
            .zeroExtend(front.dataWidth);
    front.data.put(value & value);
  }

  void _driveHardware([Iterable<BigInt>? addresses]) {
    final front = _frontWrite;
    final target = front != null && front.addr.value.isValid
        ? _writes[front.addr.value.toBigInt()]
        : null;
    for (final address in addresses ?? _hardwareReads.keys) {
      final exposed = _hardwareReads[address];
      if (exposed == null) {
        continue;
      }
      final entry = _registers[address]!;
      var value = entry.value;
      if (front != null &&
          exposed.commands.isNotEmpty &&
          entry.config.isFrontdoorWritable) {
        final register = entry.description;
        final address = front.addr.value;
        final inBlock = address.isValid
            ? LogicValue.ofBool(address.toBigInt() >= register.blockBase &&
                address.toBigInt() < register.blockBase + register.blockSize)
            : LogicValue.x;
        final enable = front.en.value & inBlock;
        final offset = target?.$2 ?? 0;
        final count = min(front.dataWidth, entry.config.width - offset);
        for (final field in exposed.commands) {
          final stored = value.getRange(field.start, field.start + field.width);
          final overlaps = target?.$1 == entry &&
              field.start < offset + count &&
              field.start + field.width > offset;
          final selected =
              address.isValid ? LogicValue.ofBool(overlaps) : LogicValue.x;
          final select = enable & selected;
          var command = LogicValue.ofInt(0, field.width);
          if (!address.isValid && entry.config.width > front.dataWidth) {
            command = LogicValue.filled(field.width, LogicValue.x);
          } else if (overlaps ||
              (!address.isValid && entry.config.width <= front.dataWidth)) {
            final start = max(field.start, offset);
            final end = min(field.start + field.width, offset + count);
            final data = front.data.value & front.data.value;
            command = command.withSet(start - field.start,
                data.getRange(start - offset, end - offset));
          }
          final result = select == LogicValue.zero
              ? stored
              : select == LogicValue.one
                  ? command
                  : LogicValue.ofIterable([
                      for (var bit = 0; bit < field.width; bit++)
                        if (stored[bit] == command[bit])
                          stored[bit]
                        else
                          LogicValue.x,
                    ]);
          value = value.withSet(field.start, result);
        }
      }
      if (exposed.output.value != value) {
        exposed.output.put(value);
      }
    }
  }

  /// Detaches simulation callbacks. Also called at simulation end.
  Future<void> dispose() async {
    for (final cancel in _cancelGlitches) {
      cancel();
    }
    _cancelGlitches.clear();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}

class _CsrModelRegister {
  final CsrModelRegisterDescription description;
  final SparseMemoryStorage _storage;
  CsrInstanceConfig get config => description.config;
  Map<CsrFieldConfig, LogicValue> get illegalValues =>
      description.illegalValues;

  _CsrModelRegister(this.description, this._storage);

  LogicValue get _address =>
      LogicValue.ofBigInt(description.address, _storage.addrWidth);

  LogicValue get value =>
      _storage.getData(_address) ??
      LogicValue.filled(config.width, LogicValue.x);

  set value(LogicValue value) {
    if (value.width != config.width) {
      throw ArgumentError('CSR value width does not match its register.');
    }
    _storage.setData(_address, value);
  }

  LogicValue write(LogicValue data, {int offset = 0, bool backdoor = false}) {
    final count = min(data.width, config.width - offset);
    final proposed = value.withSet(offset, data.getRange(0, count));
    if (!backdoor && config.access == CsrAccess.readOnly) {
      return value & value;
    }
    var result = config.fields.isEmpty ? proposed : value;
    for (final field in config.fields) {
      final original = value.getRange(field.start, field.start + field.width);
      final incoming =
          proposed.getRange(field.start, field.start + field.width);
      final LogicValue updated;
      switch (field.access) {
        case CsrFieldAccess.readOnly:
        case CsrFieldAccess.writeOnly:
          updated = original;
        case CsrFieldAccess.readWrite:
          updated = incoming;
        case CsrFieldAccess.writeOnesClear:
          updated = backdoor ? original | incoming : original & ~incoming;
        case CsrFieldAccess.readWriteLegal:
          updated = incoming.isValid &&
                  field.legalValues
                      .any((legal) => incoming.toBigInt() == BigInt.from(legal))
              ? incoming
              : illegalValues[field]!;
      }
      result = result.withSet(field.start, updated);
    }
    final updated =
        value.withSet(offset, result.getRange(offset, offset + count));
    return updated & updated;
  }
}
