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
import 'package:rohd_hcl/src/memory/csr/csr_container.dart';

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
  // private config object
  final CsrInstanceConfig _config;

  /// Configuration for the associated CSR.
  CsrInstanceConfig get config => _config.clone();

  /// Should this CSR be readable by the HW.
  final bool hasRead;

  /// Should this CSR be writable by the HW.
  final bool hasWrite;

  /// The width of data in the CSR.
  final int dataWidth;

  /// The read data from the CSR.
  Csr? get rdData => tryPort(_config.name) as Csr?;

  /// Write the CSR in this cycle.
  Logic? get wrEn => tryPort('${_config.name}_wrEn');

  /// Data to write to the CSR in this cycle.
  Logic? get wrData => tryPort('${_config.name}_wrData');

  /// Constructs a new interface of specified [dataWidth]
  /// and conditionally instantiates read and writes ports based on
  /// [hasRead] and [hasWrite].
  CsrBackdoorInterface({
    required CsrInstanceConfig config,
  })  : _config = config.clone(),
        dataWidth = config.width,
        hasRead = config.isBackdoorReadable,
        hasWrite = config.isBackdoorWritable {
    if (hasRead) {
      setPorts([
        Csr(_config),
      ], [
        CsrBackdoorPortGroup.read,
      ]);
    }

    if (hasWrite) {
      setPorts([
        Port('${_config.name}_wrEn'),
        Port('${_config.name}_wrData', dataWidth),
      ], [
        CsrBackdoorPortGroup.write,
      ]);
    }
  }

  /// Makes a copy of this [Interface] with matching configuration.
  CsrBackdoorInterface clone() => CsrBackdoorInterface(config: _config.clone());
}

/// Logic representation of a block of registers.
///
/// A block is just a collection of registers that are
/// readable and writable through an addressing scheme
/// that is relative (offset from) the base address of the block.
class CsrBlock extends CsrContainer {
  /// Configuration for the CSR block.
  @override
  CsrBlockConfig get config => super.config as CsrBlockConfig;

  /// CSRs in this block.
  final List<Csr> csrs;

  /// Is it legal for the largest register width to be
  /// greater than the data width of the frontdoor interfaces.
  ///
  /// If this is true, HW generation must assign multiple addresses
  /// to any register that exceeds the data width of the frontdoor.
  final bool allowLargerRegisters;

  /// What increment value to use when deriving logical addresses
  /// for registers that are wider than the frontdoor data width.
  final int logicalRegisterIncrement;

  /// Direct access ports for reading and writing individual registers.
  ///
  /// There is a public copy that is exported out of the module
  /// for consumption at higher levels in the hierarchy.
  /// The private copies are used for internal logic.
  final List<CsrBackdoorInterface> backdoorInterfaces = [];
  final List<CsrBackdoorInterface> _backdoorInterfaces = [];
  final Map<int, int> _backdoorIndexMap = {};

  /// Getter for block's base address
  int get baseAddr => config.baseAddr;

  /// Getter for the CSR configurations.
  List<CsrInstanceConfig> get registers => config.registers;

  /// Create the CsrBlock from a configuration.
  factory CsrBlock(
    CsrBlockConfig config,
    Logic clk,
    Logic reset, {
    DataPortInterface? frontWrite,
    DataPortInterface? frontRead,
    bool allowLargerRegisters = false,
    int logicalRegisterIncrement = 1,
  }) {
    if (frontWrite == null && frontRead == null) {
      throw CsrValidationException(
          'At least one of `frontWrite` or `frontRead` must be provided.');
    }

    final csrs = <Csr>[];
    for (final reg in config.registers) {
      csrs.add(Csr(reg));
    }
    return CsrBlock._(
      config: config,
      csrs: csrs,
      clk: clk,
      reset: reset,
      frontWrite: frontWrite,
      frontRead: frontRead,
      allowLargerRegisters: allowLargerRegisters,
      logicalRegisterIncrement: logicalRegisterIncrement,
    );
  }

  /// Constructor for a CSR block.
  CsrBlock._({
    required CsrBlockConfig super.config,
    required this.csrs,
    required super.clk,
    required super.reset,
    required super.frontWrite,
    required super.frontRead,
    this.allowLargerRegisters = false,
    this.logicalRegisterIncrement = 1,
  }) {
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
    if (frontRead != null && frontRead!.dataWidth < config.maxRegWidth()) {
      if (allowLargerRegisters) {
        // must check for collisions in logical register addresses
        final regCheck = <int>[];
        for (final csr in csrs) {
          if (csr.config.width > frontRead!.dataWidth) {
            final targ = (csr.width / frontRead!.dataWidth).ceil();

            for (var j = 0; j < targ; j++) {
              regCheck.add(csr.addr + j * logicalRegisterIncrement);
            }
          } else {
            regCheck.add(csr.addr);
          }
        }
        if (regCheck.length != regCheck.toSet().length) {
          throw CsrValidationException(
              'There is at least one collision across logical register '
              'addresses due to some registers being wider than the '
              'frontdoor data width. Note that each logical address '
              'has a +$logicalRegisterIncrement increment to '
              'the original address.');
        }
      }
    }
  }

  void _buildLogic() {
    // individual CSR write logic
    for (var i = 0; i < csrs.length; i++) {
      // this block of code mostly handles the case where
      // the register is wider than the data width of the frontdoor
      // which is only permissible if [allowLargerRegisters] is true.
      Logic? addrCheck;
      Logic? dataToWrite;
      if (frontWritePresent) {
        final dataWidth = frontWrite!.dataWidth;
        if (dataWidth < csrs[i].config.width) {
          final rem = csrs[i].config.width % dataWidth;
          final targ = (csrs[i].config.width / dataWidth).ceil();

          // must logically separate the register out across multiple addresses
          final addrs = List.generate(
              targ,
              (j) => Const(csrs[i].addr + j * logicalRegisterIncrement,
                  width: addrWidth));
          addrCheck = frontWrite!.addr.isIn(addrs);

          // we write the portion of the register that
          // corresponds to this logical address
          final wrCases = <Logic, Logic>{};
          for (var j = 0; j < targ; j++) {
            final key = Const(csrs[i].addr + j * logicalRegisterIncrement,
                width: addrWidth);
            if (j == targ - 1) {
              // might need to truncate the data on the interface
              // for the last chunk depending on divisibility
              wrCases[key] = csrs[i].withSet(
                  j * dataWidth,
                  csrs[i]
                      .getWriteData([
                        if (j * dataWidth > 0)
                          csrs[i].getRange(0, j * dataWidth),
                        frontWrite!.data.getRange(0, rem == 0 ? dataWidth : rem)
                      ].rswizzle())
                      .getRange(
                          j * dataWidth,
                          rem == 0
                              ? (j + 1) * dataWidth
                              : j * dataWidth + rem));
            } else {
              // no truncation needed
              wrCases[key] = csrs[i].withSet(
                  j * dataWidth,
                  csrs[i]
                      .getWriteData([
                        if (j * dataWidth > 0)
                          csrs[i].getRange(0, j * dataWidth),
                        frontWrite!.data,
                        if ((j + 1) * dataWidth < csrs[i].config.width)
                          csrs[i].getRange((j + 1) * dataWidth),
                      ].rswizzle())
                      .getRange(j * dataWidth, (j + 1) * dataWidth));
            }
          }
          dataToWrite = cases(
              frontWrite!.addr,
              conditionalType: ConditionalType.unique,
              wrCases,
              defaultValue: csrs[i]);
        } else {
          // direct address check
          // direct application of write data
          addrCheck =
              frontWrite!.addr.eq(Const(csrs[i].addr, width: addrWidth));
          dataToWrite = csrs[i]
              .getWriteData(frontWrite!.data.getRange(0, csrs[i].config.width));
        }
      }

      Sequential(
        clk,
        reset: reset,
        resetValues: {
          csrs[i]: csrs[i].resetValue,
        },
        [
          If.block([
            // frontdoor write takes highest priority
            if (frontWritePresent && config.registers[i].isFrontdoorWritable)
              ElseIf(frontWrite!.en & addrCheck!, [
                csrs[i] < dataToWrite,
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

    if (frontReadPresent) {
      final dataWidth = frontRead!.dataWidth;

      // individual CSR read logic
      final rdData = Logic(name: 'internalRdData', width: frontRead!.dataWidth);
      final rdCases = <CaseItem>[];
      for (final csr in csrs) {
        if (csr.isFrontdoorReadable) {
          if (dataWidth < csr.config.width) {
            final rem = csr.width % dataWidth;
            final targ = (csr.width / dataWidth).ceil();

            // must further examine logical registers
            // and capture the correct logical chunk
            for (var j = 0; j < targ; j++) {
              final rngEnd = j == targ - 1
                  ? rem == 0
                      ? frontRead!.dataWidth
                      : rem
                  : frontRead!.dataWidth;
              rdCases.add(CaseItem(
                  Const(csr.addr + j * logicalRegisterIncrement,
                      width: addrWidth),
                  [
                    rdData <
                        csr
                            .getRange(frontRead!.dataWidth * j,
                                frontRead!.dataWidth * j + rngEnd)
                            .zeroExtend(frontRead!.dataWidth),
                  ]));
            }
          } else {
            // normal capture of the register data
            rdCases.add(CaseItem(Const(csr.addr, width: addrWidth), [
              rdData < csr.zeroExtend(frontRead!.dataWidth),
            ]));
          }
        }
      }

      Combinational([
        Case(
            frontRead!.addr,
            conditionalType: ConditionalType.unique,
            rdCases,
            defaultItem: [
              rdData < Const(0, width: frontRead!.dataWidth),
            ]),
      ]);
      frontRead!.data <= rdData;
    }

    // driving of backdoor read outputs
    for (var i = 0; i < csrs.length; i++) {
      if (_backdoorIndexMap.containsKey(i) &&
          _backdoorInterfaces[_backdoorIndexMap[i]!].hasRead) {
        _backdoorInterfaces[_backdoorIndexMap[i]!].rdData! <= csrs[i];
      }
    }
  }
}
