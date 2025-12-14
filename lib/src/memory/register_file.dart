// Copyright (C) 2023-2025 Intel Corporation
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

/// A flop-based [Memory].
class RegisterFile extends Memory with ResettableEntries {
  /// Accesses the read data for the provided [index].
  Logic rdData(int index) => rdPorts[index].data;

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
  RegisterFile(
    super.clk,
    super.reset,
    super.writePorts,
    super.readPorts, {
    this.numEntries = 8,
    super.name = 'rf',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
    dynamic resetValue,
  }) : super(
          definitionName: definitionName ??
              'RegisterFile_WP${writePorts.length}'
                  '_RP${readPorts.length}_E$numEntries',
        ) {
    _resetValues = makeResetValues(
      resetValue,
      numEntries: numEntries,
      entryWidth: dataWidth,
    );
    _buildLogic();
  }

  /// A testbench hook to access data at a given address.
  LogicValue? getData(LogicValue addr) => _storageBank[addr.toInt()].value;

  /// A testbench hook to write data at a given address.
  void setData(LogicValue addr, LogicValue value) {
    _storageBank[addr.toInt()].put(value);
  }

  /// Flop-based storage of all memory.
  late final List<Logic> _storageBank;

  void _buildLogic() {
    // create local storage bank
    _storageBank = List<Logic>.generate(
      numEntries,
      (i) => Logic(name: 'storageBank_$i', width: dataWidth),
    );

    Sequential(clk, [
      If(
        reset,
        then: [..._storageBank.mapIndexed((i, e) => e < _resetValues[i])],
        orElse: [
          for (var entry = 0; entry < numEntries; entry++)
            ...wrPorts.map(
              (wrPort) =>
                  // set storage bank if write enable and pointer matches
                  If(
                wrPort.en & wrPort.addr.eq(entry),
                then: [
                  wrPort.valid < 1,
                  _storageBank[entry] <
                      (wrPort is MaskedDataPortInterface
                          ? [
                              for (var index = 0;
                                  index < dataWidth ~/ 8;
                                  index++)
                                mux(
                                  wrPort.mask[index],
                                  wrPort.data.getRange(
                                    index * 8,
                                    (index + 1) * 8,
                                  ),
                                  _storageBank[entry].getRange(
                                    index * 8,
                                    (index + 1) * 8,
                                  ),
                                ),
                            ].rswizzle()
                          : wrPort.data),
                ],
              ),
            ),
        ],
      ),
    ]);

    Combinational([
      ...rdPorts.map(
        (rdPort) => If(
          ~rdPort.en,
          then: [rdPort.data < Const(0, width: dataWidth)],
          orElse: [
            Case(
              rdPort.addr,
              [
                for (var entry = 0; entry < numEntries; entry++)
                  CaseItem(Const(LogicValue.ofInt(entry, addrWidth)), [
                    rdPort.data < _storageBank[entry],
                    rdPort.valid < 1,
                  ]),
              ],
              defaultItem: [rdPort.data < Const(0, width: dataWidth)],
            ),
          ],
        ),
      ),
    ]);
  }

  @override
  int get readLatency => 0;
}
