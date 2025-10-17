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

  /// Whether to track the number of valid entries and emit full/empty signals.
  final bool enableValidTracking;

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

  /// Constructs a new [Cam] with write ports that use direct address writes
  /// and .read ports that use associative lookup.
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
  Cam(Logic clk, Logic reset, List<DataPortInterface> writePorts,
      List<TagInterface> lookupPorts,
      {this.numEntries = 8,
      this.enableValidTracking = false,
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

  /// Valid bits for each entry (only used when enableValidTracking is true).
  late final List<Logic>? _validBits;

  void _buildLogic() {
    // create local storage bank
    _storageBank = List<Logic>.generate(
        numEntries, (i) => Logic(name: 'tag_$i', width: dataWidth));

    // Create valid tracking if enabled
    if (enableValidTracking) {
      _validBits =
          List<Logic>.generate(numEntries, (i) => Logic(name: 'valid_$i'));

      final countWidth = log2Ceil(numEntries + 1);
      addOutput('valid_count', width: countWidth);
      addOutput('full');
      addOutput('empty');
    }

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

    if (enableValidTracking) {
      // Count valid entries
      final countSum = _validBits!
          .map((v) => v.zeroExtend(validCount!.width))
          .reduce((a, b) => a + b);
      validCount! <= countSum;
      full! <= validCount!.eq(numEntries);
      empty! <= validCount!.eq(0);
    }

    Sequential(clk, [
      If(reset, then: [
        ..._storageBank.mapIndexed((i, e) => e < Const(0, width: dataWidth)),
        if (enableValidTracking) ..._validBits!.map((v) => v < Const(0)),
      ], orElse: [
        for (var entry = 0; entry < numEntries; entry++)
          ...wrPorts.map((wrPort) =>
              // set storage bank if write enable and pointer matches
              If(wrPort.en & wrPort.addr.eq(entry), then: [
                _storageBank[entry] < wrPort.data,
                if (enableValidTracking) _validBits![entry] < Const(1),
              ])),
      ]),
    ]);
  }

  @override
  int get readLatency => 0;
}

/// An interface to a Content-Addressable Memory (CAM) with invalidate support.
///
/// This interface extends [TagInterface] with an invalidate signal that,
/// when asserted during a lookup, will clear the valid bit of the matching
/// entry after returning the result.
class TagInvalidateInterface extends TagInterface {
  /// Signal to invalidate the matching entry on a successful lookup.
  Logic get invalidate => port('invalidate');

  /// Constructs a new interface with invalidate support.
  TagInvalidateInterface(super.idWidth, super.tagWidth) {
    setPorts([
      Logic.port('invalidate'),
    ], [
      DataPortGroup.control
    ]);
  }

  /// Makes a copy of this [TagInvalidateInterface] with matching configuration.
  @override
  TagInvalidateInterface clone() => TagInvalidateInterface(idWidth, tagWidth);
}

/// A content-addressable memory (CAM) with invalidate-on-read support.
///
/// This CAM maintains a valid bit for each entry. When a lookup succeeds
/// and the [TagInvalidateInterface.invalidate] signal is asserted, the valid
/// bit for that entry is cleared, making the entry unavailable for future
/// lookups until it is written again.
class CamInvalidate extends Memory {
  /// The number of entries in the Cam.
  final int numEntries;

  /// The number of lookup (tag access) ports.
  final int numLookups;

  /// Whether to track the number of valid entries and emit full/empty signals.
  final bool enableValidTracking;

  /// The lookup (tag access) ports with invalidate support.
  @protected
  final List<TagInvalidateInterface> lookupPorts = [];

  /// Signal indicating the CAM is full (all entries valid).
  /// Only available when [enableValidTracking] is true.
  Logic? get full => enableValidTracking ? output('full') : null;

  /// Signal indicating the CAM is empty (no entries valid).
  /// Only available when [enableValidTracking] is true.
  Logic? get empty => enableValidTracking ? output('empty') : null;

  /// The count of valid entries.
  /// Only available when [enableValidTracking] is true.
  Logic? get validCount => enableValidTracking ? output('valid_count') : null;

  /// Constructs a new [CamInvalidate] with write ports and lookup ports
  /// that support invalidate-on-read.
  ///
  /// Each entry has a valid bit that is set on write and can be cleared
  /// on a successful lookup when [TagInvalidateInterface.invalidate] is high.
  ///
  /// If [enableValidTracking] is true, the CAM will maintain a count of
  /// valid entries and provide [full], [empty], and [validCount] signals.
  /// This is particularly useful with invalidate-on-read to track how many
  /// entries are still valid.
  ///
  /// Example with valid tracking:
  /// ```dart
  /// final cam = CamInvalidate(
  ///   clk, reset,
  ///   [writePort], [lookupPort],
  ///   numEntries: 16,
  ///   enableValidTracking: true,
  /// );
  /// // cam.validCount decrements automatically when entries are invalidated
  /// ```
  CamInvalidate(Logic clk, Logic reset, List<DataPortInterface> writePorts,
      List<TagInvalidateInterface> lookupPorts,
      {this.numEntries = 8,
      this.enableValidTracking = false,
      super.name = 'cam_invalidate',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : numLookups = lookupPorts.length,
        super(clk, reset, writePorts, [],
            definitionName: definitionName ??
                'CAM_INV_WP${writePorts.length}'
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

  /// Flop-based storage of all memory (includes valid bit in MSB).
  late final List<Logic> _storageBank;

  void _buildLogic() {
    // Create local storage bank for tags with valid bit (MSB)
    // Width is dataWidth + 1 to include the valid bit
    _storageBank = List<Logic>.generate(
        numEntries, (i) => Logic(name: 'tag_$i', width: dataWidth + 1));
    if (enableValidTracking) {
      final countWidth = log2Ceil(numEntries + 1);
      addOutput('valid_count', width: countWidth);
      addOutput('full');
      addOutput('empty');

      // TODO(desmonddak): replace with an up/dn Counter when available.
      // Count valid entries by summing the MSB (valid bit)
      // of each storage bank entry.
      final validBits = _storageBank
          .map((tag) => tag[dataWidth]) // Extract MSB (valid bit).
          .toList();
      final countSum = validBits
          .map((v) => v.zeroExtend(validCount!.width))
          .reduce((a, b) => a + b);
      validCount! <= countSum;
      full! <= validCount!.eq(numEntries);
      empty! <= validCount!.eq(0);
    }

    // CAM lookup: check if tag matches and entry is valid.
    // Use the same pattern as regular CAM but with valid bit.
    for (final lookupPort in lookupPorts) {
      final validTag = [Const(1), lookupPort.tag].swizzle();

      Combinational([
        Case(validTag, [
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

    // Compute next state for each storage entry combinationally.
    final nextStorageBank = <Logic>[];
    for (var entry = 0; entry < numEntries; entry++) {
      final nextEntry = Logic(name: 'next_tag_$entry', width: dataWidth + 1);
      nextStorageBank.add(nextEntry);

      final writeConditions = <Logic>[];
      final writeDataOptions = <Logic>[];
      for (final wrPort in wrPorts) {
        writeConditions.add(wrPort.en & wrPort.addr.eq(entry));
        writeDataOptions.add([Const(1), wrPort.data].swizzle());
      }
      final anyWrite = writeConditions.isNotEmpty
          ? writeConditions.reduce((a, b) => a | b)
          : Const(0);
      final writeData = writeDataOptions.isNotEmpty
          ? writeDataOptions.first
          : Const(0, width: dataWidth + 1);

      // Check for invalidation
      final invalidateConditions = <Logic>[];
      for (var i = 0; i < lookupPorts.length; i++) {
        final validTag = [Const(1), lookupPorts[i].tag].swizzle();
        final tagMatches = _storageBank[entry].eq(validTag);
        final shouldInvalidate = lookupPorts[i].invalidate & tagMatches;
        invalidateConditions.add(shouldInvalidate);
      }
      final anyInvalidate = invalidateConditions.isNotEmpty
          ? invalidateConditions.reduce((a, b) => a | b)
          : Const(0);

      nextEntry <=
          mux(
              anyInvalidate,
              // Invalidate: clear valid bit.
              [Const(0), _storageBank[entry].slice(dataWidth - 1, 0)].swizzle(),
              // Otherwise: write if enabled, else hold current value.
              mux(anyWrite, writeData, _storageBank[entry]));
    }

    Sequential(clk, [
      If(reset, then: [
        // Clear all tags (including valid bit in MSB)
        ..._storageBank
            .mapIndexed((i, e) => e < Const(0, width: dataWidth + 1)),
      ], orElse: [
        // Transfer computed next state to storage
        for (var entry = 0; entry < numEntries; entry++)
          _storageBank[entry] < nextStorageBank[entry],
      ]),
    ]);
  }

  @override
  int get readLatency => 0;
}
