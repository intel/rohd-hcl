// Copyright (C) 2023-2026 Intel Corporation
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
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// A grouping for interface signals of [DataPortInterface]s.
enum DataPortGroup {
  /// For signals associated with controlling/requesting actions for memory.
  control,

  /// For data signals to/from memory.
  data
}

/// A [DataPortInterface] that supports byte-enabled strobing.
class MaskedDataPortInterface<LogicType extends Logic>
    extends DataPortInterface<LogicType> {
  /// A bus controlling the mask, where each bit cooresponds to one
  /// byte of data.  A high bit is an enable for that chunk of data.
  Logic get mask => port('mask');

  /// Constructs a [DataPortInterface] with mask.
  MaskedDataPortInterface(super.dataWidth, super.addrWidth) {
    _addMask();
  }

  /// Constructs a byte-masked port preserving the payload schema of [data].
  MaskedDataPortInterface.typed(super.data, super.addrWidth) : super.typed() {
    _addMask();
  }

  void _addMask() {
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
  MaskedDataPortInterface<LogicType> clone() =>
      MaskedDataPortInterface<LogicType>.typed(data, addrWidth);
}

/// An interface to a simple memory that only needs enable, address, and data.
///
/// Can be used for either read or write direction by grouping signals using
/// [DataPortGroup].
class DataPortInterface<LogicType extends Logic>
    extends Interface<DataPortGroup> {
  /// The width of data in the memory.
  final int dataWidth;

  /// The width of addresses in the memory.
  final int addrWidth;

  /// The "enable" bit for this interface, enabling a request.
  Logic get en => port('en');

  /// The "address" bit for a request when [en] is high.
  Logic get addr => port('addr');

  /// The data sent or received with the associated request.
  LogicType get data => port('data') as LogicType;

  /// Constructs a new interface of specified [dataWidth] and [addrWidth] for
  /// interacting with a memory in either the read or write direction.
  DataPortInterface(this.dataWidth, this.addrWidth) {
    if (LogicType != Logic) {
      throw ArgumentError(
          'Use DataPortInterface.typed for a specialized payload type.');
    }
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

  /// Constructs a memory port with a type-preserving clone of [data].
  ///
  /// [data] is a schema, not a driver. Drive the returned interface's [data]
  /// for writes, or consume it for reads.
  DataPortInterface.typed(LogicType data, this.addrWidth)
      : dataWidth = data.width {
    setPorts([Logic.port('en'), Logic.port('addr', addrWidth)],
        [DataPortGroup.control]);
    setPorts([data.cloneTyped(name: 'data')], [DataPortGroup.data]);
  }

  /// Makes a copy of this [Interface] with matching configuration.
  @override
  DataPortInterface<LogicType> clone() =>
      DataPortInterface<LogicType>.typed(data, addrWidth);

  bool _suppressData = false;

  @override
  Map<String, Logic> getPorts([Iterable<DataPortGroup>? tags]) {
    final ports = super.getPorts(tags);
    return _suppressData
        ? (Map<String, Logic>.of(ports)..remove('data'))
        : ports;
  }

  @override
  void connectIO(Module module, Interface<dynamic> srcInterface,
      {Iterable<DataPortGroup>? inputTags,
      Iterable<DataPortGroup>? outputTags,
      Iterable<DataPortGroup>? inOutTags,
      String Function(String original)? uniquify}) {
    final source = srcInterface.port('data');
    if (source.width != dataWidth ||
        (((source is LogicStructure && data is LogicStructure) ||
                (source is LogicEnum && data is LogicEnum)) &&
            !sameDeclaredPayloadShape(data, source))) {
      throw PortTypeException.forIntendedName(
          'data',
          'Memory payload layout does not match '
              '${payloadShapeIdentity(data)}.');
    }
    final dataName = uniquify?.call('data') ?? 'data';
    if (inputTags?.contains(DataPortGroup.data) ?? false) {
      final bridge = data.cloneTyped(name: 'data_input_bridge')..gets(source);
      data <= module.addTypedInput(dataName, bridge);
    }
    if (outputTags?.contains(DataPortGroup.data) ?? false) {
      final output = module.addTypedOutput(dataName, data.cloneTyped);
      output <= data;
      source <= output;
    }
    if (inOutTags?.contains(DataPortGroup.data) ?? false) {
      final bridge = data.cloneTyped(name: 'data_inout_bridge')..gets(source);
      data <= module.addTypedInOut(dataName, bridge);
    }
    _suppressData = true;
    try {
      super.connectIO(module, srcInterface,
          inputTags: inputTags,
          outputTags: outputTags,
          inOutTags: inOutTags,
          uniquify: uniquify);
    } finally {
      _suppressData = false;
    }
  }
}

/// A generic memory with variable numbers of read and write ports.
abstract class Memory<LogicType extends Logic> extends Module {
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
  List<DataPortInterface<LogicType>> get writes => _extWrites;

  /// Exported access to connected external read ports.
  List<DataPortInterface<LogicType>> get reads => _extReads;

  /// External write ports passed into the RF constructor.
  final List<DataPortInterface<LogicType>> _extWrites;

  /// External read ports passed into the RF constructor.
  final List<DataPortInterface<LogicType>> _extReads;

  /// Internal write ports.
  @protected
  final List<DataPortInterface<LogicType>> wrPorts = [];

  /// Internal read ports.
  @protected
  final List<DataPortInterface<LogicType>> rdPorts = [];

  /// Internal clock.
  @protected
  Logic get clk => input('clk');

  /// Internal reset.
  @protected
  Logic get reset => input('reset');

  /// Construct a new memory.
  ///
  /// Must provide at least one port (read or write).
  Memory(Logic clk, Logic reset, List<DataPortInterface<LogicType>> writePorts,
      List<DataPortInterface<LogicType>> readPorts,
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

    final prototype =
        (writePorts.isNotEmpty ? writePorts.first : readPorts.first).data;
    // make sure widths of everything match expectations
    for (final port in [...writePorts, ...readPorts]) {
      if (port.addrWidth != addrWidth) {
        throw RohdHclException('All ports must have the same address width.');
      }
      if (port.dataWidth != dataWidth) {
        throw RohdHclException('All ports must have the same data width.');
      }
      if (((prototype is LogicStructure && port.data is LogicStructure) ||
              (prototype is LogicEnum && port.data is LogicEnum)) &&
          !sameDeclaredPayloadShape(prototype, port.data)) {
        throw RohdHclException('All memory ports must have matching payload '
            'layouts and value codecs.');
      }
    }

    addInput('clk', clk);
    addInput('reset', reset);

    for (var i = 0; i < numReads; i++) {
      rdPorts.add(addInterfacePorts(readPorts[i],
          inputTags: {DataPortGroup.control},
          outputTags: {DataPortGroup.data},
          uniquify: (original) => 'rd_${original}_$i'));
    }
    for (var i = 0; i < numWrites; i++) {
      wrPorts.add(addInterfacePorts(writePorts[i],
          inputTags: {DataPortGroup.control, DataPortGroup.data},
          uniquify: (original) => 'wr_${original}_$i'));
    }
  }
}
