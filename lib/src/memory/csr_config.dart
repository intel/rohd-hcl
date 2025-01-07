// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_config.dart
// Configuration objects for defining CSRs.
//
// 2024 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

/// Definitions for various register field access patterns.
enum CsrFieldAccess {
  /// Register field is read only.
  // ignore: constant_identifier_names
  READ_ONLY,

  /// Register field can be read and written.
  // ignore: constant_identifier_names
  READ_WRITE,

  /// Writing 1's to the field triggers some other action,
  /// but the field itself is read only.
  // ignore: constant_identifier_names
  WRITE_ONES_CLEAR,

  /// Only legal values can be written
  // ignore: constant_identifier_names
  READ_WRITE_LEGAL,
}

/// Definitions for various register access patterns.
enum CsrAccess {
  /// Register is read only.
  // ignore: constant_identifier_names
  READ_ONLY,

  /// Register can be read and written.
  // ignore: constant_identifier_names
  READ_WRITE,
}

/// Configuration for a register field.
///
/// If [start] and/or [width] is symbolic based on
/// the parent register width and/or other fields,
/// it is assumed that those symbolic values are resolved
/// before construction of the field config.
/// If a field should be duplicated n times within a register,
/// it is assumed that this object is instantiated n times
/// within the parent register config accordingly.
class CsrFieldConfig {
  /// Starting bit position of the field in the register.
  final int start;

  /// Number of bits in the field.
  final int width;

  /// Name for the field.
  final String name;

  /// Access rule for the field.
  final CsrFieldAccess access;

  /// A list of legal values for the field.
  ///
  /// This list can be empty and in general is only
  /// applicable for fields with FIELD_WRITE_ANY_READ_LEGAL access.
  final List<int> legalValues = [];

  /// Construct a new field configuration.
  CsrFieldConfig({
    required this.start,
    required this.width,
    required this.name,
    required this.access,
  });

  /// Add a legal value for the field.
  ///
  /// Only applicable for fields with FIELD_WRITE_ANY_READ_LEGAL access.
  void addLegalValue(int val) => legalValues.add(val);

  /// Method to return a legal value from an illegal one.
  ///
  /// Only applicable for fields with FIELD_WRITE_ANY_READ_LEGAL access.
  /// This is a default implementation that simply takes the first
  /// legal value but can be overridden in a derived class.
  int transformIllegalValue() => legalValues[0];
}

/// Configuration for an architectural register.
///
/// Any architecturally fixed fields can be added directly to this class,
/// but any fields with implementation specific config should be
/// left until the instantiation of the register.
class CsrConfig {
  /// Name for the register.
  final String name;

  /// Access rule for the register.
  final CsrAccess access;

  /// Architectural reset value for the register.
  ///
  /// Note that this can be overridden in the instantiation of the register.
  int resetValue;

  /// Fields in this register.
  final List<CsrFieldConfig> fields = [];

  /// Construct a new register configuration.
  CsrConfig({
    required this.name,
    required this.access,
    this.resetValue = 0,
  });

  /// Accessor to the config of a particular field
  /// within the register by name [nm].
  CsrFieldConfig getFieldByName(String nm) =>
      fields.firstWhere((element) => element.name == nm);
}

/// Configuration for a register instance.
///
/// Apply implementation specific information to an architectural register.
/// This includes instantiation of fields that require runtime configuration.
/// Such runtime configuration might also apply for conditional
/// instantiation of fields within the register
class CsrInstanceConfig {
  /// Underlying architectural configuration.
  final CsrConfig arch;

  /// Register's address within its block
  ///
  /// This can be thought of as an offset relative to the block address.
  /// This can also be thought of as a unique ID for this register.
  final int addr;

  /// Number of bits in the register.
  final int width;

  /// Accessor to the name of the architectural register.
  String get name => arch.name;

  /// Accessor to the architectural access rule of the register.
  CsrAccess get access => arch.access;

  /// Accessor to the architectural reset value of the register.
  int get resetValue => arch.resetValue;

  /// Accessor to the fields of the register.
  List<CsrFieldConfig> get fields => arch.fields;

  /// Construct a new register configuration.
  CsrInstanceConfig({
    required this.arch,
    required this.addr,
    required this.width,
    int? resetValue,
  }) {
    if (resetValue != null) {
      arch.resetValue = resetValue;
    }
  }

  /// Accessor to the config of a particular field
  /// within the register by name [nm].
  CsrFieldConfig getFieldByName(String nm) => arch.getFieldByName(nm);
}

/// Definition for a coherent block of registers.
///
/// Blocks by definition are instantiations of registers and
/// hence require CsrInstanceConfig objects.
/// This class is also where the choice to instantiate
/// any conditional registers should take place.
class CsrBlockConfig {
  /// Name for the block.
  final String name;

  /// Address off of which all register addresses are offset.
  final int baseAddr;

  /// Registers in this block.
  final List<CsrInstanceConfig> registers = [];

  /// Construct a new block configuration.
  CsrBlockConfig({
    required this.name,
    required this.baseAddr,
  });

  /// Accessor to the config of a particular register
  /// within the block by name [nm].
  CsrInstanceConfig getRegisterByName(String nm) =>
      registers.firstWhere((element) => element.name == nm);

  /// Accessor to the config of a particular register
  /// within the block by relative address [addr].
  CsrInstanceConfig getRegisterByAddr(int addr) =>
      registers.firstWhere((element) => element.addr == addr);
}

/// Definition for a top level module containing CSR blocks.
///
/// This class is also where the choice to instantiate
/// any conditional blocks should take place.
class CsrTopConfig {
  /// Name for the top module.
  final String name;

  /// Address bits dedicated to the individual registers.
  ///
  /// This is effectively the number of LSBs in an incoming address
  /// to ignore when assessing the address of a block.
  final int blockOffsetWidth;

  /// Blocks in this module.
  final List<CsrBlockConfig> blocks = [];

  /// Construct a new top level configuration.
  CsrTopConfig({
    required this.name,
    required this.blockOffsetWidth,
  });

  /// Accessor to the config of a particular register block
  /// within the module by name [nm].
  CsrBlockConfig getBlockByName(String nm) =>
      blocks.firstWhere((element) => element.name == nm);

  /// Accessor to the config of a particular register block
  /// within the module by relative address [addr].
  CsrBlockConfig getBlockByAddr(int addr) =>
      blocks.firstWhere((element) => element.baseAddr == addr);
}
