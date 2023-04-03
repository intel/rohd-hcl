// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory.dart
// Memory interfaces and modules, including RF.
//
// 2021 November 3
// Author: Max Korbel <max.korbel@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// A grouping for interface signals of [DataPortInterface]s.
enum DataPortGroup {
  /// For signals associated with controlling/requesting actions for memory.
  control,

  /// For data signals to/from memory.
  data
}

/// A [DataPortInterface] that supports byte-enabled strobing.
class StrobeDataPortInterface extends DataPortInterface {
  /// A bus controlling the strobe, where each bit cooresponds to one
  /// byte of data.
  Logic get strobe => port('strobe');

  /// Constructs a [DataPortInterface] with strobe.
  StrobeDataPortInterface(super.dataWidth, super.addrWidth) {
    setPorts([
      Port('strobe', dataWidth ~/ 8),
    ], [
      DataPortGroup.control
    ]);
  }

  @override
  DataPortInterface clone() => StrobeDataPortInterface(dataWidth, addrWidth);
}

/// An interface to a simple memory that only needs enable, address, and data.
///
/// Can be used for either read or write direction by grouping signals using
/// [DataPortGroup].
class DataPortInterface extends Interface<DataPortGroup> {
  /// The width of data in the memory.
  final int dataWidth;

  /// The width of addresses in the memory.
  final int addrWidth;

  /// The "enable" bit for this interface, enabling a request.
  Logic get en => port('en');

  /// The "address" bit for a request when [en] is high.
  Logic get addr => port('addr');

  /// The data sent or received with the associated request.
  Logic get data => port('data');

  /// Constructs a new interface of specified [dataWidth] and [addrWidth] for
  /// interacting with a memory in either the read or write direction.
  DataPortInterface(this.dataWidth, this.addrWidth)
      : assert(dataWidth % 8 == 0, 'The data width must be byte-granularity') {
    setPorts([
      Port('en'),
      Port('addr', addrWidth),
    ], [
      DataPortGroup.control
    ]);

    setPorts([
      Port('data', dataWidth),
    ], [
      DataPortGroup.data
    ]);
  }

  /// Makes a copy of this [Interface] with matching configuration.
  DataPortInterface clone() => DataPortInterface(dataWidth, addrWidth);
}

/// A generic memory with variable numbers of read and write ports.
abstract class Memory extends Module {
  /// The number of write ports.
  final int numWrites;

  /// The number of read ports.
  final int numReads;

  /// The address width.
  final int addrWidth;

  /// The data width.
  final int dataWidth;

  final List<DataPortInterface> _wrPorts = [];
  final List<DataPortInterface> _rdPorts = [];

  /// Internal clock.
  Logic get _clk => input('clk');

  /// Internal reset.
  Logic get _reset => input('reset');

  /// Construct a new memory.
  Memory(Logic clk, Logic reset, List<DataPortInterface> writePorts,
      List<DataPortInterface> readPorts,
      {super.name = 'memory'})
      : assert(writePorts.isNotEmpty && readPorts.isNotEmpty,
            'Must specify at least one read port and one write port.'),
        numWrites = writePorts.length,
        numReads = readPorts.length,
        dataWidth = (writePorts.isNotEmpty)
            ? writePorts[0].dataWidth
            : readPorts[0].dataWidth, // at least one of these must exist
        addrWidth = (writePorts.isNotEmpty)
            ? writePorts[0].addrWidth
            : readPorts[0].addrWidth // at least one of these must exist
  {
    // make sure widths of everything match expectations
    for (final port in [...writePorts, ...readPorts]) {
      if (port.addrWidth != addrWidth) {
        throw RohdHclException('All ports must have the same address width.');
      }
      if (port.dataWidth != dataWidth) {
        throw RohdHclException('All ports must have the same data width.');
      }
    }

    addInput('clk', clk);
    addInput('reset', reset);

    for (var i = 0; i < numReads; i++) {
      _rdPorts.add(readPorts[i].clone()
        ..connectIO(this, readPorts[i],
            inputTags: {DataPortGroup.control},
            outputTags: {DataPortGroup.data},
            uniquify: (original) => 'rd_${original}_$i'));
    }
    for (var i = 0; i < numWrites; i++) {
      _wrPorts.add(writePorts[i].clone()
        ..connectIO(this, writePorts[i],
            inputTags: {DataPortGroup.control, DataPortGroup.data},
            outputTags: {},
            uniquify: (original) => 'wr_${original}_$i'));
    }
  }
}

/// A flop-based memory.
class RegisterFile extends Memory {
  /// Accesses the read data for the provided [index].
  Logic rdData(int index) => _rdPorts[index].data;

  /// The number of entries in the RF.
  final int numEntries;

  /// Constructs a new RF.
  ///
  /// [StrobeDataPortInterface]s are supported on `writePorts`, but not on
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

    Sequential(_clk, [
      If(_reset, then: [
        // zero out entire storage bank on reset
        ..._storageBank.map((e) => e < 0)
      ], orElse: [
        for (var entry = 0; entry < numEntries; entry++)
          ..._wrPorts.map((wrPort) =>
              // set storage bank if write enable and pointer matches
              If(wrPort.en & wrPort.addr.eq(entry), then: [
                _storageBank[entry] <
                    (wrPort is StrobeDataPortInterface
                        ? [
                            for (var index = 0; index < dataWidth ~/ 8; index++)
                              mux(
                                  wrPort.strobe[index],
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
      ..._rdPorts.map((rdPort) => If(_reset | ~rdPort.en, then: [
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
}
