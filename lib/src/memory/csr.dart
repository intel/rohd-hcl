// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr.dart
// A flexible definition of CSRs.
//
// 2024 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Logic representation of a CSR.
///
/// Semantically, a register can be created with no fields.
/// In this case, a single implicit field is created that is
/// read/write and the entire width of the register.
class Csr extends LogicStructure {
  /// Configuration for the CSR.
  final CsrInstanceConfig config;

  /// A list of indices of all of the reserved fields in the CSR.
  /// This is necessary because the configuration does not explicitly
  /// define reserved fields, but they must be accounted for
  /// in certain logic involving the CSR.
  final List<int> rsvdIndices;

  /// Getter for the address of the CSR.
  int get addr => config.addr;

  /// Getter for the reset value of the CSR.
  int get resetValue => config.resetValue;

  /// Getter for the access control of the CSR.
  CsrAccess get access => config.access;

  /// Getter for the field configuration of the CSR
  List<CsrFieldConfig> get fields => config.fields;

  /// Explicit constructor.
  ///
  /// This constructor is private and should not be used directly.
  /// Instead, the factory constructor [Csr] should be used.
  /// This facilitates proper calling of the super constructor.
  Csr._({
    required this.config,
    required this.rsvdIndices,
    required List<Logic> fields,
  }) : super(fields, name: config.name);

  /// Factory constructor for [Csr].
  ///
  /// Because LogicStructure requires a List<Logic> upon construction,
  /// the factory method assists in creating the List upfront before
  /// the LogicStructure constructor is called.
  factory Csr(
    CsrInstanceConfig config,
  ) {
    final fields = <Logic>[];
    final rsvds = <int>[];
    var currIdx = 0;
    var rsvdCount = 0;

    // semantically a register with no fields means that
    // there is one read/write field that is the entire register
    if (config.fields.isEmpty) {
      fields.add(Logic(name: '${config.name}_data', width: config.width));
    }
    // there is at least one field explicitly defined so
    // process them individually
    else {
      for (final field in config.fields) {
        if (field.start > currIdx) {
          fields.add(Logic(
              name: '${config.name}_rsvd_$rsvdCount',
              width: field.start - currIdx));
          rsvds.add(fields.length - 1);
          rsvdCount++;
        }
        fields.add(
            Logic(name: '${config.name}_${field.name}', width: field.width));
        currIdx = field.start + field.width;
      }
      if (currIdx < config.width) {
        fields.add(Logic(
            name: '${config.name}_rsvd_$rsvdCount',
            width: config.width - currIdx));
        rsvds.add(fields.length - 1);
      }
    }
    return Csr._(
      config: config,
      rsvdIndices: rsvds,
      fields: fields,
    );
  }

  /// Accessor to the bits of a particular field within the CSR by name [nm].
  Logic getField(String nm) =>
      elements.firstWhere((element) => element.name == '${name}_$nm');

  /// Accessor to the config of a particular field within the CSR by name [nm].
  CsrFieldConfig getFieldConfigByName(String nm) => config.getFieldByName(nm);

  /// Given some arbitrary data [wd] to write to this CSR,
  /// return the data that should actually be written based
  /// on the access control of the CSR and its fields.
  Logic getWriteData(Logic wd) {
    // if the whole register is ready only, return the current value
    if (access == CsrAccess.READ_ONLY) {
      return this;
    }
    // register can be written, but still need to look at the fields...
    else {
      // special case of no explicit fields defined
      // in this case, we have an implicit read/write field
      // so there is nothing special to do
      if (fields.isEmpty) {
        return wd;
      }

      // otherwise, we need to look at the fields
      var finalWd = wd;
      var currIdx = 0;
      var currField = 0;
      for (var i = 0; i < elements.length; i++) {
        // if the given field is reserved or read only
        // take the current value instead of the new value
        final chk1 = rsvdIndices.contains(i);
        if (chk1) {
          finalWd = finalWd.withSet(currIdx, elements[i]);
          currIdx += elements[i].width;
          continue;
        }

        // if the given field is read only
        // take the current value instead of the new value
        final chk2 = fields[currField].access == CsrFieldAccess.READ_ONLY ||
            fields[currField].access == CsrFieldAccess.WRITE_ONES_CLEAR;
        if (chk2) {
          finalWd = finalWd.withSet(currIdx, elements[i]);
          currField++;
          currIdx += elements[i].width;
          continue;
        }

        if (fields[currField].access == CsrFieldAccess.READ_WRITE_LEGAL) {
          // if the given field is write legal
          // make sure the value is in fact legal
          // and transform it if not
          final origVal =
              wd.getRange(currIdx, currIdx + fields[currField].width);
          final legalCases = <Logic, Logic>{};
          for (var i = 0; i < fields[currField].legalValues.length; i++) {
            legalCases[Const(fields[currField].legalValues[i],
                width: fields[currField].width)] = origVal;
          }
          final newVal = cases(
              origVal,
              conditionalType: ConditionalType.unique,
              legalCases,
              defaultValue: Const(fields[currField].transformIllegalValue(),
                  width: fields[currField].width));

          finalWd = finalWd.withSet(currIdx, newVal);
          currField++;
          currIdx += elements[i].width;
        } else {
          // normal read/write field
          currField++;
          currIdx += elements[i].width;
        }
      }
      return finalWd;
    }
  }
}

/// Logic representation of a block of registers.
///
/// A block is just a collection of registers that are
/// readable and writable through an addressing scheme
/// that is relative (offset from) the base address of the block.
// TODO:
//  backdoor reads and writes
class CsrBlock extends Module {
  /// Configuration for the CSR block.
  final CsrBlockConfig config;

  /// CSRs in this block.
  final List<Csr> csrs;

  /// Clock for the module.
  late final Logic _clk;

  /// Reset for the module.
  late final Logic _reset;

  /// Interface for frontdoor writes to CSRs.
  late final DataPortInterface _frontWrite;

  /// Interface for frontdoor reads to CSRs.
  late final DataPortInterface _frontRead;

  /// Getter for block's base address
  int get baseAddr => config.baseAddr;

  /// Getter for the CSR configurations.
  List<CsrInstanceConfig> get registers => config.registers;

  /// Constructor for a CSR block.
  CsrBlock._({
    required this.config,
    required this.csrs,
    required Logic clk,
    required Logic reset,
    required DataPortInterface fdw,
    required DataPortInterface fdr,
  }) : super(name: config.name) {
    _clk = addInput('clk', clk);
    _reset = addInput('reset', reset);

    _frontWrite = fdw.clone()
      ..connectIO(this, fdw,
          inputTags: {DataPortGroup.control, DataPortGroup.data},
          outputTags: {},
          uniquify: (original) => 'frontWrite_$original');
    _frontRead = fdr.clone()
      ..connectIO(this, fdr,
          inputTags: {DataPortGroup.control},
          outputTags: {DataPortGroup.data},
          uniquify: (original) => 'frontRead_$original');

    _buildLogic();
  }

  /// Create the CsrBlock from a configuration.
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
      config: config,
      csrs: csrs,
      clk: clk,
      reset: reset,
      fdw: fdw,
      fdr: fdr,
    );
  }

  /// Accessor to the config of a particular register
  /// within the block by name [nm].
  CsrInstanceConfig getRegisterByName(String nm) =>
      config.getRegisterByName(nm);

  /// Accessor to the config of a particular register
  /// within the block by relative address [addr].
  CsrInstanceConfig getRegisterByAddr(int addr) =>
      config.getRegisterByAddr(addr);

  void _buildLogic() {
    final addrWidth = _frontWrite.addrWidth;

    // individual CSR write logic
    for (final csr in csrs) {
      Sequential(_clk, reset: _reset, resetValues: {
        csr: csr.resetValue,
      }, [
        If(
            _frontWrite.en &
                _frontWrite.addr.eq(Const(csr.addr, width: addrWidth)),
            then: [
              csr < csr.getWriteData(_frontWrite.data),
            ],
            orElse: [
              csr < csr,
            ]),
      ]);
    }

    // individual CSR read logic
    final rdData = Logic(name: 'rdData', width: _frontRead.dataWidth);
    final rdCases = csrs
        .map((csr) => CaseItem(Const(csr.addr, width: addrWidth), [
              rdData < csr,
            ]))
        .toList();
    Combinational([
      Case(_frontRead.addr, rdCases, defaultItem: [
        rdData < Const(0, width: _frontRead.dataWidth),
      ]),
    ]);
    _frontRead.data <= rdData;
  }
}

/// Top level module encapsulating groups of CSRs.
///
/// This top module can include arbitrarily many CSR blocks.
/// Individual blocks are addressable using some number of
/// MSBs of the incoming address and registers within the given block
/// are addressable using the remaining LSBs of the incoming address.
// TODO:
//  backdoor reads and writes
class CsrTop extends Module {
  /// width of the LSBs of the address
  /// to ignore when mapping to blocks
  final int blockOffsetWidth;

  /// Configuration for the CSR Top module.
  final CsrTopConfig config;

  /// List of CSR blocks in this module.
  final List<CsrBlock> _blocks = [];

  /// Clock for the module.
  late final Logic _clk;

  /// Reset for the module.
  late final Logic _reset;

  /// Interface for frontdoor writes to CSRs.
  late final DataPortInterface _frontWrite;

  /// Interface for frontdoor reads to CSRs.
  late final DataPortInterface _frontRead;

  // individual sub interfaces to blocks
  final List<DataPortInterface> _fdWrites = [];
  final List<DataPortInterface> _fdReads = [];

  /// Getter for the block configurations of the CSR.
  List<CsrBlockConfig> get blocks => config.blocks;

  CsrTop._({
    required this.config,
    required this.blockOffsetWidth, // TODO: make this part of the config??
    required Logic clk,
    required Logic reset,
    required DataPortInterface fdw,
    required DataPortInterface fdr,
  }) : super(name: config.name) {
    _clk = addInput('clk', clk);
    _reset = addInput('reset', reset);

    _frontWrite = fdw.clone()
      ..connectIO(this, fdw,
          inputTags: {DataPortGroup.control, DataPortGroup.data},
          outputTags: {},
          uniquify: (original) => '${name}_frontWrite_$original');
    _frontRead = fdr.clone()
      ..connectIO(this, fdr,
          inputTags: {DataPortGroup.control},
          outputTags: {DataPortGroup.data},
          uniquify: (original) => '${name}_frontRead_$original');

    for (final block in config.blocks) {
      _fdWrites.add(DataPortInterface(fdw.dataWidth, blockOffsetWidth));
      _fdReads.add(DataPortInterface(fdr.dataWidth, blockOffsetWidth));
      _blocks.add(CsrBlock(block, _clk, _reset, _fdWrites.last, _fdReads.last));
    }

    _buildLogic();
  }

  /// create the CsrBlock from a configuration
  factory CsrTop(
    CsrTopConfig config,
    Logic clk,
    Logic reset,
    DataPortInterface fdw,
    DataPortInterface fdr,
  ) =>
      CsrTop._(
        config: config,
        blockOffsetWidth: config.blockOffsetWidth,
        clk: clk,
        reset: reset,
        fdw: fdw,
        fdr: fdr,
      );

  /// Accessor to the config of a particular register block
  /// within the module by name [nm].
  CsrBlockConfig getBlockByName(String nm) => config.getBlockByName(nm);

  /// Accessor to the config of a particular register block
  /// within the module by relative address [addr].
  CsrBlockConfig getBlockByAddr(int addr) => config.getBlockByAddr(addr);

  void _buildLogic() {
    final addrWidth = _frontWrite.addrWidth;

    // mask out LSBs to perform a match on block
    final maskedFrontWrAddr = _frontWrite.addr &
        ~Const((1 << blockOffsetWidth) - 1, width: addrWidth);
    final maskedFrontRdAddr =
        _frontRead.addr & ~Const((1 << blockOffsetWidth) - 1, width: addrWidth);

    // shift out MSBs to pass the appropriate address into the blocks
    final shiftedFrontWrAddr = _frontWrite.addr.getRange(0, blockOffsetWidth);
    final shiftedFrontRdAddr = _frontRead.addr.getRange(0, blockOffsetWidth);

    // drive frontdoor write and read inputs
    for (var i = 0; i < _blocks.length; i++) {
      _fdWrites[i].en <=
          _frontWrite.en &
              maskedFrontWrAddr
                  .eq(Const(_blocks[i].baseAddr, width: addrWidth));
      _fdReads[i].en <=
          _frontWrite.en &
              maskedFrontRdAddr
                  .eq(Const(_blocks[i].baseAddr, width: addrWidth));

      _fdWrites[i].addr <= shiftedFrontWrAddr;
      _fdReads[i].addr <= shiftedFrontRdAddr;

      _fdWrites[i].data <= _frontWrite.data;
    }

    // capture frontdoor read output
    final rdData = Logic(name: 'rdData', width: _frontRead.dataWidth);
    final rdCases = _blocks
        .asMap()
        .entries
        .map(
            (block) => CaseItem(Const(block.value.baseAddr, width: addrWidth), [
                  rdData < _fdReads[block.key].data,
                ]))
        .toList();
    Combinational([
      Case(maskedFrontRdAddr, rdCases, defaultItem: [
        rdData < Const(0, width: _frontRead.dataWidth),
      ]),
    ]);
    _frontRead.data <= rdData;
  }
}
