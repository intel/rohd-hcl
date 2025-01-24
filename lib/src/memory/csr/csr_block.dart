// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_block.dart
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
  CsrBackdoorInterface({
    required this.config,
  })  : dataWidth = config.width,
        hasRead = config.isBackdoorReadable,
        hasWrite = config.isBackdoorWritable {
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
  CsrBackdoorInterface clone() => CsrBackdoorInterface(config: config);
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
  final Map<int, int> _backdoorIndexMap = {};

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

  /// Constructor for a CSR block.
  CsrBlock._({
    required this.config,
    required this.csrs,
    required Logic clk,
    required Logic reset,
    required DataPortInterface fdw,
    required DataPortInterface fdr,
  }) : super(name: config.name) {
    config.validate();

    _clk = addInput('${name}_clk', clk);
    _reset = addInput('${name}_reset', reset);

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

    _validate();

    for (var i = 0; i < csrs.length; i++) {
      if (csrs[i].config.backdoorAccessible) {
        _backdoorInterfaces.add(CsrBackdoorInterface(config: csrs[i].config));
        backdoorInterfaces.add(CsrBackdoorInterface(config: csrs[i].config));
        _backdoorInterfaces.last.connectIO(this, backdoorInterfaces.last,
            outputTags: {CsrBackdoorPortGroup.read},
            inputTags: {CsrBackdoorPortGroup.write},
            uniquify: (original) =>
                '${name}_${csrs[i].config.name}_backdoor_$original');
        _backdoorIndexMap[i] = _backdoorInterfaces.length - 1;
      }
    }

    _buildLogic();
  }

  /// Accessor to the config of a particular register
  /// within the block by name [name].
  CsrInstanceConfig getRegisterByName(String name) =>
      config.getRegisterByName(name);

  /// Accessor to the config of a particular register
  /// within the block by relative address [addr].
  CsrInstanceConfig getRegisterByAddr(int addr) =>
      config.getRegisterByAddr(addr);

  /// Accessor to the backdoor ports of a particular register
  /// within the block by name [name].
  CsrBackdoorInterface getBackdoorPortsByName(String name) {
    final idx = config.registers.indexOf(config.getRegisterByName(name));
    if (_backdoorIndexMap.containsKey(idx)) {
      return backdoorInterfaces[_backdoorIndexMap[idx]!];
    } else {
      throw Exception('Register $name not found in block ${config.name}');
    }
  }

  /// Accessor to the backdoor ports of a particular register
  /// within the block by relative address [addr].
  CsrBackdoorInterface getBackdoorPortsByAddr(int addr) {
    final idx = config.registers.indexOf(config.getRegisterByAddr(addr));
    if (_backdoorIndexMap.containsKey(idx)) {
      return backdoorInterfaces[_backdoorIndexMap[idx]!];
    } else {
      throw Exception(
          'Register address $addr not found in block ${config.name}');
    }
  }

  // validate the frontdoor interface widths to ensure that they are wide enough
  void _validate() {
    // check frontdoor interfaces
    // data width must be at least as wide as the biggest register in the block
    // address width must be at least wide enough
    // to address all registers in the block
    if (_frontRead.dataWidth < config.maxRegWidth()) {
      throw CsrValidationException(
          'Frontdoor read interface data width must be '
          'at least ${config.maxRegWidth()}.');
    }
    if (_frontWrite.dataWidth < config.maxRegWidth()) {
      throw CsrValidationException(
          'Frontdoor write interface data width must be '
          'at least ${config.maxRegWidth()}.');
    }
    if (_frontRead.addrWidth < config.minAddrBits()) {
      throw CsrValidationException(
          'Frontdoor read interface address width must be '
          'at least ${config.minAddrBits()}.');
    }
    if (_frontWrite.dataWidth < config.minAddrBits()) {
      throw CsrValidationException(
          'Frontdoor write interface address width must be '
          'at least ${config.minAddrBits()}.');
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
            if (config.registers[i].isFrontdoorWritable)
              ElseIf(
                  _frontWrite.en &
                      _frontWrite.addr
                          .eq(Const(csrs[i].addr, width: addrWidth)),
                  [
                    csrs[i] <
                        csrs[i].getWriteData(
                            _frontWrite.data.getRange(0, csrs[i].config.width)),
                  ]),
            // backdoor write takes next priority
            if (_backdoorIndexMap.containsKey(i) &&
                _backdoorInterfaces[_backdoorIndexMap[i]!].hasWrite)
              ElseIf(_backdoorInterfaces[_backdoorIndexMap[i]!].wrEn!, [
                csrs[i] <
                    csrs[i].getWriteData(
                        _backdoorInterfaces[_backdoorIndexMap[i]!].wrData!),
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
        .where((csr) => csr.isFrontdoorReadable)
        .map((csr) => CaseItem(Const(csr.addr, width: addrWidth), [
              rdData < csr.zeroExtend(_frontRead.dataWidth),
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
      if (_backdoorIndexMap.containsKey(i) &&
          _backdoorInterfaces[_backdoorIndexMap[i]!].hasRead) {
        _backdoorInterfaces[_backdoorIndexMap[i]!].rdData! <= csrs[i];
      }
    }
  }
}
