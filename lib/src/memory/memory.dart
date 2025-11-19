// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory.dart
// Memory interfaces and modules.
//
// 2021 November 3
// Author: Max Korbel <max.korbel@intel.com>

import 'package:meta/meta.dart';
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
class MaskedDataPortInterface extends DataPortInterface {
  /// A bus controlling the mask, where each bit cooresponds to one
  /// byte of data.  A high bit is an enable for that chunk of data.
  Logic get mask => port('mask');

  /// Constructs a [DataPortInterface] with mask.
  MaskedDataPortInterface(super.dataWidth, super.addrWidth) {
    if (dataWidth % 8 != 0) {
      throw RohdHclException('The data width must be byte-granularity');
    }
    setPorts([
      Logic.port('mask', dataWidth ~/ 8),
    ], [
      DataPortGroup.control
    ]);
  }

  @override
  DataPortInterface clone() => MaskedDataPortInterface(dataWidth, addrWidth);
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
  DataPortInterface(this.dataWidth, this.addrWidth) {
    setPorts([
      Logic.port('en'),
      Logic.port('addr', addrWidth),
    ], [
      DataPortGroup.control
    ]);

    setPorts([
      Logic.port('data', dataWidth),
    ], [
      DataPortGroup.data
    ]);
  }

  /// Makes a copy of this [Interface] with matching configuration.
  @override
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

  /// The number of cycles before data is returned after a read.
  ///
  /// Must be non-negative.
  int get readLatency;

  /// Exported access to connected external write ports.
  List<DataPortInterface> get writes => _extWrites;

  /// Exported access to connected external read ports.
  List<DataPortInterface> get reads => _extReads;

  /// External write ports passed into the RF constructor.
  final List<DataPortInterface> _extWrites;

  /// External read ports passed into the RF constructor.
  final List<DataPortInterface> _extReads;

  /// Internal write ports.
  @protected
  final List<DataPortInterface> wrPorts = [];

  /// Internal read ports.
  @protected
  final List<DataPortInterface> rdPorts = [];

  /// Internal clock.
  @protected
  Logic get clk => input('clk');

  /// Internal reset.
  @protected
  Logic get reset => input('reset');

  /// Construct a new memory.
  ///
  /// Must provide at least one port (read or write).
  Memory(Logic clk, Logic reset, List<DataPortInterface> writePorts,
      List<DataPortInterface> readPorts,
      {super.name = 'memory',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : _extWrites = writePorts,
        _extReads = readPorts,
        numWrites = writePorts.length,
        numReads = readPorts.length,
        dataWidth = (writePorts.isNotEmpty)
            ? writePorts[0].dataWidth
            : (readPorts.isNotEmpty)
                ? readPorts[0].dataWidth
                : 0, // at least one of these must exist
        addrWidth = (writePorts.isNotEmpty)
            ? writePorts[0].addrWidth
            : (readPorts.isNotEmpty)
                ? readPorts[0].addrWidth
                : 0, // at least one of these must exist
        super(
            definitionName: definitionName ??
                'Memory_WP${writePorts.length}_RP${readPorts.length}') {
    if (writePorts.isEmpty && readPorts.isEmpty) {
      throw RohdHclException(
          'Must specify at least one read port or one write port.');
    }
    if (readLatency < 0) {
      throw RohdHclException('Read latency must be non-negative.');
    }

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
      rdPorts.add(readPorts[i].clone()
        ..connectIO(this, readPorts[i],
            inputTags: {DataPortGroup.control},
            outputTags: {DataPortGroup.data},
            uniquify: (original) => 'rd_${original}_$i'));
    }
    for (var i = 0; i < numWrites; i++) {
      wrPorts.add(writePorts[i].clone()
        ..connectIO(this, writePorts[i],
            inputTags: {DataPortGroup.control, DataPortGroup.data},
            outputTags: {},
            uniquify: (original) => 'wr_${original}_$i'));
    }
  }
}
