// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// register_file.dart
// A register file.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A flop-based memory.
class RegisterFile extends Memory {
  /// Accesses the read data for the provided [index].
  Logic rdData(int index) => rdPorts[index].data;

  /// The number of entries in the RF.
  final int numEntries;

  /// Constructs a new RF.
  ///
  /// [MaskedDataPortInterface]s are supported on `writePorts`, but not on
  /// `readPorts`.
  RegisterFile(super.clk, super.reset, super.writePorts, super.readPorts,
      {this.numEntries = 8, super.name = 'rf'}) {
    _buildLogic();
  }

  /// A testbench hook to access data at a given address.
  LogicValue? getData(LogicValue addr) => _storageBank[addr.toInt()].value;

  /// Flop-based storage of all memory.
  late final List<Logic> _storageBank;

  void _buildLogic() {
    // create local storage bank
    _storageBank = List<Logic>.generate(
        numEntries, (i) => Logic(name: 'storageBank_$i', width: dataWidth));

    Sequential(clk, [
      If(reset, then: [
        // zero out entire storage bank on reset
        ..._storageBank.map((e) => e < 0)
      ], orElse: [
        for (var entry = 0; entry < numEntries; entry++)
          ...wrPorts.map((wrPort) =>
              // set storage bank if write enable and pointer matches
              If(wrPort.en & wrPort.addr.eq(entry), then: [
                _storageBank[entry] <
                    (wrPort is MaskedDataPortInterface
                        ? [
                            for (var index = 0; index < dataWidth ~/ 8; index++)
                              mux(
                                  wrPort.mask[index],
                                  wrPort.data
                                      .getRange(index * 8, (index + 1) * 8),
                                  _storageBank[entry]
                                      .getRange(index * 8, (index + 1) * 8))
                          ].rswizzle()
                        : wrPort.data),
              ])),
      ]),
    ]);

    Combinational([
      ...rdPorts.map((rdPort) => If(reset | ~rdPort.en, then: [
            rdPort.data < Const(0, width: dataWidth)
          ], orElse: [
            Case(rdPort.addr, [
              for (var entry = 0; entry < numEntries; entry++)
                CaseItem(Const(LogicValue.ofInt(entry, addrWidth)),
                    [rdPort.data < _storageBank[entry]])
            ], defaultItem: [
              rdPort.data < Const(0, width: dataWidth)
            ])
          ]))
    ]);
  }

  @override
  int get readLatency => 0;
}
