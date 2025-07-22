// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_top.dart
// A flexible definition of CSRs.
//
// 2024 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/memory/csr/csr_container.dart';

/// Top level module encapsulating groups of CSRs.
///
/// This top module can include arbitrarily many CSR blocks.
/// Individual blocks are addressable using some number of
/// MSBs of the incoming address and registers within the given block
/// are addressable using the remaining LSBs of the incoming address.
class CsrTop extends CsrContainer {
  /// What increment value to use when deriving logical addresses
  /// for registers that are wider than the frontdoor data width.
  final int logicalRegisterIncrement;

  /// Configuration for the CSR Top module.
  @override
  CsrTopConfig get config => super.config as CsrTopConfig;

  /// List of CSR blocks in this module.
  final List<CsrBlock> _blocks = [];

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
    final idx = config.blocks.indexOf(config.getBlockByName(block));
    if (idx >= 0 && idx < backdoorInterfaces.length) {
      final idx1 = config.blocks[idx].registers
          .indexOf(config.blocks[idx].getRegisterByName(reg));
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
    final idx = config.blocks.indexOf(config.getBlockByAddr(blockAddr));
    if (idx >= 0 && idx < backdoorInterfaces.length) {
      final idx1 = config.blocks[idx].registers
          .indexOf(config.blocks[idx].getRegisterByAddr(regAddr));
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

  /// Create the CsrBlock from a configuration
  CsrTop(
      {required CsrTopConfig super.config,
      required super.clk,
      required super.reset,
      required super.frontWrite,
      required super.frontRead,
      super.allowLargerRegisters,
      this.logicalRegisterIncrement = 1,
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'CsrTop_A${config.minAddrBits()}_'
                    'W${config.maxRegWidth()}_'
                    'BO${config.blockOffsetWidth}_'
                    'LR${allowLargerRegisters}_'
                    'RI$logicalRegisterIncrement') {
    _validate();

    for (final block in config.blocks) {
      DataPortInterface? blockFdWrite;
      DataPortInterface? blockFdRead;

      if (frontWritePresent) {
        blockFdWrite =
            DataPortInterface(frontWrite!.dataWidth, blockOffsetWidth);
        _fdWrites.add(blockFdWrite);
      }

      if (frontReadPresent) {
        blockFdRead = DataPortInterface(frontRead!.dataWidth, blockOffsetWidth);
        _fdReads.add(blockFdRead);
      }

      _blocks.add(CsrBlock(
          config: block,
          clk: clk,
          reset: reset,
          frontWrite: blockFdWrite,
          frontRead: blockFdRead,
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
    // to address all registers in all blocks

    if (frontReadPresent) {
      if (frontRead!.addrWidth < blockOffsetWidth) {
        throw CsrValidationException(
            'Frontdoor read interface address width must be '
            'at least $blockOffsetWidth.');
      }
    }

    if (frontWritePresent) {
      if (frontWrite!.addrWidth < blockOffsetWidth) {
        throw CsrValidationException(
            'Frontdoor write interface address width must be '
            'at least $blockOffsetWidth.');
      }
    }
  }

  void _buildLogic() {
    if (frontWritePresent) {
      // mask out LSBs to perform a match on block
      final maskedFrontWrAddr = frontWrite!.addr &
          ~Const((1 << blockOffsetWidth) - 1, width: addrWidth);

      // shift out MSBs to pass the appropriate address into the blocks
      final shiftedFrontWrAddr = frontWrite!.addr.getRange(0, blockOffsetWidth);

      // drive frontdoor write and read inputs
      for (var i = 0; i < _blocks.length; i++) {
        _fdWrites[i].en <=
            frontWrite!.en &
                maskedFrontWrAddr
                    .eq(Const(_blocks[i].baseAddr, width: addrWidth));

        _fdWrites[i].addr <= shiftedFrontWrAddr;
        _fdWrites[i].data <= frontWrite!.data;
      }
    }

    if (frontReadPresent) {
      // mask out LSBs to perform a match on block
      final maskedFrontRdAddr = frontRead!.addr &
          ~Const((1 << blockOffsetWidth) - 1, width: addrWidth);

      // shift out MSBs to pass the appropriate address into the blocks
      final shiftedFrontRdAddr = frontRead!.addr.getRange(0, blockOffsetWidth);

      // drive frontdoor write and read inputs
      for (var i = 0; i < _blocks.length; i++) {
        _fdReads[i].en <=
            frontRead!.en &
                maskedFrontRdAddr
                    .eq(Const(_blocks[i].baseAddr, width: addrWidth));

        _fdReads[i].addr <= shiftedFrontRdAddr;
      }

      // capture frontdoor read output
      final rdData = Logic(name: 'internalRdData', width: frontRead!.dataWidth);
      final rdCases = _blocks
          .asMap()
          .entries
          .map((block) =>
              CaseItem(Const(block.value.baseAddr, width: addrWidth), [
                rdData < _fdReads[block.key].data,
              ]))
          .toList();
      Combinational([
        Case(
            maskedFrontRdAddr,
            conditionalType: ConditionalType.unique,
            rdCases,
            defaultItem: [
              rdData < Const(0, width: frontRead!.dataWidth),
            ]),
      ]);
      frontRead!.data <= rdData;
    }

    for (var i = 0; i < _blocks.length; i++) {
      for (var j = 0; j < blocks[i].registers.length; j++) {
        // drive backdoor write ports
        if (_backdoorIndexMaps[i].containsKey(j) &&
            _backdoorInterfaces[i][_backdoorIndexMaps[i][j]!].hasWrite) {
          _blocks[i].backdoorInterfaces[_backdoorIndexMaps[i][j]!].wrEn! <=
              _backdoorInterfaces[i][_backdoorIndexMaps[i][j]!].wrEn!;
          _blocks[i].backdoorInterfaces[_backdoorIndexMaps[i][j]!].wrData! <=
              _backdoorInterfaces[i][_backdoorIndexMaps[i][j]!].wrData!;
        }

        // driving of backdoor read outputs
        if (_backdoorIndexMaps[i].containsKey(j) &&
            _backdoorInterfaces[i][_backdoorIndexMaps[i][j]!].hasRead) {
          _backdoorInterfaces[i][_backdoorIndexMaps[i][j]!].rdData! <=
              _blocks[i].backdoorInterfaces[_backdoorIndexMaps[i][j]!].rdData!;
        }
      }
    }
  }
}
