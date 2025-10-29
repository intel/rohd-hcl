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

  /// Fill interfaces which supply address and data to be filled.
  @protected
  final List<ValidDataPortInterface> fills = [];

  /// Read interfaces which return data and valid on a read.
  @protected
  final List<ValidDataPortInterface> reads = [];

  /// Eviction interfaces which return the address and data being evicted.
  @protected
  final List<ValidDataPortInterface> evictions = [];

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

  /// Clock.
  Logic get clk => input('clk');

  /// Reset.
  Logic get reset => input('reset');

  /// Constructs a [Cache] supporting multiple read and fill ports.
  ///
  /// Defines a set-associativity of [ways] and a depth or number of [lines].
  /// The total capacity of the cache is [ways]*[lines]. The [replacement]
  /// policy is used to choose which way to evict on a fill miss.
  Cache(Logic clk, Logic reset, List<ValidDataPortInterface> fills,
      List<ValidDataPortInterface> reads,
      {List<ValidDataPortInterface>? evictions,
      this.ways = 2,
      this.lines = 16,
      this.replacement = PseudoLRUReplacement.new,
      super.name = 'Cache',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : dataWidth = (fills.isNotEmpty)
            ? fills[0].dataWidth
            : (reads.isNotEmpty)
                ? reads[0].dataWidth
                : 0,
        super(
            definitionName: definitionName ??
                'Cache_WP${fills.length}'
                    '_RP${reads.length}_W${ways}_L$lines') {
    addInput('clk', clk);
    addInput('reset', reset);

    // Validate that readWithInvalidate is not used on fill ports
    for (var i = 0; i < fills.length; i++) {
      if (fills[i].hasReadWithInvalidate) {
        throw ArgumentError(
            'readWithInvalidate option is not supported on fill ports '
            '(port $i)');
      }
      this.fills.add(fills[i].clone()
        ..connectIO(this, fills[i],
            inputTags: {DataPortGroup.control, DataPortGroup.data},
            uniquify: (original) => 'cache_fill_${original}_$i'));
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
    if (evictions != null) {
      if (evictions.length != fills.length) {
        throw ArgumentError(
            'Must provide exactly one eviction port per read or fill port.');
      }
      for (var i = 0; i < evictions.length; i++) {
        this.evictions.add(evictions[i].clone()
          ..connectIO(this, evictions[i],
              outputTags: {DataPortGroup.control, DataPortGroup.data},
              uniquify: (original) => 'cache_evict_${original}_$i'));
      }
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
