// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr.dart
// A flexible definition of CSRs.
//
// 2024 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// definitions for various register field access patterns
enum CsrFieldAccess {
  /// register field is read only
  FIELD_READ_ONLY,

  /// register field can be read and written
  FIELD_READ_WRITE,

  /// writing 1's to the field triggers some other action
  /// but the field itself is read only
  FIELD_W1C,
}

/// definitions for various register access patterns
enum CsrAccess {
  /// register field is read only
  REGISTER_READ_ONLY,

  /// register field can be read and written
  REGISTER_READ_WRITE,
}

/// configuration for a register field
class CsrFieldConfig {
  /// starting bit position of the field in the register
  final int start;

  /// number of bits in the field
  final int width;

  /// name for the field
  final String name;

  /// access rules for the field
  final CsrFieldAccess access;

  /// construct a new field configuration
  CsrFieldConfig(this.start, this.width, this.name, this.access);
}

/// configuration for a register
class CsrConfig {
  /// register's address within its block
  final int addr;

  /// number of bits in the register
  final int width;

  /// name for the register
  final String name;

  /// access rules for the register
  final CsrAccess access;

  /// reset value for the register
  final int resetValue;

  /// fields in this register
  final List<CsrFieldConfig> fields = [];

  /// construct a new register configuration
  CsrConfig(this.addr, this.width, this.name, this.access, this.resetValue);

  /// add a register field to this register
  void addField(CsrFieldConfig field) {
    fields.add(field);
  }
}

/// definition for a coherent block of registers
class CsrBlockConfig {
  /// name for the block
  final String name;

  /// address of the first register in the block
  final int baseAddr;

  /// registers in this block
  final List<CsrConfig> registers = [];

  /// construct a new block configuration
  CsrBlockConfig(
    this.name,
    this.baseAddr,
  );

  /// add a register to this block
  void addRegister(CsrConfig register) {
    registers.add(register);
  }
}

/// definition for a top level module containing CSR blocks
class CsrTopConfig {
  /// name for the top module
  final String name;

  /// blocks in this module
  final List<CsrBlockConfig> blocks = [];

  /// construct a new top level configuration
  CsrTopConfig(
    this.name,
  );

  /// add a block to this module
  void addBlock(CsrBlockConfig block) {
    blocks.add(block);
  }
}

/// Logic representation of a CSR
class Csr extends LogicStructure {
  /// bit width of the CSR
  @override
  final int csrWidth;

  /// address for the CSR
  final int addr;

  /// reset value for the CSR
  final int resetValue;

  /// access control for the CSR
  final CsrAccess access;

  /// CSR fields
  final List<Logic> fields;

  /// access control for each field
  final List<CsrFieldAccess> fieldAccess;

  Csr._({
    required super.name,
    required this.csrWidth,
    required this.addr,
    required this.resetValue,
    required this.access,
    required this.fields,
    required this.fieldAccess,
  }) : super(fields);

  factory Csr(
    CsrConfig config,
  ) {
    final fields = <Logic>[];
    var currIdx = 0;
    var rsvdCount = 0;
    final acc = <CsrFieldAccess>[];

    // semantically a register with no fields means that
    // there is one read/write field that is the entire register
    if (config.fields.isEmpty) {
      fields.add(Logic(name: '${config.name}_data', width: config.width));
      acc.add(CsrFieldAccess.FIELD_READ_WRITE);
    }
    // there is at least one field explicitly defined so
    // process them individually
    else {
      for (final field in config.fields) {
        if (field.start > currIdx) {
          fields.add(Logic(
              name: '${config.name}_rsvd_$rsvdCount',
              width: field.start - currIdx));
          acc.add(CsrFieldAccess.FIELD_READ_ONLY);
        }
        fields.add(
            Logic(name: '${config.name}_${field.name}', width: field.width));
        acc.add(field.access);
        currIdx = field.start + field.width;
      }
      if (currIdx < config.width) {
        fields.add(Logic(
            name: '${config.name}_rsvd_$rsvdCount',
            width: config.width - currIdx));
        acc.add(CsrFieldAccess.FIELD_READ_ONLY);
      }
    }
    return Csr._(
      name: config.name,
      csrWidth: config.width,
      addr: config.addr,
      resetValue: config.resetValue,
      access: config.access,
      fields: fields,
      fieldAccess: acc,
    );
  }

  /// extract the address as a Const
  Logic getAddr(int addrWidth) => Const(LogicValue.ofInt(addr, addrWidth));

  /// extract the reset value as a Const
  Logic getResetValue() => Const(LogicValue.ofInt(resetValue, width));

  /// method to return an individual by name
  Logic getField(String nm) =>
      fields.firstWhere((element) => element.name == '${name}_$nm');

  /// perform mapping of original write data based on access config
  Logic getWriteData(Logic wd) {
    // if the whole register is ready only, return the current value
    if (access == CsrAccess.REGISTER_READ_ONLY) {
      return this;
    }
    // register can be written, but still need to look at the fields...
    else {
      var finalWd = wd;
      var currIdx = 0;
      for (var i = 0; i < fields.length; i++) {
        // if the given field is read only, take the current value
        // instead of the new value
        final chk = fieldAccess[i] == CsrFieldAccess.FIELD_READ_ONLY ||
            fieldAccess[i] == CsrFieldAccess.FIELD_W1C;
        if (chk) {
          finalWd = finalWd.withSet(currIdx, fields[i]);
        }
        currIdx += fields[i].width;
      }
      return finalWd;
    }
  }
}

/// a submodule representing a block of CSRs
class CsrBlock extends Module {
  /// address for this block
  final int addr;

  /// width of address in bits
  final int addrWidth;

  /// CSRs in this block
  final List<Csr> csrs;

  /// clk for the module
  late final Logic clk;

  /// reset for the module
  late final Logic reset;

  /// interface for frontdoor writes to CSRs
  late final DataPortInterface frontWrite;

  /// interface for frontdoor reads to CSRs
  late final DataPortInterface frontRead;

  // TODO: how to deal with backdoor writes??

  CsrBlock._({
    required super.name,
    required this.addr,
    required this.csrs,
    required Logic clk,
    required Logic reset,
    required DataPortInterface fdw,
    required DataPortInterface fdr,
  }) : addrWidth = fdw.addrWidth {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    frontWrite = fdw.clone()
      ..connectIO(this, fdw,
          inputTags: {DataPortGroup.control},
          outputTags: {DataPortGroup.data},
          uniquify: (original) => 'frontWrite_$original');
    frontRead = fdr.clone()
      ..connectIO(this, fdr,
          inputTags: {DataPortGroup.control},
          outputTags: {DataPortGroup.data},
          uniquify: (original) => 'frontRead_$original');

    _buildLogic();
  }

  /// create the CsrBlock from a configuration
  factory CsrBlock(
    CsrBlockConfig config,
    Logic clk,
    Logic reset,
    DataPortInterface fdw,
    DataPortInterface fdr,
  ) {
    final csrs = <Csr>[];
    for (final reg in config.registers) {
      csrs.add(Csr(reg));
    }
    return CsrBlock._(
      name: config.name,
      addr: config.baseAddr,
      csrs: csrs,
      clk: clk,
      reset: reset,
      fdw: fdw,
      fdr: fdr,
    );
  }

  /// extract the address as a Const
  Logic getAddr(int addrWidth) => Const(LogicValue.ofInt(addr, addrWidth));

  /// method to return an individual register by name
  Csr getRegister(String nm) =>
      csrs.firstWhere((element) => element.name == nm);

  /// method to return an individual by address
  Csr getRegisterByAddr(int addr) =>
      csrs.firstWhere((element) => element.addr == addr);

  /// API method to extract read data from block
  Logic rdData() => frontRead.data;

  void _buildLogic() {
    // individual CSR write logic
    for (final csr in csrs) {
      Sequential(clk, reset: reset, resetValues: {
        csr: csr.getResetValue(),
      }, [
        If(frontWrite.en & frontWrite.addr.eq(csr.getAddr(addrWidth)), then: [
          csr < csr.getWriteData(frontWrite.data),
        ], orElse: [
          csr < csr,
        ]),
      ]);
    }

    // individual CSR read logic
    final rdData = Logic(name: 'rdData', width: frontRead.dataWidth);
    final rdCases = csrs
        .map((csr) => CaseItem(csr.getAddr(addrWidth), [
              rdData < csr,
            ]))
        .toList();
    Combinational([
      Case(frontRead.addr, rdCases, defaultItem: [
        rdData < Const(0, width: frontRead.dataWidth),
      ]),
    ]);
    frontRead.data <= rdData;
  }
}

class CsrTop extends Module {
  /// width of address in bits
  final int addrWidth;

  /// CSRs in this block
  final List<CsrBlock> blocks;

  /// clk for the module
  late final Logic clk;

  /// reset for the module
  late final Logic reset;

  /// interface for frontdoor writes to CSRs
  late final DataPortInterface frontWrite;

  /// interface for frontdoor reads to CSRs
  late final DataPortInterface frontRead;

  // individual sub interfaces to blocks
  final List<DataPortInterface> _fdWrites = [];
  final List<DataPortInterface> _fdReads = [];

  CsrTop._({
    required super.name,
    required this.blocks,
    required Logic clk,
    required Logic reset,
    required DataPortInterface fdw,
    required DataPortInterface fdr,
  }) : addrWidth = fdw.addrWidth {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    frontWrite = fdw.clone()
      ..connectIO(this, fdw,
          inputTags: {DataPortGroup.control},
          outputTags: {DataPortGroup.data},
          uniquify: (original) => 'frontWrite_$original');
    frontRead = fdr.clone()
      ..connectIO(this, fdr,
          inputTags: {DataPortGroup.control},
          outputTags: {DataPortGroup.data},
          uniquify: (original) => 'frontRead_$original');

    _buildLogic();
  }

  /// create the CsrBlock from a configuration
  factory CsrTop(
    CsrTopConfig config,
    Logic clk,
    Logic reset,
    DataPortInterface fdw,
    DataPortInterface fdr,
  ) {
    final blks = <CsrBlock>[];
    for (final block in config.blocks) {
      // TODO: how to derive the address width
      // TODO: how to connect properly top level
      // IDEA: need to remove the block portion of the address
      _fdWrites.add(DataPortInterface(fdw.dataWidth, TODO));
      _fdReads.add(DataPortInterface(fdr.dataWidth, TODO));
      blks.add(CsrBlock(block, clk, reset, _fdWrites.last, _fdReads.last));
    }
    return CsrTop._(
      name: config.name,
      blocks: blks,
      clk: clk,
      reset: reset,
      fdw: fdw,
      fdr: fdr,
    );
  }

  // TODO: how to map the address to the correct block
  void _buildLogic() {
    // drive frontdoor write and read inputs
    for (var i = 0; i < blocks.length; i++) {
      _fdWrites[i].en <=
          frontWrite.en & frontWrite.addr.eq(blocks[i].getAddr(addrWidth));
      _fdReads[i].en <=
          frontWrite.en & frontWrite.addr.eq(blocks[i].getAddr(addrWidth));

      _fdWrites[i].addr <= frontWrite.addr;
      _fdReads[i].addr <= frontWrite.addr;

      _fdWrites[i].data <= frontWrite.data;
    }

    // capture frontdoor read output
    final rdData = Logic(name: 'rdData', width: frontRead.dataWidth);
    final rdCases = blocks
        .map((block) => CaseItem(block.getAddr(addrWidth), [
              rdData < block.rdData(),
            ]))
        .toList();
    Combinational([
      Case(frontRead.addr, rdCases, defaultItem: [
        rdData < Const(0, width: frontRead.dataWidth),
      ]),
    ]);
    frontRead.data <= rdData;
  }

  /// method to return an individual by name
  CsrBlock getBlock(String nm) =>
      blocks.firstWhere((element) => element.name == nm);

  /// method to return an individual by address
  CsrBlock getBlockByAddr(int addr) =>
      blocks.firstWhere((element) => element.addr == addr);
}
