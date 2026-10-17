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

/// Software-held state for an entire CSR top.
///
/// Addresses are the frontdoor's logical addresses (no implicit byte scaling).
/// Inspection and loading bypass architectural write effects. Hardware
/// frontdoor and backdoor writes retain their architectural semantics.
class CsrSoftwareModel
    implements BehavioralModel, MemoryStateAccess<Map<int, LogicValue>> {
  /// Frozen metadata shared with the portable SystemC generator.
  @override
  final CsrModelDescription description;

  /// Address increment between chunks of a register wider than a frontdoor.
  int get logicalRegisterIncrement => description.logicalRegisterIncrement;

  final Map<int, _CsrModelRegister> _registers = {};
  final Map<String, int> _names = {};
  final Map<int, (_CsrModelRegister, int)> _reads = {};
  final Map<int, (_CsrModelRegister, int)> _writes = {};
  final Map<int, CsrBackdoorInterface> _hardware = {};
  final Map<Logic, LogicValue> _sampled = {};
  final Set<Logic> _deferred = {};
  final Set<Logic> _racing = {};
  final Set<int> _activeHardwareWrites = {};
  final Set<int> _deferredHardware = {};
  final Map<Logic, int> _hardwareEnables = {};
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

  /// Constructs the software state and attaches one shared clock handler.
  ///
  /// [hardware] contains only selected, already connected hardware interfaces.
  CsrSoftwareModel({
    required this.description,
    required Logic clk,
    required Logic reset,
    required DataPortInterface? frontRead,
    required DataPortInterface? frontWrite,
    required Map<int, CsrBackdoorInterface> hardware,
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
    for (final entry in description.registers.entries) {
      _registers[entry.key] = _CsrModelRegister(entry.value);
    }
    _names.addAll(description.names);
    _reads.addAll(description.reads.map((address, target) =>
        MapEntry(address, (_registers[target.$1.address]!, target.$2))));
    _writes.addAll(description.writes.map((address, target) =>
        MapEntry(address, (_registers[target.$1.address]!, target.$2))));
    _hardware.addAll(hardware);
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
    if (frontWrite != null) {
      for (final signal in [frontWrite.en, frontWrite.addr, frontWrite.data]) {
        _cancelGlitches
            .add(signal.glitch.listen((_) => _driveHardware()).cancel);
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

  void _setHardwareActive(int address, Logic enable) {
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
  int addressOf(String block, String register) =>
      _names['$block/$register'] ??
      (throw ArgumentError('Unknown CSR $block/$register.'));

  _CsrModelRegister _at(int address) =>
      _registers[address] ??
      (throw ArgumentError.value(address, 'address', 'Unknown CSR.'));

  /// Inspects raw state without allocating any hardware signals.
  @override
  LogicValue peek(int address) => _at(address).value;

  /// Replaces raw state, bypassing frontdoor permissions and field effects.
  @override
  void poke(int address, LogicValue value) {
    final register = _at(address);
    if (value.width != register.config.width) {
      throw ArgumentError('CSR value width does not match its register.');
    }
    register.value = value;
    _driveRead();
    _driveHardware();
  }

  /// Captures all register state, keyed by absolute logical register address.
  @override
  Map<int, LogicValue> snapshot() => Map.unmodifiable(
      _registers.map((address, entry) => MapEntry(address, entry.value)));

  /// Loads validated raw state atomically.
  ///
  /// With [replace], unspecified registers take their architectural reset
  /// values. Otherwise they retain their state. Loading does not pulse command
  /// fields or perform W1C operations.
  @override
  void load(Map<int, LogicValue> values, {bool replace = false}) {
    for (final entry in values.entries) {
      if (_at(entry.key).config.width != entry.value.width) {
        throw ArgumentError('CSR value width does not match its register.');
      }
    }
    if (replace) {
      _resetState();
    }
    for (final entry in values.entries) {
      _registers[entry.key]!.value = entry.value;
    }
    _driveRead();
    _driveHardware();
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
    if (invalid) {
      _resetState(unknown: true);
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
      } else if (reset == LogicValue.one) {
        _resetState();
      } else {
        _write();
      }
    }
    _driveRead();
    _driveHardware();
  }

  void _write() {
    final front = _frontWrite;
    final touched = <_CsrModelRegister>{};
    if (front != null) {
      final enable = _sampled[front.en]!;
      final address = _sampled[front.addr]!;
      if (enable != LogicValue.zero) {
        if (address.isValid) {
          final target = _writes[address.toInt()];
          if (target != null) {
            final (entry, offset) = target;
            touched.add(entry);
            entry.value = enable.isValid
                ? entry.write(_sampled[front.data]!, offset: offset)
                : LogicValue.filled(entry.config.width, LogicValue.x);
          }
        } else {
          for (final entry
              in _writes.values.map((target) => target.$1).toSet()) {
            touched.add(entry);
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
          entry.value = enable.isValid
              ? entry.write(_sampled[hardware.wrData]!, backdoor: true)
              : LogicValue.filled(entry.config.width, LogicValue.x);
        }
      }
    }
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
    final target = _reads[address.toInt()];
    final value = target == null
        ? LogicValue.ofInt(0, front.dataWidth)
        : target.$1.value
            .getRange(target.$2,
                min(target.$2 + front.dataWidth, target.$1.config.width))
            .zeroExtend(front.dataWidth);
    front.data.put(value & value);
  }

  void _driveHardware() {
    final front = _frontWrite;
    final target = front != null && front.addr.value.isValid
        ? _writes[front.addr.value.toInt()]
        : null;
    for (final exposed in _hardware.entries) {
      if (!exposed.value.hasRead) {
        continue;
      }
      final entry = _registers[exposed.key]!;
      var value = entry.value;
      if (front != null && entry.config.isFrontdoorWritable) {
        final register = entry.description;
        final address = front.addr.value;
        final inBlock = address.isValid
            ? LogicValue.ofBool(address.toInt() >= register.blockBase &&
                address.toInt() < register.blockBase + register.blockSize)
            : LogicValue.x;
        final enable = front.en.value & inBlock;
        final offset = target?.$2 ?? 0;
        final count = min(front.dataWidth, entry.config.width - offset);
        for (final field in entry.config.fields) {
          if (field.access != CsrFieldAccess.writeOnly) {
            continue;
          }
          final unknown = !enable.isValid &&
                  (entry.config.width > front.dataWidth ||
                      !front.addr.value.isValid ||
                      target?.$1 == entry) ||
              enable == LogicValue.one &&
                  !front.addr.value.isValid &&
                  entry.config.width <= front.dataWidth;
          if (unknown) {
            value = value.withSet(
                field.start, LogicValue.filled(field.width, LogicValue.x));
          } else if (target?.$1 == entry &&
              enable == LogicValue.one &&
              field.start < offset + count &&
              field.start + field.width > offset) {
            final start = max(field.start, offset);
            final end = min(field.start + field.width, offset + count);
            final update =
                front.data.value.getRange(start - offset, end - offset);
            final command = LogicValue.ofInt(0, field.width)
                .withSet(start - field.start, update);
            value = value.withSet(field.start, command);
          }
        }
      }
      for (final field in entry.config.fields
          .where((field) => field.access == CsrFieldAccess.writeOnly)) {
        // ROHD's mux propagates an invalid selected operand to the whole field.
        if (!value.getRange(field.start, field.start + field.width).isValid) {
          value = value.withSet(
              field.start, LogicValue.filled(field.width, LogicValue.x));
        }
      }
      exposed.value.rdData!.put(value);
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
  CsrInstanceConfig get config => description.config;
  LogicValue value;
  Map<CsrFieldConfig, LogicValue> get illegalValues =>
      description.illegalValues;

  _CsrModelRegister(this.description)
      : value = LogicValue.filled(description.config.width, LogicValue.x);

  LogicValue write(LogicValue data, {int offset = 0, bool backdoor = false}) {
    final count = min(data.width, config.width - offset);
    final proposed = value.withSet(offset, data.getRange(0, count));
    if (config.access == CsrAccess.readOnly) {
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
          updated =
              incoming.isValid && field.legalValues.contains(incoming.toInt())
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
