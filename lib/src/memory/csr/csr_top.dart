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
class CsrTop extends CsrContainer
    with SystemVerilog
    implements BehavioralModelProvider {
  /// Resolved construction policy. Existing callers default to RTL.
  late final CsrImplementationConfiguration implementationConfiguration;

  /// Whole-top software state, or `null` for the RTL implementation.
  CsrSoftwareModel? get softwareModel => _softwareModel;
  CsrSoftwareModel? _softwareModel;

  @override
  CsrSoftwareModel? get behavioralModel => _softwareModel;

  /// Exports the software implementation as a compact behavioral SystemC class.
  ///
  /// This explicit backend works on ROHD 0.6.11 without a SystemC synthesizer.
  /// Surrounding systems must bind this class at the CSR top boundary.
  ///
  /// [options] controls boundary types and unknown outputs independently of
  /// storage selection and CSR architectural configuration.
  String generateModelSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) {
    final model = _softwareModel;
    if (model == null) {
      throw StateError('Behavioral SystemC export requires software CSRs.');
    }
    return model.generateSystemC(
      className: className,
      options: options,
    );
  }

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

  /// Getter for the block size.
  int get blockSize => config.blockSize;

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
      CsrImplementationConfiguration? implementationConfiguration,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'CsrTop_A${config.minAddrBits()}_'
                    'W${config.maxRegWidth()}_'
                    'BS${config.blockSize}_'
                    'LR${allowLargerRegisters}_'
                    'RI$logicalRegisterIncrement') {
    _validate();
    this.implementationConfiguration =
        implementationConfiguration ?? CsrImplementationScope.current;
    if (this.implementationConfiguration.implementation ==
        CsrImplementation.software) {
      _buildSoftwareModel();
      return;
    }
    if (this.implementationConfiguration.hardwareRegisters != null) {
      throw ArgumentError(
          'Selective CSR hardware exposure requires software implementation.');
    }

    for (final block in config.blocks) {
      DataPortInterface? blockFdWrite;
      DataPortInterface? blockFdRead;

      final blockOffsetW = config.blockOffsetWidthForBlock(block);

      if (frontWritePresent) {
        blockFdWrite = DataPortInterface(frontWrite!.dataWidth, blockOffsetW);
        _fdWrites.add(blockFdWrite);
      }

      if (frontReadPresent) {
        blockFdRead = DataPortInterface(frontRead!.dataWidth, blockOffsetW);
        _fdReads.add(blockFdRead);
      }

      _blocks.add(CsrBlock(
          config: block,
          clk: clk,
          reset: reset,
          frontWrite: blockFdWrite,
          frontRead: blockFdRead,
          allowLargerRegisters: allowLargerRegisters,
          logicalRegisterIncrement: logicalRegisterIncrement,
          asyncReset: config.asyncReset));
    }

    for (var i = 0; i < blocks.length; i++) {
      _backdoorInterfaces.add([]);
      backdoorInterfaces.add([]);
      _backdoorIndexMaps.add({});
      for (var j = 0; j < blocks[i].registers.length; j++) {
        if (blocks[i].registers[j].backdoorAccessible) {
          backdoorInterfaces[i]
              .add(CsrBackdoorInterface(config: blocks[i].registers[j]));
          _backdoorInterfaces[i].add(addInterfacePorts(
              backdoorInterfaces[i].last,
              outputTags: {CsrBackdoorPortGroup.read},
              inputTags: {CsrBackdoorPortGroup.write},
              uniquify: (original) =>
                  '${name}_${blocks[i].name}_${blocks[i].registers[j].name}'
                  '_backdoor_$original'));
          _backdoorIndexMaps[i][j] = _backdoorInterfaces[i].length - 1;
        }
      }
    }

    _buildLogic();
  }

  void _buildSoftwareModel() {
    final selected = implementationConfiguration.hardwareRegisters;
    final remaining = selected == null ? <String>{} : Set<String>.of(selected);
    final hardware = <int, CsrBackdoorInterface>{};
    for (var i = 0; i < blocks.length; i++) {
      backdoorInterfaces.add([]);
      _backdoorInterfaces.add([]);
      _backdoorIndexMaps.add({});
      final block = blocks[i];
      for (var j = 0; j < block.registers.length; j++) {
        final register = block.registers[j];
        final key = '${block.name}/${register.name}';
        final expose = selected == null || selected.contains(key);
        if (!expose) {
          continue;
        }
        remaining.remove(key);
        if (!register.backdoorAccessible) {
          if (selected != null) {
            throw ArgumentError('CSR $key has no hardware backdoor access.');
          }
          continue;
        }
        final external = CsrBackdoorInterface(config: register);
        final internal = addInterfacePorts(external,
            outputTags: {CsrBackdoorPortGroup.read},
            inputTags: {CsrBackdoorPortGroup.write},
            uniquify: (original) =>
                '${name}_${block.name}_${register.name}_backdoor_$original');
        _backdoorIndexMaps[i][j] = backdoorInterfaces[i].length;
        backdoorInterfaces[i].add(external);
        _backdoorInterfaces[i].add(internal);
        hardware[block.baseAddr + register.addr] = internal;
      }
    }
    if (remaining.isNotEmpty) {
      throw ArgumentError('Unknown hardware CSR selection: $remaining.');
    }
    _softwareModel = CsrSoftwareModel(
      description: CsrModelDescription.fromConfig(
        config,
        instanceName: name,
        frontRead: frontRead == null
            ? null
            : MemoryPortGeometry(
                addressWidth: frontRead!.addrWidth,
                dataWidth: frontRead!.dataWidth),
        frontWrite: frontWrite == null
            ? null
            : MemoryPortGeometry(
                addressWidth: frontWrite!.addrWidth,
                dataWidth: frontWrite!.dataWidth),
        hardwareRegisters: selected,
        logicalRegisterIncrement: logicalRegisterIncrement,
        allowLargerRegisters: allowLargerRegisters,
      ),
      clk: clk,
      reset: reset,
      frontRead: frontRead,
      frontWrite: frontWrite,
      hardware: hardware,
    );
  }

  /// Software tops are custom leaves, not wire-only/default RTL definitions.
  ///
  /// Classify without invoking an unsupported Verilog exporter: other
  /// backends query this property when instantiating their parent hierarchy.
  @override
  DefinitionGenerationType get generatedDefinitionType => _softwareModel != null
      ? DefinitionGenerationType.custom
      : super.generatedDefinitionType;

  @override
  String? definitionVerilog(String definitionType) {
    if (implementationConfiguration.implementation ==
        CsrImplementation.software) {
      throw UnsupportedError('Software CSRs require a behavioral simulation '
          'backend; RTL export is not a software-model implementation.');
    }
    return null;
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

    // compute the maximum effective block offset width across all blocks
    final maxBlockOffsetWidth = config.blocks
        .map(config.blockOffsetWidthForBlock)
        .fold(0, (a, b) => a > b ? a : b);

    if (frontReadPresent) {
      if (frontRead!.addrWidth < maxBlockOffsetWidth) {
        throw CsrValidationException(
            'Frontdoor read interface address width must be '
            'at least $maxBlockOffsetWidth.');
      }
    }

    if (frontWritePresent) {
      if (frontWrite!.addrWidth < maxBlockOffsetWidth) {
        throw CsrValidationException(
            'Frontdoor write interface address width must be '
            'at least $maxBlockOffsetWidth.');
      }
    }
  }

  // true when addr falls within [block.baseAddr, block.baseAddr + blockSize).
  // compares at addrWidth + 1 bits so a block spanning the full address
  // space (baseAddr + blockSize == 1 << addrWidth) does not overflow hi.
  Logic _blockRangeMatch(Logic addr, CsrBlockConfig block) {
    final cmpWidth = addrWidth + 1;
    final addrExt = addr.zeroExtend(cmpWidth);
    final lo = Const(block.baseAddr, width: cmpWidth);
    final hi = Const(block.baseAddr + config.blockSizeForBlock(block),
        width: cmpWidth);
    return addrExt.gte(lo) & addrExt.lt(hi);
  }

  void _buildLogic() {
    if (frontWritePresent) {
      // drive frontdoor write inputs per block using each block's own range
      for (var i = 0; i < _blocks.length; i++) {
        final offsetWidth = config.blockOffsetWidthForBlock(config.blocks[i]);
        final baseAddr = Const(_blocks[i].baseAddr, width: addrWidth);

        // extract the in-block register address
        final shiftedFrontWrAddr =
            (frontWrite!.addr - baseAddr).getRange(0, offsetWidth);

        _fdWrites[i].en <=
            frontWrite!.en &
                _blockRangeMatch(frontWrite!.addr, config.blocks[i]);

        _fdWrites[i].addr <= shiftedFrontWrAddr;
        _fdWrites[i].data <= frontWrite!.data;
      }
    }

    if (frontReadPresent) {
      // per-block address match signals
      final blockReadMatches = List.generate(
          _blocks.length,
          (i) => _blockRangeMatch(frontRead!.addr, config.blocks[i])
              .named('inRangeFrontRdAddr_$i'));

      // drive frontdoor read enable and address per block
      for (var i = 0; i < _blocks.length; i++) {
        final offsetWidth = config.blockOffsetWidthForBlock(config.blocks[i]);
        final baseAddr = Const(_blocks[i].baseAddr, width: addrWidth);
        _fdReads[i].en <= frontRead!.en & blockReadMatches[i];
        _fdReads[i].addr <=
            (frontRead!.addr - baseAddr).getRange(0, offsetWidth);
      }

      // capture frontdoor read output via Iff/ElseIf/Else on per-block matches
      final rdData = Logic(name: 'internalRdData', width: frontRead!.dataWidth);
      Combinational([
        If.block([
          Iff(blockReadMatches[0], [rdData < _fdReads[0].data]),
          for (var i = 1; i < _blocks.length; i++)
            ElseIf(blockReadMatches[i], [rdData < _fdReads[i].data]),
          Else([rdData < Const(0, width: frontRead!.dataWidth)]),
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
