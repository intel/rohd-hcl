// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_model_description.dart
// Immutable configuration for CSR software models.
//
// 2026 October 16
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Frozen configuration of one register, with no runtime signals or callbacks.
final class CsrModelRegisterDescription {
  /// Absolute logical register address.
  final int address;

  /// Start and extent of the owning block's address range.
  final int blockBase;

  /// Number of logical addresses in the owning block.
  final int blockSize;

  /// Deep-copied base configuration, including immutable field lists.
  final CsrInstanceConfig config;

  /// Evaluated legal-value fallbacks keyed by the copied fields.
  final Map<CsrFieldConfig, LogicValue> illegalValues;

  CsrModelRegisterDescription._frozen(
      this.address,
      this.blockBase,
      this.blockSize,
      this.config,
      Map<CsrFieldConfig, LogicValue> illegalValues)
      : illegalValues = Map.unmodifiable(illegalValues);

  factory CsrModelRegisterDescription._(
      int address, int blockBase, int blockSize, CsrInstanceConfig original) {
    final fields = [
      for (final field in original.fields)
        CsrFieldConfig(
          name: field.name,
          start: field.start,
          width: field.width,
          access: field.access,
          resetValue: field.resetValue,
          legalValues: field.legalValues,
        ),
    ];
    final config = CsrInstanceConfig(
      arch: CsrConfig(
        name: original.name,
        access: original.access,
        fields: fields,
      ),
      addr: original.addr,
      width: original.width,
      resetValue: original.resetValue,
      isFrontdoorReadable: original.isFrontdoorReadable,
      isFrontdoorWritable: original.isFrontdoorWritable,
      isBackdoorReadable: original.isBackdoorReadable,
      isBackdoorWritable: original.isBackdoorWritable,
    );
    return CsrModelRegisterDescription._frozen(
        address, blockBase, blockSize, config, {
      for (var index = 0; index < fields.length; index++)
        if (fields[index].access == CsrFieldAccess.readWriteLegal)
          fields[index]: LogicValue.ofInt(
              original.fields[index].transformIllegalValue(),
              fields[index].width),
    });
  }
}

/// Frozen hardware port names for one explicitly exposed register.
final class CsrModelHardwarePorts {
  /// Live hardware-read output, when exposed.
  final String? read;

  /// Hardware write-enable input, when exposed.
  final String? writeEnable;

  /// Hardware write-data input, when exposed.
  final String? writeData;

  CsrModelHardwarePorts._({this.read, this.writeEnable, this.writeData});

  /// Whether this register exposes hardware reads.
  bool get hasRead => read != null;

  /// Whether this register exposes hardware writes.
  bool get hasWrite => writeEnable != null;
}

/// Portable whole-top CSR metadata shared by ROHD and SystemC execution.
///
/// Construction uses architectural configuration only. It allocates no Logic,
/// Module, simulator callback, or mutable register state.
final class CsrModelDescription implements BehavioralModelDescription {
  @override
  String get kind => 'csr';

  @override
  final Map<String, int> inputPorts;

  @override
  final Map<String, int> outputPorts;

  /// Reset mode, frozen at description construction.
  final bool asyncReset;

  /// Address step between chunks of a wide register.
  final int logicalRegisterIncrement;

  /// Frontdoor geometry, or null for an omitted frontdoor.
  final MemoryPortGeometry? frontRead;

  /// Write-frontdoor geometry, independent of the read geometry.
  final MemoryPortGeometry? frontWrite;

  /// Register descriptions keyed by absolute logical address.
  final Map<int, CsrModelRegisterDescription> registers;

  /// Name lookup without allocating register signals.
  final Map<String, int> names;

  /// Indexed frontdoor chunks: register and bit offset.
  final Map<int, (CsrModelRegisterDescription, int)> reads;

  /// Indexed write chunks, honoring architectural accessibility.
  final Map<int, (CsrModelRegisterDescription, int)> writes;

  /// Only requested and architecturally accessible hardware ports.
  final Map<int, CsrModelHardwarePorts> hardware;

  CsrModelDescription._({
    required this.asyncReset,
    required this.logicalRegisterIncrement,
    required this.frontRead,
    required this.frontWrite,
    required Map<String, int> inputPorts,
    required Map<String, int> outputPorts,
    required Map<int, CsrModelRegisterDescription> registers,
    required Map<String, int> names,
    required Map<int, (CsrModelRegisterDescription, int)> reads,
    required Map<int, (CsrModelRegisterDescription, int)> writes,
    required Map<int, CsrModelHardwarePorts> hardware,
  })  : inputPorts = Map.unmodifiable(inputPorts),
        outputPorts = Map.unmodifiable(outputPorts),
        registers = Map.unmodifiable(registers),
        names = Map.unmodifiable(names),
        reads = Map.unmodifiable(reads),
        writes = Map.unmodifiable(writes),
        hardware = Map.unmodifiable(hardware);

  /// Elaborates configuration without constructing a ROHD top or runtime.
  factory CsrModelDescription.fromConfig(
    CsrTopConfig config, {
    required String instanceName,
    MemoryPortGeometry? frontRead,
    MemoryPortGeometry? frontWrite,
    Set<String>? hardwareRegisters = const {},
    int logicalRegisterIncrement = 1,
    bool allowLargerRegisters = false,
  }) {
    if (logicalRegisterIncrement < 1) {
      throw ArgumentError.value(logicalRegisterIncrement,
          'logicalRegisterIncrement', 'Must be positive.');
    }
    for (final port in [frontRead, frontWrite]) {
      if (port != null &&
          (port.addressWidth < config.minAddrBits() ||
              (!allowLargerRegisters &&
                  port.dataWidth < config.maxRegWidth()))) {
        throw CsrValidationException(
            'Frontdoor geometry cannot address all CSR registers and blocks.');
      }
    }
    if (frontRead != null &&
        frontWrite != null &&
        frontRead.addressWidth != frontWrite.addressWidth) {
      throw CsrValidationException('CSR frontdoor address widths must match.');
    }
    final registers = <int, CsrModelRegisterDescription>{};
    final names = <String, int>{};
    final reads = <int, (CsrModelRegisterDescription, int)>{};
    final writes = <int, (CsrModelRegisterDescription, int)>{};
    final hardware = <int, CsrModelHardwarePorts>{};
    final inputs = <String, int>{'clk': 1, 'reset': 1};
    final outputs = <String, int>{};
    final remaining = Set<String>.of(hardwareRegisters ?? const {});
    void index(Map<int, (CsrModelRegisterDescription, int)> target,
        CsrModelRegisterDescription entry, MemoryPortGeometry port) {
      if (!allowLargerRegisters && entry.config.width > port.dataWidth) {
        throw CsrValidationException('CSR width exceeds frontdoor data width.');
      }
      for (var offset = 0;
          offset < entry.config.width;
          offset += port.dataWidth) {
        final relative = entry.config.addr +
            offset ~/ port.dataWidth * logicalRegisterIncrement;
        final address = entry.blockBase + relative;
        if (relative >= entry.blockSize ||
            BigInt.from(address) >= BigInt.one << port.addressWidth) {
          throw CsrValidationException(
              'Wide CSR exceeds its address geometry.');
        }
        if (target.containsKey(address)) {
          throw CsrValidationException(
              'Overlapping logical CSR address $address.');
        }
        target[address] = (entry, offset);
      }
    }

    for (final (prefix, port) in [
      ('frontRead', frontRead),
      ('frontWrite', frontWrite),
    ]) {
      if (port != null) {
        inputs['${prefix}_en'] = 1;
        inputs['${prefix}_addr'] = port.addressWidth;
        (prefix == 'frontRead' ? outputs : inputs)['${prefix}_data'] =
            port.dataWidth;
      }
    }
    for (final block in config.blocks) {
      for (final original in block.registers) {
        final address = block.baseAddr + original.addr;
        if (registers.containsKey(address)) {
          throw CsrValidationException('Duplicate CSR address $address.');
        }
        final entry = CsrModelRegisterDescription._(
            address, block.baseAddr, config.blockSizeForBlock(block), original);
        final register = entry.config;
        registers[address] = entry;
        final key = '${block.name}/${register.name}';
        names[key] = address;
        if (frontRead != null && register.isFrontdoorReadable) {
          index(reads, entry, frontRead);
        }
        if (frontWrite != null && register.isFrontdoorWritable) {
          index(writes, entry, frontWrite);
        }
        if (hardwareRegisters != null && !hardwareRegisters.contains(key)) {
          continue;
        }
        remaining.remove(key);
        if (!register.backdoorAccessible) {
          if (hardwareRegisters != null) {
            throw ArgumentError('CSR $key has no hardware backdoor access.');
          }
          continue;
        }
        final prefix = '${instanceName}_${block.name}_${register.name}'
            '_backdoor_${register.name}';
        final ports = CsrModelHardwarePorts._(
          read: register.isBackdoorReadable ? prefix : null,
          writeEnable: register.isBackdoorWritable ? '${prefix}_wrEn' : null,
          writeData: register.isBackdoorWritable ? '${prefix}_wrData' : null,
        );
        hardware[address] = ports;
        if (ports.hasRead) {
          outputs[ports.read!] = register.width;
        }
        if (ports.hasWrite) {
          inputs[ports.writeEnable!] = 1;
          inputs[ports.writeData!] = register.width;
        }
      }
    }
    if (remaining.isNotEmpty) {
      throw ArgumentError(
          'Unknown hardware CSR names: ${remaining.join(', ')}.');
    }
    if (registers.isEmpty) {
      throw CsrValidationException(
          'A CSR model requires at least one register.');
    }
    return CsrModelDescription._(
      asyncReset: config.asyncReset,
      logicalRegisterIncrement: logicalRegisterIncrement,
      frontRead: frontRead,
      frontWrite: frontWrite,
      inputPorts: inputs,
      outputPorts: outputs,
      registers: registers,
      names: names,
      reads: reads,
      writes: writes,
      hardware: hardware,
    );
  }

  /// Largest stored or transferred value width.
  int get maximumValueWidth => max(
      registers.values.map((entry) => entry.config.width).reduce(max),
      max(frontRead?.dataWidth ?? 1, frontWrite?.dataWidth ?? 1));
}
