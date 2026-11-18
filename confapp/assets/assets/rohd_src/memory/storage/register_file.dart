// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// register_file.dart
// A register file.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';

/// A flop-based [Memory].
class RegisterFile<LogicType extends Logic> extends Memory<LogicType>
    with ResettableEntries {
  /// Accesses the read data for the provided [index].
  LogicType rdData(int index) => reads[index].data;

  /// The number of entries in the RF.
  final int numEntries;

  /// Entry-indexed reset values for the [_storageBank].
  late final List<Logic> _resetValues;

  /// Constructs a new RF.
  ///
  /// [MaskedDataPortInterface]s are supported on `writePorts`, but not on
  /// `readPorts`.
  ///
  /// The [resetValue] follows the semantics of [ResettableEntries].
  RegisterFile(super.clk, super.reset, super.writePorts, super.readPorts,
      {this.numEntries = 8,
      super.name = 'rf',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName,
      dynamic resetValue})
      : super(
            definitionName: definitionName ??
                'RegisterFile_WP${writePorts.length}'
                    '_RP${readPorts.length}_E$numEntries') {
    _resetValues = makeResetValues(resetValue,
        numEntries: numEntries, entryWidth: dataWidth);
    _buildLogic();
  }

  /// A testbench hook to access data at a given address.
  LogicValue? getData(LogicValue addr) => _storageBank.at([_index(addr)]).value;

  int _index(LogicValue address) {
    final index = address.toBigInt();
    if (index >= BigInt.from(numEntries)) {
      throw RangeError('Address $index is outside register-file geometry.');
    }
    return index.toInt();
  }

  /// A testbench hook to write data at a given address.
  void setData(LogicValue addr, LogicValue value) {
    _storageBank.at([_index(addr)]).put(normalizeStoredValue(value));
  }

  /// Flop-based storage of all memory.
  late final TypedLogicArray<LogicType, LogicValue> _storageBank;

  void _buildLogic() {
    // create local storage bank
    final prototype = (wrPorts.isNotEmpty ? wrPorts.first : rdPorts.first).data;
    _storageBank = TypedLogicArray<LogicType, LogicValue>(
        [numEntries], prototype.cloneTyped,
        name: 'storageBank');

    List<Conditional> writeEntry(DataPortInterface<LogicType> port, int entry) {
      final target = _storageBank.at([entry]);
      final selected = storedIndexMatches(port.addr, entry);
      if (port is MaskedDataPortInterface<LogicType>) {
        final bytes = <Logic>[];
        final uncertainBytes = <Logic>[];
        for (var byte = 0; byte < dataWidth ~/ 8; byte++) {
          final old = target.getRange(byte * 8, (byte + 1) * 8);
          final updated = Logic(width: 8);
          final uncertain = Logic(width: 8);
          Combinational([
            Case(
                port.mask[byte],
                [
                  CaseItem(Const(0), [updated < old, uncertain < old]),
                  CaseItem(Const(1), [
                    updated <
                        normalizeStoredLogic(
                            port.data.getRange(byte * 8, (byte + 1) * 8)),
                    uncertain < Const(LogicValue.filled(8, LogicValue.x)),
                  ]),
                ],
                exactMatch: true,
                defaultItem: [
                  updated < Const(LogicValue.filled(8, LogicValue.x)),
                  uncertain < Const(LogicValue.filled(8, LogicValue.x)),
                ]),
          ]);
          bytes.add(updated);
          uncertainBytes.add(uncertain);
        }
        return [
          Case(
              port.en & selected,
              [
                CaseItem(Const(0), []),
                CaseItem(Const(1), [target < bytes.rconcat()]),
              ],
              exactMatch: true,
              defaultItem: [target < uncertainBytes.rconcat()])
        ];
      }
      final unknown = Logic(width: dataWidth)
        ..gets(Const(LogicValue.filled(dataWidth, LogicValue.x)));
      return [
        Case(
            port.en & selected,
            [
              CaseItem(Const(0), []),
              CaseItem(Const(1), [target < normalizeStoredLogic(port.data)])
            ],
            exactMatch: true,
            defaultItem: [target < unknown])
      ];
    }

    Sequential(clk, [
      If(reset, then: [
        ..._storageBank.arrayElements
            .mapIndexed((i, e) => e < normalizeStoredLogic(_resetValues[i]))
      ], orElse: [
        for (var entry = 0; entry < numEntries; entry++)
          for (final wrPort in wrPorts) ...writeEntry(wrPort, entry),
      ]),
    ]);

    for (final rdPort in rdPorts) {
      final unknown = Logic(width: dataWidth)
        ..gets(Const(LogicValue.filled(dataWidth, LogicValue.x)));
      Combinational([
        Case(
            rdPort.en,
            [
              CaseItem(Const(0), [rdPort.data < Const(0, width: dataWidth)]),
              CaseItem(Const(1), [
                Case(
                    rdPort.addr ^ rdPort.addr,
                    [
                      CaseItem(Const(0, width: addrWidth), [
                        Case(
                            rdPort.addr,
                            [
                              for (var entry = 0; entry < numEntries; entry++)
                                CaseItem(
                                    Const(LogicValue.ofInt(entry, addrWidth)), [
                                  rdPort.data < _storageBank.at([entry])
                                ])
                            ],
                            exactMatch: true,
                            defaultItem: [
                              rdPort.data < Const(0, width: dataWidth)
                            ])
                      ])
                    ],
                    exactMatch: true,
                    defaultItem: [rdPort.data < unknown])
              ])
            ],
            exactMatch: true,
            defaultItem: [rdPort.data < unknown])
      ]);
    }
  }

  @override
  int get readLatency => 0;
}
