// Copyright (C) 2024-2026 Intel Corporation
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

  final BigInt? _addressExtent;

  /// Indicates whether the `reset` signal driving this block's registers
  /// should be treated as an asynchronous reset.
  ///
  /// If `true`, registers reset as soon as `reset` is asserted, independent
  /// of `clk`. If `false` (the default), `reset` is treated as synchronous
  /// and registers only reset on the next active edge of `clk`.
  bool get asyncReset => _asyncReset;
  final bool _asyncReset;

  /// Direct access ports for reading and writing individual registers.
  ///
  /// There is a public copy that is exported out of the module
  /// for consumption at higher levels in the hierarchy.
  /// The private copies are used for internal logic.
  final List<CsrBackdoorInterface> backdoorInterfaces = [];
  final List<CsrBackdoorInterface> _backdoorInterfaces = [];
  final Map<int, int> _backdoorIndexMap = {};

  /// Getter for block's base address
  BigInt get baseAddr => config.baseAddr;

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
    super.logicalRegisterIncrement,
    super.wideLogicalRegisterIncrement,
    BigInt? addressExtent,
    bool asyncReset = false,
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  })  : _asyncReset = asyncReset,
        _addressExtent = addressExtent,
        csrs = List.unmodifiable(config.registers.map(Csr.new)),
        super(
            definitionName: definitionName ?? 'CsrBlock_${config.name}_block') {
    _validate();

    for (var i = 0; i < csrs.length; i++) {
      if (csrs[i].config.backdoorAccessible) {
        backdoorInterfaces.add(CsrBackdoorInterface(config: csrs[i].config));
        _backdoorInterfaces.add(addInterfacePorts(backdoorInterfaces.last,
            outputTags: {CsrBackdoorPortGroup.read},
            inputTags: {CsrBackdoorPortGroup.write},
            uniquify: (original) =>
                '${name}_${csrs[i].config.name}_backdoor_$original'));
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

  /// Looks up a register by an arbitrary-width offset.
  CsrInstanceConfig getRegisterByBigIntAddr(BigInt addr) =>
      config.getRegisterByBigIntAddr(addr);

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
  CsrBackdoorInterface getBackdoorPortsByAddr(int addr) =>
      getBackdoorPortsByBigIntAddr(BigInt.from(addr));

  /// Looks up a backdoor by an arbitrary-width register offset.
  CsrBackdoorInterface getBackdoorPortsByBigIntAddr(BigInt addr) {
    final idx = config.registers.indexOf(config.getRegisterByBigIntAddr(addr));
    if (_backdoorIndexMap.containsKey(idx)) {
      return backdoorInterfaces[_backdoorIndexMap[idx]!];
    } else {
      throw Exception(
          'Register address $addr not found in block ${config.name}');
    }
  }

  // validate the frontdoor interface widths to ensure that they are wide enough
  void _validate() {
    if (logicalRegisterIncrement <= BigInt.zero) {
      throw CsrValidationException(
          'Logical register increment must be positive.');
    }
    for (final (port, isRead) in [(frontRead, true), (frontWrite, false)]) {
      if (port == null) {
        continue;
      }
      final used = <BigInt>{};
      final extent =
          _addressExtent ?? config.blockSize ?? (BigInt.one << port.addrWidth);
      for (final csr in csrs) {
        if (isRead
            ? !csr.isFrontdoorReadable
            : !csr.config.isFrontdoorWritable) {
          continue;
        }
        final count = (csr.width + port.dataWidth - 1) ~/ port.dataWidth;
        for (var chunk = 0; chunk < count; chunk++) {
          final address =
              csr.addr + BigInt.from(chunk) * logicalRegisterIncrement;
          if (address >= extent || address >= BigInt.one << port.addrWidth) {
            throw CsrValidationException(
                'Wide CSR exceeds its address geometry.');
          }
          if (!used.add(address)) {
            throw CsrValidationException(
                'Overlapping logical CSR address $address.');
          }
        }
      }
    }
  }

  void _buildLogic() {
    // per-CSR frontdoor write pulse used to drive backdoor reads of
    // writeOnly fields; null where the CSR has no writeOnly fields.
    final frontdoorWriteValidFulls = <Logic?>[];
    final frontdoorWriteDataFulls = <Logic?>[];

    // individual CSR write logic
    for (var i = 0; i < csrs.length; i++) {
      // this block of code mostly handles the case where
      // the register is wider than the data width of the frontdoor
      // which is only permissible if [allowLargerRegisters] is true.
      Logic? addrCheck;
      Csr? dataToWrite;
      final hasWriteOnlyField = csrs[i]
          .config
          .fields
          .any((field) => field.access == CsrFieldAccess.writeOnly);
      Logic? frontdoorWriteValidFull;
      Logic? frontdoorWriteDataFull;
      if (frontWritePresent) {
        final dataWidth = frontWrite!.dataWidth;
        final normalizedFrontWriteData =
            frontWrite!.data ^ Const(0, width: dataWidth);
        if (dataWidth < csrs[i].config.width) {
          final rem = csrs[i].config.width % dataWidth;
          final targ = (csrs[i].config.width / dataWidth).ceil();

          // must logically separate the register out across multiple addresses
          final addrs = List.generate(
              targ,
              (j) => Const(
                  csrs[i].addr + BigInt.from(j) * logicalRegisterIncrement,
                  width: addrWidth));
          addrCheck = frontWrite!.addr.isIn(addrs);

          // we write the portion of the register that
          // corresponds to this logical address
          final wrCases = <Logic, Csr>{};
          for (var j = 0; j < targ; j++) {
            final key = Const(
                csrs[i].addr + BigInt.from(j) * logicalRegisterIncrement,
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
                        normalizedFrontWriteData.getRange(
                            0, rem == 0 ? dataWidth : rem)
                      ].rconcat())
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
                        normalizedFrontWriteData,
                        if ((j + 1) * dataWidth < csrs[i].config.width)
                          csrs[i].getRange((j + 1) * dataWidth),
                      ].rconcat())
                      .getRange(j * dataWidth, (j + 1) * dataWidth));
            }
          }
          dataToWrite = cases<Csr>(
              frontWrite!.addr,
              conditionalType: ConditionalType.unique,
              wrCases,
              outputGenerator: csrs[i].clone,
              defaultValue: csrs[i]);

          if (hasWriteOnlyField && config.registers[i].isFrontdoorWritable) {
            final validCases = <Logic, Logic>{};
            final dataCases = <Logic, Logic>{};
            for (var j = 0; j < targ; j++) {
              final key = Const(
                  csrs[i].addr + BigInt.from(j) * logicalRegisterIncrement,
                  width: addrWidth);
              final chunkWidth =
                  j == targ - 1 ? (rem == 0 ? dataWidth : rem) : dataWidth;
              final chunkData = j == targ - 1
                  ? normalizedFrontWriteData.getRange(0, chunkWidth)
                  : normalizedFrontWriteData;
              final highWidth =
                  csrs[i].config.width - j * dataWidth - chunkWidth;
              validCases[key] = [
                if (j * dataWidth > 0) Const(0, width: j * dataWidth),
                Const(1, width: 1).replicate(chunkWidth),
                if (highWidth > 0) Const(0, width: highWidth),
              ].rconcat();
              dataCases[key] = [
                if (j * dataWidth > 0) Const(0, width: j * dataWidth),
                chunkData,
                if (highWidth > 0) Const(0, width: highWidth),
              ].rconcat();
            }
            frontdoorWriteValidFull = mux(
                frontWrite!.en,
                cases(
                    frontWrite!.addr,
                    conditionalType: ConditionalType.unique,
                    validCases,
                    defaultValue: Const(0, width: csrs[i].config.width)),
                Const(0, width: csrs[i].config.width));
            frontdoorWriteDataFull = cases(
                frontWrite!.addr,
                conditionalType: ConditionalType.unique,
                dataCases,
                defaultValue: Const(0, width: csrs[i].config.width));
          }
        } else {
          // direct address check
          // direct application of write data
          addrCheck =
              frontWrite!.addr.eq(Const(csrs[i].addr, width: addrWidth));
          dataToWrite = csrs[i].getWriteData(
              normalizedFrontWriteData.getRange(0, csrs[i].config.width));

          if (hasWriteOnlyField && config.registers[i].isFrontdoorWritable) {
            frontdoorWriteValidFull =
                (frontWrite!.en & addrCheck).replicate(csrs[i].config.width);
            frontdoorWriteDataFull =
                normalizedFrontWriteData.getRange(0, csrs[i].config.width);
          }
        }
      }
      frontdoorWriteValidFulls.add(frontdoorWriteValidFull);
      frontdoorWriteDataFulls.add(frontdoorWriteDataFull);

      final unknown = Const(LogicValue.filled(csrs[i].width, LogicValue.x));
      final backdoor = _backdoorIndexMap.containsKey(i)
          ? _backdoorInterfaces[_backdoorIndexMap[i]!]
          : null;
      final backdoorConditions = <Conditional>[
        if (backdoor != null && backdoor.hasWrite)
          Case(
              backdoor.wrEn!,
              [
                CaseItem(Const(0), [csrs[i] < csrs[i]]),
                CaseItem(Const(1), [
                  csrs[i] <
                      csrs[i]
                          .getWriteData(backdoor.wrData!, isBackdoorWrite: true)
                ]),
              ],
              exactMatch: true,
              defaultItem: [csrs[i] < unknown])
        else
          csrs[i] < csrs[i],
      ];

      final writeConditions = <Conditional>[
        if (frontWritePresent && config.registers[i].isFrontdoorWritable)
          Case(
              frontWrite!.en & addrCheck!,
              [
                CaseItem(Const(0), backdoorConditions),
                CaseItem(Const(1), [csrs[i] < dataToWrite]),
              ],
              exactMatch: true,
              defaultItem: [csrs[i] < unknown])
        else
          ...backdoorConditions,
      ];
      Sequential(
        clk,
        [
          // Retain X/Z poisoning when the asynchronous reset wrapper's
          // Verilog `if` takes its else branch for an unknown reset.
          Case(
              reset,
              [
                CaseItem(Const(0), writeConditions),
                CaseItem(Const(1), [
                  csrs[i] < Const(csrs[i].resetValue, width: csrs[i].width)
                ]),
              ],
              exactMatch: true,
              defaultItem: [csrs[i] < unknown]),
        ],
        reset: asyncReset ? reset : null,
        asyncReset: asyncReset,
        resetValues: asyncReset ? {csrs[i]: csrs[i].resetValue} : null,
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
                  Const(csr.addr + BigInt.from(j) * logicalRegisterIncrement,
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
        final validFull = frontdoorWriteValidFulls[i] ??
            Const(0, width: csrs[i].config.width);
        final dataFull =
            frontdoorWriteDataFulls[i] ?? Const(0, width: csrs[i].config.width);
        _backdoorInterfaces[_backdoorIndexMap[i]!].rdData! <=
            csrs[i].getBackdoorReadData(validFull, dataFull);
      }
    }
  }
}
