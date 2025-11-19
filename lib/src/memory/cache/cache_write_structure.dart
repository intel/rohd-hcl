// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cache_write_structure.dart
// Cache write structure for CachedRequestResponseChannel external writes.
//
// 2025 November 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// A [LogicStructure] representing a cache write operation with address, data,
/// and invalidate fields.
///
/// This structure is used for external writes to the cache. When [invalidate]
/// is 1, the cache entry is invalidated. When [invalidate] is 0, the cache is
/// updated with [data] at [addr].
class CacheWriteStructure extends LogicStructure {
  /// The address field.
  Logic get addr => elements[0];

  /// The data field.
  Logic get data => elements[1];

  /// The invalidate bit (1 = invalidate, 0 = write data).
  Logic get invalidate => elements[2];

  /// Creates a [CacheWriteStructure] with the specified [addrWidth] and
  /// [dataWidth].
  CacheWriteStructure({required int addrWidth, required int dataWidth})
      : super([
          Logic(width: addrWidth, name: 'addr', naming: Naming.mergeable),
          Logic(width: dataWidth, name: 'data', naming: Naming.mergeable),
          Logic(name: 'invalidate', naming: Naming.mergeable),
        ], name: 'cacheWriteStructure');

  /// Private constructor for cloning.
  CacheWriteStructure._fromStructure(LogicStructure original, {String? name})
      : super(original.elements.map((e) => e.clone()).toList(),
            name: name ?? original.name);

  @override
  CacheWriteStructure clone({String? name}) =>
      CacheWriteStructure._fromStructure(this, name: name);
}
