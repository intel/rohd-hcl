// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fully_associative_cache.dart
// Fully associative cache implementation using CAM for tag lookup.
//
// 2025 October 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A fully associative cache that uses CAM for tag lookup.
///
/// In a fully associative cache, any address can be stored in any cache line.
/// There is no set indexing - the entire address is used as the tag. This
/// provides maximum flexibility in placement but requires searching all
/// entries for a match, which is efficiently done using a CAM (Content
/// Addressable Memory).
///
/// Key characteristics:
/// - No set indexing: entire address is the tag
/// - Uses CAM for parallel tag search across all entries
/// - Replacement policy manages all [numEntries] ways globally
/// - More flexible placement than set-associative caches
/// - Potentially lower conflict misses but higher hardware complexity
class FullyAssociativeReadCache extends Cache {
  /// The number of entries in the cache.
  /// In a fully associative cache, this equals the number of ways.
  final int numEntries;

  /// Constructs a [FullyAssociativeReadCache] with CAM-based tag lookup.
  ///
  /// Defines a fully associative cache with [numEntries] lines. Each address
  /// can be stored in any entry. The [replacement] policy is used to choose
  /// which entry to evict on a fill miss.
  ///
  /// Example:
  /// ```dart
  /// final cache = FullyAssociativeReadCache(
  ///   clk, reset,
  ///   [fillPort], [readPort],
  ///   numEntries: 16,
  ///   replacement: PseudoLRUReplacement.new,
  /// );
  /// ```
  FullyAssociativeReadCache(
    super.clk,
    super.reset,
    super.fills,
    super.reads, {
    this.numEntries = 16,
    super.replacement,
  }) : super(ways: numEntries, lines: 1);

  @override
  void buildLogic() {
    final numReads = reads.length;
    final numFills = fills.length;
    final tagWidth = reads[0].addrWidth;

    // Create CAM for tag storage with valid bits
    // Each fill port needs a write port to the CAM
    final camWritePorts = [
      for (var i = 0; i < numFills; i++)
        DataPortInterface(tagWidth, log2Ceil(numEntries))
    ];

    // Each read and fill port needs a lookup port to the CAM
    final camLookupPorts = [
      for (var i = 0; i < numReads + numFills; i++)
        TagInvalidateInterface(log2Ceil(numEntries), tagWidth)
    ];

    CamInvalidate(clk, reset, camWritePorts, camLookupPorts,
        numEntries: numEntries, enableValidTracking: true);

    // Create data storage using register file
    final dataRfWritePorts = [
      for (var i = 0; i < numFills; i++)
        DataPortInterface(dataWidth, log2Ceil(numEntries))
    ];
    final dataRfReadPorts = [
      for (var i = 0; i < numReads; i++)
        DataPortInterface(dataWidth, log2Ceil(numEntries))
    ];

    RegisterFile(
      clk,
      reset,
      dataRfWritePorts,
      dataRfReadPorts,
      numEntries: numEntries,
      name: 'data_rf',
    );

    // Replacement policy - single "line" (line 0) manages all entries
    final policyHitPorts = _genReplacementAccesses(
        List.generate(numReads + numFills, (i) => reads[0]),
        prefix: 'rp_hit');
    final policyAllocPorts =
        _genReplacementAccesses(fills, prefix: 'rp_alloc');
    final policyInvalPorts =
        _genReplacementAccesses(fills, prefix: 'rp_inval');

    replacement(
      clk,
      reset,
      policyHitPorts[0],
      policyAllocPorts[0],
      policyInvalPorts[0],
      name: 'replacement_policy',
      ways: numEntries,
    );

    // Handle fill operations
    for (var fillIdx = 0; fillIdx < numFills; fillIdx++) {
      final fillPort = fills[fillIdx];
      final camWrPort = camWritePorts[fillIdx];
      final camLookupPort = camLookupPorts[numReads + fillIdx];
      final dataWrPort = dataRfWritePorts[fillIdx];

      // Lookup in CAM to check if tag exists
      camLookupPort.en <= fillPort.en;
      camLookupPort.tag <= fillPort.addr;

      final hit = camLookupPort.hit;
      final hitIdx = camLookupPort.idx;

      // Track hits, misses, and invalidates for replacement policy
      // and write to CAM and data RF based on hit/miss/invalidate
      Combinational([
        // Default values
        policyHitPorts[0][numReads + fillIdx].access < Const(0),
        policyAllocPorts[0][fillIdx].access < Const(0),
        policyInvalPorts[0][fillIdx].access < Const(0),
        camWrPort.en < Const(0),
        camWrPort.addr < Const(0, width: log2Ceil(numEntries)),
        camWrPort.data < Const(0, width: tagWidth),
        dataWrPort.en < Const(0),
        dataWrPort.addr < Const(0, width: log2Ceil(numEntries)),
        dataWrPort.data < Const(0, width: dataWidth),
        camLookupPort.invalidate < Const(0),
        If(fillPort.en, then: [
          If.block([
            // Fill with hit: update existing entry data
            Iff(fillPort.valid & hit, [
              policyHitPorts[0][numReads + fillIdx].access < Const(1),
              policyHitPorts[0][numReads + fillIdx].way < hitIdx,
              dataWrPort.en < Const(1),
              dataWrPort.addr < hitIdx,
              dataWrPort.data < fillPort.data,
            ]),
            // Fill with miss: allocate new entry (both CAM tag and data)
            ElseIf(fillPort.valid & ~hit, [
              policyAllocPorts[0][fillIdx].access < Const(1),
              camWrPort.en < Const(1),
              camWrPort.addr <
                  policyAllocPorts[0][fillIdx].way.slice(
                      log2Ceil(numEntries) - 1, 0),
              camWrPort.data < fillPort.addr,
              dataWrPort.en < Const(1),
              dataWrPort.addr <
                  policyAllocPorts[0][fillIdx].way.slice(
                      log2Ceil(numEntries) - 1, 0),
              dataWrPort.data < fillPort.data,
            ]),
            // Invalidate: remove entry from CAM (set invalidate signal)
            ElseIf(~fillPort.valid & hit, [
              policyInvalPorts[0][fillIdx].access < Const(1),
              policyInvalPorts[0][fillIdx].way < hitIdx,
              camLookupPort.invalidate < Const(1),
            ]),
          ])
        ])
      ]);
    }

    // Handle read operations
    for (var readIdx = 0; readIdx < numReads; readIdx++) {
      final readPort = reads[readIdx];
      final camLookupPort = camLookupPorts[readIdx];
      final dataRdPort = dataRfReadPorts[readIdx];

      // Lookup in CAM
      camLookupPort.en <= readPort.en;
      camLookupPort.tag <= readPort.addr;
      camLookupPort.invalidate <= Const(0); // Never invalidate on read

      final hit = camLookupPort.hit;
      final hitIdx = camLookupPort.idx;

      // Update replacement policy on hit
      policyHitPorts[0][readIdx].access <= readPort.en & hit;
      policyHitPorts[0][readIdx].way <= hitIdx;

      // Read data from register file
      Combinational([
        dataRdPort.en < Const(0),
        dataRdPort.addr < Const(0, width: log2Ceil(numEntries)),
        readPort.data < Const(0, width: dataWidth),
        readPort.valid < Const(0),
        If(readPort.en & hit, then: [
          dataRdPort.en < Const(1),
          dataRdPort.addr < hitIdx,
          readPort.data < dataRdPort.data,
          readPort.valid < Const(1),
        ])
      ]);
    }
  }

  /// Generate a 2D list of [AccessInterface]s for the replacement policy.
  /// Returns [lines][ports] where lines is always 1 for fully associative.
  List<List<AccessInterface>> _genReplacementAccesses(
      List<DataPortInterface> ports,
      {String prefix = 'replace'}) {
    final dataPorts = [
      [for (var i = 0; i < ports.length; i++) AccessInterface(numEntries)]
    ];

    for (var r = 0; r < ports.length; r++) {
      dataPorts[0][r].access.named('${prefix}_port${r}_access');
      dataPorts[0][r].way.named('${prefix}_port${r}_way');
    }
    return dataPorts;
  }

  @override
  Logic getTag(Logic addr) => addr; // Entire address is the tag

  @override
  Logic getLine(Logic addr) =>
      Const(0); // No line indexing in fully associative
}
