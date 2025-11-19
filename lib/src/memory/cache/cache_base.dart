// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cache_base.dart
// Base cache interface and abstract class.
//
// 2025 September 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An interface to a cache memory that supplies enable [en], address [addr],
/// [valid] for indicating a hit, and [data].
///
/// Can be used for either read or write direction by grouping signals using
/// [DataPortGroup].
class ValidDataPortInterface extends DataPortInterface {
  /// The "valid" bit for a response when the data is valid.
  Logic get valid => port('valid');

  /// The "readWithInvalidate" signal for read ports that invalidate on hit.
  /// Only available if hasReadWithInvalidate is true.
  Logic get readWithInvalidate {
    if (!hasReadWithInvalidate) {
      throw RohdHclException(
          'readWithInvalidate signal not available on this interface');
    }
    return port('readWithInvalidate');
  }

  /// Whether this interface has readWithInvalidate capability.
  final bool hasReadWithInvalidate;

  /// The name of this interface, useful for disambiguating multiple interfaces.
  late final String name;

  /// Constructs a new interface of specified [dataWidth] and [addrWidth] for
  /// interacting with a `Cache` in either the read or write direction.
  ///
  /// Set [hasReadWithInvalidate] to true to add a readWithInvalidate signal
  /// that invalidates cache entries on read hits. This should only be used
  /// for read ports, not write/fill ports.
  ValidDataPortInterface(super.dataWidth, super.addrWidth,
      {String? name, this.hasReadWithInvalidate = false})
      : super() {
    this.name = name ?? 'valid_data_port_${dataWidth}w_${addrWidth}a';

    // Add the valid port to the data group
    setPorts([
      Logic.port('valid'),
    ], [
      DataPortGroup.data
    ]);

    // Add readWithInvalidate to the control group if needed
    if (hasReadWithInvalidate) {
      setPorts([
        Logic.port('readWithInvalidate'),
      ], [
        DataPortGroup.control
      ]);
    }
  }

  /// Makes a copy of this [ValidDataPortInterface] with matching configuration.
  @override
  ValidDataPortInterface clone() => ValidDataPortInterface(dataWidth, addrWidth,
      hasReadWithInvalidate: hasReadWithInvalidate);
}

/// Composite interface grouping a fill port with an optional eviction
/// sub-interface.
///
/// Each cache fill port provides the address/data/control signals used to
/// insert or invalidate a cache entry. In some cache configurations an
/// associated eviction port is produced when a fill displaces an existing
/// entry; the eviction port provides the evicted entry's address and data so
/// that external logic (for example, a backing store) can be updated.
///
/// The `FillEvictInterface` bundles these two related interfaces together so
/// that a cache's constructor can accept a single `List<FillEvictInterface>`
/// rather than parallel lists for fills and evictions. If any
/// `FillEvictInterface` in the list provides an `eviction` sub-interface, the
/// cache requires that every entry in the list provide an eviction (the
/// all-or-none rule). This preserves the prior semantics where eviction ports
/// were parallel to fill ports.
class FillEvictInterface {
  /// The fill port used to write (or invalidate) cache entries.
  ///
  /// This is a `ValidDataPortInterface` whose `valid` signal indicates whether
  /// the write/invalidate should take place. For read-with-invalidate
  /// semantics, use the `ValidDataPortInterface.readWithInvalidate` on the
  /// cache's read ports; fill ports must NOT have `readWithInvalidate` set.
  final ValidDataPortInterface fill;

  /// Optional eviction port produced when a fill displaces an existing entry.
  ///
  /// When present, this `ValidDataPortInterface` will be driven as an output
  /// from the cache to indicate the address and data of the evicted line.
  /// Tests and higher-level integrations that do not care about evictions can
  /// omit this by leaving it null.
  final ValidDataPortInterface? eviction;

  /// Construct a `FillEvictInterface` pairing [fill] with an optional
  /// [eviction] sub-interface.
  FillEvictInterface(this.fill, [this.eviction]);

  /// Make a deep copy of this composite interface, cloning the contained
  /// `ValidDataPortInterface`s. Useful when the cache clones and connects the
  /// interfaces into its internal namespace.
  FillEvictInterface clone() =>
      FillEvictInterface(fill.clone(), eviction?.clone());
}

/// A module [Cache] implementing a configurable set-associative cache for
/// caching read operations.
///
/// Three primary operations:
/// - Reading from a cache can result in a hit or miss. The only state change is
///   that on a hit, the [replacement] policy is updated.  This is similar to a
///   memory, except that a valid bit is returned with the read data.
/// - Filling to a cache with a valid bit set results in a fill into the cache
///   memory, potentially allocating a line in a new way if the data was not
///   present. Externally, this just looks like a memory fill.
/// - Filling to a cache without the valid bit set results in an invalidate of
///   the matching line if present.
///
/// Note that filling does not result in writing of evicted data to backing
/// store, it is simply evicted.
abstract class Cache extends Module {
  /// Number of ways in the cache line, also know as associativity.
  late final int ways;

  /// Number of lines in the cache.
  late final int lines;

  /// Width of the data stored.
  late final int dataWidth;

  /// Fill interfaces which supply address and data to be filled. Each entry
  /// contains the fill port and an optional eviction sub-interface.
  @protected
  final List<FillEvictInterface> fills = [];

  /// Read interfaces which return data and valid on a read.
  @protected
  final List<ValidDataPortInterface> reads = [];

  // Evictions are provided as optional sub-interfaces on elements of
  // [fills] and so there is no separate parallel `evictions` list.

  /// The replacement policy to use for choosing which way to evict on a miss.
  @protected
  final ReplacementPolicy Function(
      Logic clk,
      Logic reset,
      List<AccessInterface> hits,
      List<AccessInterface> misses,
      List<AccessInterface> invalidates,
      {int ways,
      String name}) replacement;

  /// Per-line replacement policy instances created by subclasses.
  @protected
  late final List<ReplacementPolicy> lineReplacementPolicy;

  /// Clock.
  Logic get clk => input('clk');

  /// Reset.
  Logic get reset => input('reset');

  /// Constructs a [Cache] supporting multiple read and fill ports.
  ///
  /// Defines a set-associativity of [ways] and a depth or number of [lines].
  /// The total capacity of the cache is [ways]*[lines]. The [replacement]
  /// policy is used to choose which way to evict on a fill miss.
  Cache(Logic clk, Logic reset, List<FillEvictInterface> fills,
      List<ValidDataPortInterface> reads,
      {this.ways = 2,
      this.lines = 16,
      this.replacement = PseudoLRUReplacement.new,
      super.name = 'Cache',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : dataWidth = (fills.isNotEmpty)
            ? fills[0].fill.dataWidth
            : (reads.isNotEmpty)
                ? reads[0].dataWidth
                : 0,
        super(
            definitionName: definitionName ??
                'Cache_WP${fills.length}'
                    '_RP${reads.length}_W${ways}_L$lines') {
    addInput('clk', clk);
    addInput('reset', reset);

    // Validate and connect fill/eviction composite interfaces. If any fill
    // provides an eviction sub-interface, require that all fills provide an
    // eviction to preserve previous parallel semantics.
    final hasAnyEviction = fills.any((f) => f.eviction != null);
    if (hasAnyEviction && fills.any((f) => f.eviction == null)) {
      throw ArgumentError(
          'If eviction ports are provided, they must be supplied for all '
          'fill ports.');
    }

    for (var i = 0; i < fills.length; i++) {
      final inFill = fills[i];
      if (inFill.fill.hasReadWithInvalidate) {
        throw ArgumentError(
            'readWithInvalidate option is not supported on fill ports '
            '(port $i)');
      }
      final cloned = inFill.clone();
      cloned.fill.connectIO(this, inFill.fill,
          inputTags: {DataPortGroup.control, DataPortGroup.data},
          uniquify: (original) => 'cache_fill_${original}_$i');
      if (cloned.eviction != null) {
        cloned.eviction!.connectIO(this, inFill.eviction!,
            outputTags: {DataPortGroup.control, DataPortGroup.data},
            uniquify: (original) => 'cache_evict_${original}_$i');
      }
      this.fills.add(cloned);
    }

    for (var i = 0; i < reads.length; i++) {
      this.reads.add(reads[i].clone()
        ..connectIO(this, reads[i],
            inputTags: {
              DataPortGroup.control
            }, // Both en/addr and readWithInvalidate are control
            outputTags: {DataPortGroup.data}, // valid and data are outputs
            uniquify: (original) => 'cache_read_${original}_$i'));
    }
    buildLogic();
  }

  /// Builds the internal logic for the cache implementation.
  ///
  /// This method must be overridden by subclasses to implement the specific
  /// cache logic.
  @mustBeOverridden
  void buildLogic();

  /// Extract the tag from the address.
  Logic getTag(Logic addr) => addr.getRange(log2Ceil(lines));

  /// Extract the line index from the address.
  Logic getLine(Logic addr) => addr.slice(log2Ceil(lines) - 1, 0);
}
