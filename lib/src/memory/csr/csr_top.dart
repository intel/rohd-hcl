// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_top.dart
// A flexible definition of CSRs.
//
// 2024 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Top level module encapsulating groups of CSRs.
///
/// This top module can include arbitrarily many CSR blocks.
/// Individual blocks are addressable using some number of
/// MSBs of the incoming address and registers within the given block
/// are addressable using the remaining LSBs of the incoming address.
class CsrTop extends Module {
  // private config object
  final CsrTopConfig _config;

  /// Is it legal for the largest register width to be
  /// greater than the data width of the frontdoor interfaces.
  ///
  /// If this is true, HW generation must assign multiple addresses
  /// to any register that exceeds the data width of the frontdoor.
  final bool allowLargerRegisters;

  /// What increment value to use when deriving logical addresses
  /// for registers that are wider than the frontdoor data width.
  final int logicalRegisterIncrement;

  /// Configuration for the CSR Top module.
  CsrTopConfig get config => _config.clone();

  /// List of CSR blocks in this module.
  final List<CsrBlock> _blocks = [];

  /// Clock for the module.
  late final Logic _clk;

  /// Reset for the module.
  late final Logic _reset;

  /// Interface for frontdoor writes to CSRs.
  late final DataPortInterface? _frontWrite;

  /// Interface for frontdoor reads to CSRs.
  late final DataPortInterface? _frontRead;

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
  final List<Map<int, int>> _backdoorIndexMaps = [];

  /// Getter for the block offset width.
  int get blockOffsetWidth => config.blockOffsetWidth;

  /// Getter for the block configurations of the CSR.
  List<CsrBlockConfig> get blocks => config.blocks;

  /// Accessor to the backdoor ports of a particular register [reg]
  /// within the block [block].
  CsrBackdoorInterface getBackdoorPortsByName(String block, String reg) {
    final idx = _config.blocks.indexOf(_config.getBlockByName(block));
    if (idx >= 0 && idx < backdoorInterfaces.length) {
      final idx1 = _config.blocks[idx].registers
          .indexOf(_config.blocks[idx].getRegisterByName(reg));
      if (_backdoorIndexMaps[idx].containsKey(idx1)) {
        return backdoorInterfaces[idx][_backdoorIndexMaps[idx][idx1]!];
      } else {
        throw Exception('Register $reg in block $block could not be found.');
      }
    } else {
      throw Exception('Block $block could not be found.');
    }
  }

  /// Accessor to the backdoor ports of a particular register
  /// using its address [regAddr] within the block with address [blockAddr].
  CsrBackdoorInterface getBackdoorPortsByAddr(int blockAddr, int regAddr) {
    final idx = _config.blocks.indexOf(_config.getBlockByAddr(blockAddr));
    if (idx >= 0 && idx < backdoorInterfaces.length) {
      final idx1 = _config.blocks[idx].registers
          .indexOf(_config.blocks[idx].getRegisterByAddr(regAddr));
      if (_backdoorIndexMaps[idx].containsKey(idx1)) {
        return backdoorInterfaces[idx][_backdoorIndexMaps[idx][idx1]!];
      } else {
        throw Exception('Register with address $regAddr in block with '
            'address $blockAddr could not be found.');
      }
    } else {
      throw Exception('Block with address $blockAddr could not be found.');
    }
  }

  /// create the CsrBlock from a configuration
  factory CsrTop(
    CsrTopConfig config,
    Logic clk,
    Logic reset, {
    DataPortInterface? frontWrite,
    DataPortInterface? frontRead,
    bool allowLargerRegisters = false,
    int logicalRegisterIncrement = 1,
  }) =>
      CsrTop._(
        config: config,
        clk: clk,
        reset: reset,
        frontWrite: frontWrite,
        frontRead: frontRead,
        allowLargerRegisters: allowLargerRegisters,
        logicalRegisterIncrement: logicalRegisterIncrement,
      );

  CsrTop._({
    required CsrTopConfig config,
    required Logic clk,
    required Logic reset,
    required DataPortInterface? frontWrite,
    required DataPortInterface? frontRead,
    this.allowLargerRegisters = false,
    this.logicalRegisterIncrement = 1,
  })  : _config = config.clone(),
        super(name: config.name) {
    _config.validate();

    _clk = addInput('clk', clk);
    _reset = addInput('reset', reset);

    _frontWrite = frontWrite == null
        ? null
        : (frontWrite.clone()
          ..connectIO(this, frontWrite,
              inputTags: {DataPortGroup.control, DataPortGroup.data},
              outputTags: {},
              uniquify: (original) => 'frontWrite_$original'));
    _frontRead = frontRead == null
        ? null
        : (frontRead.clone()
          ..connectIO(this, frontRead,
              inputTags: {DataPortGroup.control},
              outputTags: {DataPortGroup.data},
              uniquify: (original) => 'frontRead_$original'));

    _validate();

    for (final block in _config.blocks) {
      _fdWrites.add(DataPortInterface(frontWrite.dataWidth, blockOffsetWidth));
      _fdReads.add(DataPortInterface(frontRead.dataWidth, blockOffsetWidth));
      _blocks.add(CsrBlock(block, _clk, _reset, _fdWrites.last, _fdReads.last,
          allowLargerRegisters: allowLargerRegisters));
    }

    for (var i = 0; i < blocks.length; i++) {
      _backdoorInterfaces.add([]);
      backdoorInterfaces.add([]);
      _backdoorIndexMaps.add({});
      for (var j = 0; j < blocks[i].registers.length; j++) {
        if (blocks[i].registers[j].backdoorAccessible) {
          _backdoorInterfaces[i]
              .add(CsrBackdoorInterface(config: blocks[i].registers[j]));
          backdoorInterfaces[i]
              .add(CsrBackdoorInterface(config: blocks[i].registers[j]));
          _backdoorInterfaces[i].last.connectIO(
              this, backdoorInterfaces[i].last,
              outputTags: {CsrBackdoorPortGroup.read},
              inputTags: {CsrBackdoorPortGroup.write},
              uniquify: (original) =>
                  '${name}_${blocks[i].name}_${blocks[i].registers[j].name}'
                  '_backdoor_$original');
          _backdoorIndexMaps[i][j] = _backdoorInterfaces[i].length - 1;
        }
      }
    }

    _buildLogic();
  }

  /// Accessor to the config of a particular register block
  /// within the module by name [name].
  CsrBlockConfig getBlockByName(String name) => config.getBlockByName(name);

  /// Accessor to the config of a particular register block
  /// within the module by relative address [addr].
  CsrBlockConfig getBlockByAddr(int addr) => config.getBlockByAddr(addr);

  // validate the frontdoor interface widths to ensure that they are wide enough
  void _validate() {
    // data width must be at least as wide as
    // the biggest register across all blocks
    // address width must be at least wide enough
    //to address all registers in all blocks
    if (_frontRead.dataWidth < _config.maxRegWidth() && !allowLargerRegisters) {
      throw CsrValidationException(
          'Frontdoor read interface data width must be '
          'at least ${_config.maxRegWidth()}.');
    }
    if (_frontWrite.dataWidth < _config.maxRegWidth() &&
        !allowLargerRegisters) {
      throw CsrValidationException(
          'Frontdoor write interface data width must be '
          'at least ${_config.maxRegWidth()}.');
    }
    if (_frontRead.addrWidth < _config.minAddrBits() ||
        _frontRead.addrWidth < blockOffsetWidth) {
      throw CsrValidationException(
          'Frontdoor read interface address width must be '
          'at least ${max(_config.minAddrBits(), blockOffsetWidth)}.');
    }
    if (_frontWrite.addrWidth < _config.minAddrBits()) {
      throw CsrValidationException(
          'Frontdoor write interface address width must be '
          'at least ${max(_config.minAddrBits(), blockOffsetWidth)}.');
    }
  }

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
        if (_backdoorIndexMaps[i].containsKey(j) &&
            _backdoorInterfaces[i][_backdoorIndexMaps[i][j]!].hasWrite) {
          _blocks[i].backdoorInterfaces[_backdoorIndexMaps[i][j]!].wrEn! <=
              _backdoorInterfaces[i][_backdoorIndexMaps[i][j]!].wrEn!;
          _blocks[i].backdoorInterfaces[_backdoorIndexMaps[i][j]!].wrData! <=
              _backdoorInterfaces[i][_backdoorIndexMaps[i][j]!].wrData!;
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
        if (_backdoorIndexMaps[i].containsKey(j) &&
            _backdoorInterfaces[i][_backdoorIndexMaps[i][j]!].hasRead) {
          _backdoorInterfaces[i][_backdoorIndexMaps[i][j]!].rdData! <=
              _blocks[i].backdoorInterfaces[_backdoorIndexMaps[i][j]!].rdData!;
        }
      }
    }
  }
}
