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

/// A grouping for interface signals of [CsrBackdoorInterface]s.
enum CsrBackdoorPortGroup {
  /// For HW reads of CSRs.
  read,

  /// For HW writes to CSRs.
  write
}

/// An interface to interact very simply with a CSR.
///
/// Can be used for either read, write or both directions.
class CsrBackdoorInterface extends Interface<CsrBackdoorPortGroup> {
  /// Configuration for the associated CSR.
  final CsrInstanceConfig config;

  /// Should this CSR be readable by the HW.
  final bool hasRead;

  /// Should this CSR be writable by the HW.
  final bool hasWrite;

  /// The width of data in the CSR.
  final int dataWidth;

  /// The read data from the CSR.
  Csr? get rdData => tryPort(config.name) as Csr?;

  /// Write the CSR in this cycle.
  Logic? get wrEn => tryPort('${config.name}_wrEn');

  /// Data to write to the CSR in this cycle.
  Logic? get wrData => tryPort('${config.name}_wrData');

  /// Constructs a new interface of specified [dataWidth]
  /// and conditionally instantiates read and writes ports based on
  /// [hasRead] and [hasWrite].
  CsrBackdoorInterface(
      {required this.config,
      this.dataWidth = 0,
      this.hasRead = true,
      this.hasWrite = true}) {
    if (hasRead) {
      setPorts([
        Csr(config),
      ], [
        CsrBackdoorPortGroup.read,
      ]);
    }

    if (hasWrite) {
      setPorts([
        Port('${config.name}_wrEn'),
        Port('${config.name}_wrData', dataWidth),
      ], [
        CsrBackdoorPortGroup.write,
      ]);
    }
  }

  /// Makes a copy of this [Interface] with matching configuration.
  CsrBackdoorInterface clone() => CsrBackdoorInterface(
      config: config,
      dataWidth: dataWidth,
      hasRead: hasRead,
      hasWrite: hasWrite);
}

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
class CsrBlock extends Module {
  /// Configuration for the CSR block.
  final CsrBlockConfig config;

  /// CSRs in this block.
  final List<Csr> csrs;

  /// Direct access ports for reading and writing individual registers.
  ///
  /// There is a public copy that is exported out of the module
  /// for consumption at higher levels in the hierarchy.
  /// The private copies are used for internal logic.
  final List<CsrBackdoorInterface> backdoorInterfaces = [];
  final List<CsrBackdoorInterface> _backdoorInterfaces = [];

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

    for (var i = 0; i < csrs.length; i++) {
      // TODO: pull hasRead and hasWrite from config??
      _backdoorInterfaces.add(CsrBackdoorInterface(
          config: csrs[i].config, dataWidth: fdr.dataWidth));
      backdoorInterfaces.add(CsrBackdoorInterface(
          config: csrs[i].config, dataWidth: fdr.dataWidth));
      _backdoorInterfaces.last.connectIO(this, backdoorInterfaces.last,
          outputTags: {CsrBackdoorPortGroup.read},
          inputTags: {CsrBackdoorPortGroup.write},
          uniquify: (original) =>
              '${name}_${csrs[i].config.name}_backdoor_$original');
    }

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

  /// Accessor to the backdoor ports of a particular register
  /// within the block by name [nm].
  CsrBackdoorInterface getBackdoorPortsByName(String nm) {
    final idx = config.registers.indexOf(config.getRegisterByName(nm));
    if (idx >= 0 && idx < backdoorInterfaces.length) {
      return backdoorInterfaces[idx];
    } else {
      throw Exception('Register $nm not found in block ${config.name}');
    }
  }

  /// Accessor to the backdoor ports of a particular register
  /// within the block by relative address [addr].
  CsrBackdoorInterface getBackdoorPortsByAddr(int addr) {
    final idx = config.registers.indexOf(config.getRegisterByAddr(addr));
    if (idx >= 0 && idx < backdoorInterfaces.length) {
      return backdoorInterfaces[idx];
    } else {
      throw Exception(
          'Register address $addr not found in block ${config.name}');
    }
  }

  void _buildLogic() {
    final addrWidth = _frontWrite.addrWidth;

    // individual CSR write logic
    for (var i = 0; i < csrs.length; i++) {
      Sequential(
        _clk,
        reset: _reset,
        resetValues: {
          csrs[i]: csrs[i].resetValue,
        },
        [
          If.block([
            // frontdoor write takes highest priority
            Iff(
                _frontWrite.en &
                    _frontWrite.addr.eq(Const(csrs[i].addr, width: addrWidth)),
                [
                  csrs[i] < csrs[i].getWriteData(_frontWrite.data),
                ]),
            // backdoor write takes next priority
            if (_backdoorInterfaces[i].hasWrite)
              ElseIf(_backdoorInterfaces[i].wrEn!, [
                csrs[i] < csrs[i].getWriteData(_backdoorInterfaces[i].wrData!),
              ]),
            // nothing to write this cycle
            Else([
              csrs[i] < csrs[i],
            ]),
          ])
        ],
      );
    }

    // individual CSR read logic
    final rdData = Logic(name: 'internalRdData', width: _frontRead.dataWidth);
    final rdCases = csrs
        .map((csr) => CaseItem(Const(csr.addr, width: addrWidth), [
              rdData < csr,
            ]))
        .toList();
    Combinational([
      Case(
          _frontRead.addr,
          conditionalType: ConditionalType.unique,
          rdCases,
          defaultItem: [
            rdData < Const(0, width: _frontRead.dataWidth),
          ]),
    ]);
    _frontRead.data <= rdData;

    // driving of backdoor read outputs
    for (var i = 0; i < csrs.length; i++) {
      if (_backdoorInterfaces[i].hasRead) {
        _backdoorInterfaces[i].rdData! <= csrs[i];
      }
    }
  }
}

/// Top level module encapsulating groups of CSRs.
///
/// This top module can include arbitrarily many CSR blocks.
/// Individual blocks are addressable using some number of
/// MSBs of the incoming address and registers within the given block
/// are addressable using the remaining LSBs of the incoming address.
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

  /// Direct access ports for reading and writing individual registers.
  ///
  /// There is a public copy that is exported out of the module
  /// for consumption at higher levels in the hierarchy.
  /// The private copies are used for internal logic.
  final List<List<CsrBackdoorInterface>> backdoorInterfaces = [];
  final List<List<CsrBackdoorInterface>> _backdoorInterfaces = [];

  /// Getter for the block configurations of the CSR.
  List<CsrBlockConfig> get blocks => config.blocks;

  /// Accessor to the backdoor ports of a particular register [reg]
  /// within the block [block].
  CsrBackdoorInterface getBackdoorPortsByName(String block, String reg) {
    final idx = config.blocks.indexOf(config.getBlockByName(block));
    if (idx >= 0 && idx < backdoorInterfaces.length) {
      return _blocks[idx].getBackdoorPortsByName(reg);
    } else {
      throw Exception('Block $block could not be found.');
    }
  }

  /// Accessor to the backdoor ports of a particular register
  /// using its address [regAddr] within the block with address [blockAddr].
  CsrBackdoorInterface getBackdoorPortsByAddr(int blockAddr, int regAddr) {
    final idx = config.blocks.indexOf(config.getBlockByAddr(blockAddr));
    if (idx >= 0 && idx < backdoorInterfaces.length) {
      return _blocks[idx].getBackdoorPortsByAddr(regAddr);
    } else {
      throw Exception('Block with address $blockAddr could not be found.');
    }
  }

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

    for (var i = 0; i < blocks.length; i++) {
      _backdoorInterfaces.add([]);
      backdoorInterfaces.add([]);
      for (var j = 0; j < blocks[i].registers.length; j++) {
        // TODO: pull hasRead and hasWrite from config??
        _backdoorInterfaces[i].add(CsrBackdoorInterface(
            config: blocks[i].registers[j], dataWidth: fdr.dataWidth));
        backdoorInterfaces[i].add(CsrBackdoorInterface(
            config: blocks[i].registers[j], dataWidth: fdr.dataWidth));
        _backdoorInterfaces[i].last.connectIO(this, backdoorInterfaces[i].last,
            outputTags: {CsrBackdoorPortGroup.read},
            inputTags: {CsrBackdoorPortGroup.write},
            uniquify: (original) =>
                '${name}_${blocks[i].name}_${blocks[i].registers[j].name}_backdoor_$original');
      }
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

      // drive backdoor write ports
      for (var j = 0; j < blocks[i].registers.length; j++) {
        if (_backdoorInterfaces[i][j].hasWrite) {
          _blocks[i].backdoorInterfaces[j].wrEn! <=
              _backdoorInterfaces[i][j].wrEn!;
          _blocks[i].backdoorInterfaces[j].wrData! <=
              _backdoorInterfaces[i][j].wrData!;
        }
      }
    }

    // capture frontdoor read output
    final rdData = Logic(name: 'internalRdData', width: _frontRead.dataWidth);
    final rdCases = _blocks
        .asMap()
        .entries
        .map(
            (block) => CaseItem(Const(block.value.baseAddr, width: addrWidth), [
                  rdData < _fdReads[block.key].data,
                ]))
        .toList();
    Combinational([
      Case(
          maskedFrontRdAddr,
          conditionalType: ConditionalType.unique,
          rdCases,
          defaultItem: [
            rdData < Const(0, width: _frontRead.dataWidth),
          ]),
    ]);
    _frontRead.data <= rdData;

    // driving of backdoor read outputs
    for (var i = 0; i < blocks.length; i++) {
      for (var j = 0; j < blocks[i].registers.length; j++) {
        if (_backdoorInterfaces[i][j].hasRead) {
          _backdoorInterfaces[i][j].rdData! <=
              _blocks[i].backdoorInterfaces[j].rdData!;
        }
      }
    }
  }
}
