// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_config.dart
// Configuration objects for defining CSRs.
//
// 2024 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

/// Targeted Exception type for Csr valiation.
class CsrValidationException implements Exception {
  /// Message associated with the Exception.
  final String message;

  /// Public constructor.
  CsrValidationException(this.message);

  @override
  String toString() => message;
}

/// Definitions for various register field access patterns.
enum CsrFieldAccess {
  /// Register field is read only.
  readOnly,

  /// Register field can be read and written.
  readWrite,

  /// Writing 1's to the field triggers some other action,
  /// but the field itself is read only.
  writeOnesClear,

  /// Only legal values can be written
  readWriteLegal,
}

/// Definitions for various register access patterns.
enum CsrAccess {
  /// Register is read only.
  readOnly,

  /// Register can be read and written.
  readWrite,
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

  /// Reset value for the field.
  ///
  /// Can be unspecified in which case takes 0.
  final int resetValue;

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
    this.resetValue = 0,
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

  /// Method to validate the configuration of a single field.
  void validate() {
    // reset value must fit within the field's width
    if (resetValue.bitLength > width) {
      throw CsrValidationException(
          'Field $name reset value does not fit within the field.');
    }

    // there must be at least 1 legal value for a READ_WRITE_LEGAL field
    // and the reset value must be legal
    // and every legal value must fit within the field's width
    if (access == CsrFieldAccess.readWriteLegal) {
      if (legalValues.isEmpty) {
        throw CsrValidationException(
            'Field $name has no legal values but has access READ_WRITE_LEGAL.');
      } else if (!legalValues.contains(resetValue)) {
        throw CsrValidationException(
            'Field $name reset value is not a legal value.');
      }

      for (final lv in legalValues) {
        if (lv.bitLength > width) {
          throw CsrValidationException(
              'Field $name legal value $lv does not fit within the field.');
        }
      }
    }
  }

  /// Deep clone method.
  CsrFieldConfig clone() => CsrFieldConfig(
        start: start,
        width: width,
        name: name,
        access: access,
        resetValue: resetValue,
      )..legalValues.addAll(legalValues);
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
  int? resetValue;

  /// Architectural property in which the register can be frontdoor read.
  ///
  /// A frontdoor read occurs explicitly using the register's address.
  bool isFrontdoorReadable;

  /// Architectural property in which the register can be frontdoor written.
  ///
  /// A frontdoor write occurs explicitly using the register's address.
  bool isFrontdoorWritable;

  /// Architectural property in which the register can be backdoor read.
  ///
  /// A backdoor read exposes the register's value combinationally to the HW.
  bool isBackdoorReadable;

  /// Architectural property in which the register can be backdoor written.
  ///
  /// A backdoor write exposes direct write access to the HW through an enable.
  bool isBackdoorWritable;

  /// Fields in this register.
  final List<CsrFieldConfig> fields = [];

  /// Construct a new register configuration.
  CsrConfig({
    required this.name,
    required this.access,
    this.resetValue,
    this.isFrontdoorReadable = true,
    this.isFrontdoorWritable = true,
    this.isBackdoorReadable = true,
    this.isBackdoorWritable = true,
  });

  /// Accessor to the config of a particular field
  /// within the register by name [name].
  CsrFieldConfig getFieldByName(String name) =>
      fields.firstWhere((element) => element.name == name);

  /// Helper to derive a reset value for the register from its fields.
  ///
  /// Only should be used if a reset value isn't explicitly provided.
  int _resetValueFromFields() {
    var rv = 0;
    for (final field in fields) {
      rv |= field.resetValue << field.start;
    }
    return rv;
  }

  /// Method to validate the configuration of a single register.
  ///
  /// Must check that its fields are mutually valid.
  void validate() {
    final ranges = <List<int>>[];
    final issues = <String>[];
    for (final field in fields) {
      // check the field on its own for issues
      try {
        field.validate();
      } on Exception catch (e) {
        issues.add(e.toString());
      }

      // check to ensure that the field doesn't overlap with any other field
      // overlap can occur on name or on bit placement
      for (var i = 0; i < ranges.length; i++) {
        // check against all other names
        if (field.name == fields[i].name) {
          issues.add('Field ${field.name} is duplicated.');
        }
        // check field start to see if it falls within another field
        else if (field.start >= ranges[i][0] && field.start <= ranges[i][1]) {
          issues.add(
              'Field ${field.name} overlaps with field ${fields[i].name}.');
        }
        // check field end to see if it falls within another field
        else if (field.start + field.width - 1 >= ranges[i][0] &&
            field.start + field.width - 1 <= ranges[i][1]) {
          issues.add(
              'Field ${field.name} overlaps with field ${fields[i].name}.');
        }
      }
      ranges.add([field.start, field.start + field.width - 1]);
    }
    if (issues.isNotEmpty) {
      throw CsrValidationException(issues.join('\n'));
    }
  }

  /// Deep clone method.
  CsrConfig clone() => CsrConfig(
        name: name,
        access: access,
        resetValue: resetValue,
        isFrontdoorReadable: isFrontdoorReadable,
        isFrontdoorWritable: isFrontdoorWritable,
        isBackdoorReadable: isBackdoorReadable,
        isBackdoorWritable: isBackdoorWritable,
      )..fields.addAll(fields.map((e) => e.clone()));
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
  int get resetValue => arch.resetValue ?? arch._resetValueFromFields();

  /// Accessor to the architectural frontdoor readability of the register.
  bool get isFrontdoorReadable => arch.isFrontdoorReadable;

  /// Accessor to the architectural frontdoor writability of the register.
  bool get isFrontdoorWritable => arch.isFrontdoorWritable;

  /// Accessor to the architectural backdoor readability of the register.
  bool get isBackdoorReadable => arch.isBackdoorReadable;

  /// Accessor to the architectural backdoor writability of the register.
  bool get isBackdoorWritable => arch.isBackdoorWritable;

  /// Helper for determining if the register is frontdoor accessible.
  bool get frontdoorAccessible => isFrontdoorReadable || isFrontdoorWritable;

  /// Helper for determining if the register is frontdoor accessible.
  bool get backdoorAccessible => isBackdoorReadable || isBackdoorWritable;

  /// Accessor to the fields of the register.
  List<CsrFieldConfig> get fields => arch.fields;

  /// Construct a new register configuration.
  CsrInstanceConfig({
    required this.arch,
    required this.addr,
    required this.width,
    int? resetValue,
    bool? isFrontdoorReadable,
    bool? isFrontdoorWritable,
    bool? isBackdoorReadable,
    bool? isBackdoorWritable,
  }) {
    if (resetValue != null) {
      arch.resetValue = resetValue;
    }
    if (isFrontdoorReadable != null) {
      arch.isFrontdoorReadable = isFrontdoorReadable;
    }
    if (isFrontdoorWritable != null) {
      arch.isFrontdoorWritable = isFrontdoorWritable;
    }
    if (isBackdoorReadable != null) {
      arch.isBackdoorReadable = isBackdoorReadable;
    }
    if (isBackdoorWritable != null) {
      arch.isBackdoorWritable = isBackdoorWritable;
    }
  }

  /// Accessor to the config of a particular field
  /// within the register by name [name].
  CsrFieldConfig getFieldByName(String name) => arch.getFieldByName(name);

  /// Method to validate the configuration of a single register.
  ///
  /// Must check that its fields are mutually valid.
  void validate() {
    // start by running architectural register validation
    arch.validate();

    // reset value must fit within the register's width
    if (resetValue.bitLength > width) {
      throw CsrValidationException(
          'Register $name reset value does not fit within its width.');
    }

    // check that the field widths don't exceed the register width
    var impliedEnd = 0;
    for (final field in fields) {
      final currEnd = field.start + field.width - 1;
      if (currEnd > impliedEnd) {
        impliedEnd = currEnd;
      }
    }
    if (impliedEnd > width - 1) {
      throw CsrValidationException(
          'Register width implied by its fields exceeds true register width.');
    }
  }

  /// Deep clone method.
  CsrInstanceConfig clone() => CsrInstanceConfig(
        arch: arch.clone(),
        addr: addr,
        width: width,
      );
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
  /// within the block by name [name].
  CsrInstanceConfig getRegisterByName(String name) =>
      registers.firstWhere((element) => element.name == name);

  /// Accessor to the config of a particular register
  /// within the block by relative address [addr].
  CsrInstanceConfig getRegisterByAddr(int addr) =>
      registers.firstWhere((element) => element.addr == addr);

  /// Method to validate the configuration of a single register block.
  ///
  /// Must check that its registers are mutually valid.
  /// Note that this method does not call the validate method of
  /// the individual registers in the block. It is assumed that
  /// register validation is called separately (i.e., in Csr HW construction).
  void validate() {
    // at least 1 register
    if (registers.isEmpty) {
      throw CsrValidationException('Block $name has no registers.');
    }

    // no two registers with the same name
    // no two registers with the same address
    final issues = <String>[];
    for (var i = 0; i < registers.length; i++) {
      for (var j = i + 1; j < registers.length; j++) {
        if (registers[i].name == registers[j].name) {
          issues.add('Register ${registers[i].name} is duplicated.');
        }
        if (registers[i].addr == registers[j].addr) {
          issues.add('Register ${registers[i].name} has a duplicate address.');
        }
      }
    }
    if (issues.isNotEmpty) {
      throw CsrValidationException(issues.join('\n'));
    }
  }

  /// Method to determine the minimum number of address bits
  /// needed to address all registers in the block. This is
  /// based on the maximum register address offset.
  int minAddrBits() {
    var maxAddr = 0;
    for (final reg in registers) {
      if (reg.addr > maxAddr) {
        maxAddr = reg.addr;
      }
    }
    return maxAddr.bitLength;
  }

  /// Method to determine the maximum register size.
  /// This is important for interface data width validation.
  int maxRegWidth() {
    var maxWidth = 0;
    for (final reg in registers) {
      if (reg.width > maxWidth) {
        maxWidth = reg.width;
      }
    }
    return maxWidth;
  }

  /// Deep clone method.
  CsrBlockConfig clone() => CsrBlockConfig(
        name: name,
        baseAddr: baseAddr,
      )..registers.addAll(registers.map((e) => e.clone()));
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
  /// within the module by name [name].
  CsrBlockConfig getBlockByName(String name) =>
      blocks.firstWhere((element) => element.name == name);

  /// Accessor to the config of a particular register block
  /// within the module by relative address [addr].
  CsrBlockConfig getBlockByAddr(int addr) =>
      blocks.firstWhere((element) => element.baseAddr == addr);

  /// Method to validate the configuration of register top module.
  ///
  /// Must check that its blocks are mutually valid.
  /// Note that this method does not call the validate method of
  /// the individual blocks. It is assumed that
  /// block validation is called separately (i.e., in CsrBlock HW construction).
  void validate() {
    // at least 1 block
    if (blocks.isEmpty) {
      throw CsrValidationException(
          'Csr top module $name has no register blocks.');
    }

    // no two blocks with the same name
    // no two blocks with the same base address
    // no two blocks with base addresses that are too close together
    // also compute the max min address bits across the blocks
    final issues = <String>[];
    var maxMinAddrBits = 0;
    for (var i = 0; i < blocks.length; i++) {
      final currMaxMin = blocks[i].minAddrBits();
      if (currMaxMin > maxMinAddrBits) {
        maxMinAddrBits = currMaxMin;
      }

      for (var j = i + 1; j < blocks.length; j++) {
        if (blocks[i].name == blocks[j].name) {
          issues.add('Register block ${blocks[i].name} is duplicated.');
        }

        if (blocks[i].baseAddr == blocks[j].baseAddr) {
          issues.add(
              'Register block ${blocks[i].name} has a duplicate base address.');
        } else if ((blocks[i].baseAddr - blocks[j].baseAddr).abs().bitLength <
            blockOffsetWidth) {
          issues.add(
              'Register blocks ${blocks[i].name} and ${blocks[j].name} are '
              'too close together per the block offset width.');
        }
      }
    }
    if (issues.isNotEmpty) {
      throw CsrValidationException(issues.join('\n'));
    }

    // is the block offset width big enough to address
    // every register in every block
    if (blockOffsetWidth < maxMinAddrBits) {
      throw CsrValidationException(
          'Block offset width is too small to address all register in all '
          'blocks in the module. The minimum offset width is $maxMinAddrBits.');
    }
  }

  /// Method to determine the minimum number of address bits
  /// needed to address all registers across all blocks. This is
  /// based on the maximum block base address. Note that we independently
  /// validate the block offset width relative to the base addresses
  /// so we can trust the simpler analysis here.
  int minAddrBits() {
    var maxAddr = 0;
    for (final block in blocks) {
      if (block.baseAddr > maxAddr) {
        maxAddr = block.baseAddr;
      }
    }
    return maxAddr.bitLength;
  }

  /// Method to determine the maximum register size.
  /// This is important for interface data width validation.
  int maxRegWidth() {
    var maxWidth = 0;
    for (final block in blocks) {
      if (block.maxRegWidth() > maxWidth) {
        maxWidth = block.maxRegWidth();
      }
    }
    return maxWidth;
  }

  /// Deep clone method.
  CsrTopConfig clone() => CsrTopConfig(
        name: name,
        blockOffsetWidth: blockOffsetWidth,
      )..blocks.addAll(blocks.map((e) => e.clone()));
}
