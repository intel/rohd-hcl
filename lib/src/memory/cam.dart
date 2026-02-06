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
///
/// For lookups, `tag` is the query and `idx`/`hit` are the results.
/// Only entries with their valid bit set will match during lookups.
///
/// For writes, `en` enables the write, `idx` is the destination address,
/// `tag` is the data to write, and `hit` sets/clears the valid bit
/// (hit=1 marks the entry valid, hit=0 marks it invalid).
class TagInterface extends Interface<DataPortGroup> {
  /// The width of data in the memory.
  final int tagWidth;

  /// The width of addresses in the memory.
  final int idWidth;

  /// Enable signal for write operations.
  Logic get en => port('en');

  /// The "tag" to match (for lookup) or write (for write operations).
  Logic get tag => port('tag');

  /// The entry number (index) where the tag was found (lookup) or
  /// the destination address (write).
  Logic get idx => port('idx');

  /// For lookups: indicates whether a valid match was found.
  /// For writes: sets/clears the valid bit (1=valid, 0=invalid).
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
class Cam extends Module {
  /// The number of entries in the Cam.
  final int numEntries;

  /// The number of write ports.
  final int numWrites;

  /// The number of lookup (tag access) ports.
  final int numLookups;

  /// Whether to track the number of valid entries and emit full/empty signals.
  final bool enableValidTracking;

  /// Internal clock.
  @protected
  Logic get clk => input('clk');

  /// Internal reset.
  @protected
  Logic get reset => input('reset');

  /// Internal write ports using TagInterface.
  @protected
  final List<TagInterface> wrPorts = [];

  /// The lookup (tag access) ports.
  @protected
  final List<TagInterface> lookupPorts = [];

  /// Signal indicating the CAM is full (all entries valid).
  /// Only available when [enableValidTracking] is true.
  Logic? get full => enableValidTracking ? output('full') : null;

  /// Signal indicating the CAM is empty (no entries valid).
  /// Only available when [enableValidTracking] is true.
  Logic? get empty => enableValidTracking ? output('empty') : null;

  /// The count of valid entries.
  /// Only available when [enableValidTracking] is true.
  Logic? get validCount => enableValidTracking ? output('valid_count') : null;

  /// Constructs a new [Cam] with write ports and lookup ports using
  /// [TagInterface].
  ///
  /// For write ports, `en` enables the write, `idx` specifies the address,
  /// and `tag` provides the data to write. The `hit` signal is ignored for
  /// writes.
  ///
  /// For lookup ports, `tag` is the query, `idx` returns the matching index,
  /// and `hit` indicates whether a match was found.
  ///
  /// If [enableValidTracking] is true, the CAM will maintain a count of
  /// valid entries and provide [full], [empty], and [validCount] signals.
  ///
  /// Example with valid tracking enabled:
  /// ```dart
  /// final cam = Cam(
  ///   clk, reset,
  ///   [writePort], [lookupPort],
  ///   numEntries: 16,
  ///   enableValidTracking: true,
  /// );
  /// // Use cam.full, cam.empty, and cam.validCount signals
  /// ```
  Cam(Logic clk, Logic reset, List<TagInterface> writePorts,
      List<TagInterface> lookupPorts,
      {this.numEntries = 8,
      this.enableValidTracking = false,
      super.name = 'cam',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : numWrites = writePorts.length,
        numLookups = lookupPorts.length,
        super(
            definitionName: definitionName ??
                'CAM_WP${writePorts.length}'
                    '_LP${lookupPorts.length}_E$numEntries') {
    if (writePorts.isEmpty && lookupPorts.isEmpty) {
      throw ArgumentError('Must provide at least one write or lookup port.');
    }
    if (lookupPorts.isEmpty) {
      throw ArgumentError('Must provide at least one lookup port.');
    }

    addInput('clk', clk);
    addInput('reset', reset);

    // Connect write ports - all signals are inputs for writes
    for (var i = 0; i < numWrites; i++) {
      wrPorts.add(writePorts[i].clone()
        ..connectIO(this, writePorts[i],
            inputTags: {DataPortGroup.control, DataPortGroup.data},
            outputTags: {},
            uniquify: (original) => 'wr_${original}_$i'));
    }

    // Connect lookup ports - control signals are inputs, data signals are
    // outputs
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

  /// Valid bits for each entry.
  late final List<Logic> _validBits;

  void _buildLogic() {
    final tagWidth = lookupPorts.first.tagWidth;

    // create local storage bank
    _storageBank = List<Logic>.generate(
        numEntries, (i) => Logic(name: 'tag_$i', width: tagWidth));

    // Create valid bits for each entry
    _validBits =
        List<Logic>.generate(numEntries, (i) => Logic(name: 'valid_$i'));

    // Create valid tracking outputs if enabled
    if (enableValidTracking) {
      final countWidth = log2Ceil(numEntries + 1);
      addOutput('valid_count', width: countWidth);
      addOutput('full');
      addOutput('empty');
    }

    // A Cam lookup returns the index, but only matches valid entries.
    for (final lookupPort in lookupPorts) {
      // Build a swizzled value of [valid, tag] for comparison
      final validTag = [Const(1), lookupPort.tag].swizzle();

      Combinational([
        Case(validTag, [
          for (var i = 0; i < numEntries; i++)
            CaseItem(
              [_validBits[i], _storageBank[i]].swizzle(),
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

    if (enableValidTracking) {
      // Count valid entries
      final countSum = _validBits
          .map((v) => v.zeroExtend(validCount!.width))
          .reduce((a, b) => a + b);
      validCount! <= countSum;
      full! <= validCount!.eq(numEntries);
      empty! <= validCount!.eq(0);
    }

    Sequential(clk, [
      If(reset, then: [
        ..._storageBank.mapIndexed((i, e) => e < Const(0, width: tagWidth)),
        ..._validBits.map((v) => v < Const(0)),
      ], orElse: [
        for (var entry = 0; entry < numEntries; entry++)
          ...wrPorts.map((wrPort) =>
              // set storage bank if write enable and pointer matches
              // use wrPort.hit to set/clear the valid bit
              If(wrPort.en & wrPort.idx.eq(entry), then: [
                _storageBank[entry] < wrPort.tag,
                _validBits[entry] < wrPort.hit,
              ])),
      ]),
    ]);
  }

  /// Read latency is 0 (combinational lookup).
  int get readLatency => 0;
}
