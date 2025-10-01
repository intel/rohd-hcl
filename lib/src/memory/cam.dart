// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cam.dart
// CAM (Contents-Addressable Memory) modules.
//
// 2025 September 18
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An interface to a Content-Addressable Memory (CAM) that allows querying
/// for tags and returns the index of the matching tag if found.
class TagInterface extends Interface<DataPortGroup> {
  /// The width of data in the memory.
  final int tagWidth;

  /// The width of addresses in the memory.
  final int idWidth;

  /// The "tag" to match.
  Logic get tag => port('tag');

  /// The entry number (index) where the tag was found.
  Logic get idx => port('idx');

  /// If the tag was found a 'hit' is indicated.
  Logic get hit => port('hit');

  /// Constructs a new interface of specified [idWidth] and [tagWidth] for
  /// querying a CAM.
  TagInterface(this.idWidth, this.tagWidth) {
    setPorts([
      Logic.port('en'),
      Logic.port('tag', tagWidth),
    ], [
      DataPortGroup.control
    ]);

    setPorts([
      Logic.port('idx', idWidth),
      Logic.port('hit'),
    ], [
      DataPortGroup.data
    ]);
  }

  /// Makes a copy of this [TagInterface] with matching configuration.
  @override
  TagInterface clone() => TagInterface(idWidth, tagWidth);
}

/// A content-addressable memory (CAM) module.
class Cam extends Memory {
  /// The number of entries in the Cam.
  final int numEntries;

  /// The number of lookup (tag access) ports.
  final int numLookups;

  /// The lookup (tag access) ports.
  @protected
  final List<TagInterface> lookupPorts = [];

  /// Constructs a new [Cam] with write ports that use direct address writes
  /// and .read ports that use associative lookup.
  Cam(Logic clk, Logic reset, List<DataPortInterface> writePorts,
      List<TagInterface> lookupPorts,
      {this.numEntries = 8,
      super.name = 'cam',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : numLookups = lookupPorts.length,
        super(clk, reset, writePorts, [],
            definitionName: definitionName ??
                'CAM_WP${writePorts.length}'
                    '_LP${lookupPorts.length}_E$numEntries') {
    if (lookupPorts.isEmpty) {
      throw ArgumentError('Must provide at least one lookup port.');
    }
    for (var i = 0; i < numLookups; i++) {
      this.lookupPorts.add(lookupPorts[i].clone()
        ..connectIO(this, lookupPorts[i],
            inputTags: {DataPortGroup.control},
            outputTags: {DataPortGroup.data},
            uniquify: (original) => 'lookup_${original}_$i'));
    }
    _buildLogic();
  }

  /// Flop-based storage of all memory.
  late final List<Logic> _storageBank;

  void _buildLogic() {
    // create local storage bank
    _storageBank = List<Logic>.generate(
        numEntries, (i) => Logic(name: 'tag_$i', width: dataWidth));

    // A Cam lookup returns the index.
    for (final lookupPort in lookupPorts) {
      Combinational([
        Case(lookupPort.tag, [
          for (var i = 0; i < numEntries; i++)
            CaseItem(
              _storageBank[i],
              [
                lookupPort.idx < Const(i, width: lookupPort.idWidth),
                lookupPort.hit < Const(1),
              ],
            )
        ], defaultItem: [
          lookupPort.idx < Const(0, width: lookupPort.idWidth),
          lookupPort.hit < Const(0)
        ]),
      ]);
    }
    Sequential(clk, [
      If(reset, then: [
        ..._storageBank.mapIndexed((i, e) => e < Const(0, width: dataWidth))
      ], orElse: [
        for (var entry = 0; entry < numEntries; entry++)
          ...wrPorts.map((wrPort) =>
              // set storage bank if write enable and pointer matches
              If(wrPort.en & wrPort.addr.eq(entry), then: [
                _storageBank[entry] < wrPort.data,
              ])),
      ]),
    ]);
  }

  @override
  int get readLatency => 0;
}
