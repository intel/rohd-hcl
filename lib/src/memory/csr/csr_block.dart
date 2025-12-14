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

/// [Logic] representation of a block of registers.
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

  /// Constructor for a CSR block.
  CsrBlock({
    required CsrBlockConfig super.config,
    required super.clk,
    required super.reset,
    required super.frontWrite,
    required super.frontRead,
    super.allowLargerRegisters,
    this.logicalRegisterIncrement = 1,
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  })  : csrs = List.unmodifiable(config.registers.map(Csr.new)),
        super(
            definitionName: definitionName ?? 'CsrBlock_${config.name}_block') {
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
    final wrHits = <Logic>[];
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
          wrHits.add(addrCheck);

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
          wrHits.add(addrCheck);
          dataToWrite = csrs[i]
              .getWriteData(frontWrite!.data.getRange(0, csrs[i].config.width));
        }
      }

      final seqConditions = [
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
      ];

      Sequential(
        clk,
        reset: reset,
        resetValues: {
          csrs[i]: csrs[i].resetValue,
        },
        [
          if (seqConditions.isNotEmpty)
            If.block([
              ...seqConditions,
              // nothing to write this cycle
              Else([
                csrs[i] < csrs[i],
              ]),
            ])
          else
            csrs[i] < csrs[i],
        ],
      );
    }

    if (frontWritePresent) {
      final wrHit = wrHits.isEmpty ? Const(0) : wrHits.swizzle().or();

      frontWrite!.done <= frontWrite!.en;
      frontWrite!.valid <= frontWrite!.en & wrHit;
    }

    if (frontReadPresent) {
      final dataWidth = frontRead!.dataWidth;

      // individual CSR read logic
      final rdData = Logic(name: 'internalRdData', width: frontRead!.dataWidth);
      final rdValid = Logic(name: 'internalRdValid');
      final rdDone = Logic(name: 'internalRdDone');
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
                    rdValid < Const(1),
                    rdDone < Const(1),
                  ]));
            }
          } else {
            // normal capture of the register data
            rdCases.add(CaseItem(Const(csr.addr, width: addrWidth), [
              rdData < csr.zeroExtend(frontRead!.dataWidth),
              rdValid < Const(1),
              rdDone < Const(1),
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
              rdValid < Const(0),
              rdDone < Const(1),
            ]),
      ]);
      frontRead!.data <= rdData;
      frontRead!.valid <= rdValid;
      frontRead!.done <= rdDone;
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
