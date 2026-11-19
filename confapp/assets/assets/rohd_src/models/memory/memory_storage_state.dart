// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_storage_state.dart
// State adapter for existing memory storage.
//
// 2026 October 16
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';

/// Immutable sparse state containing explicit words and symbolic writes.
///
/// Symbolic writes represent uncertainty at potentially unallocated words.
class MemoryStorageImage {
  /// Explicitly stored words.
  final Map<BigInt, LogicValue> entries;

  /// Uncertain-address writes retained by the snapshot.
  final List<UncertainMemoryWrite> uncertainWrites;

  /// Address-mapping identity when [uncertainWrites] is nonempty.
  final String? symbolicAddressMappingId;

  /// Creates a detached image.
  MemoryStorageImage(Map<int, LogicValue> entries,
      {Iterable<UncertainMemoryWrite> uncertainWrites = const [],
      this.symbolicAddressMappingId})
      : entries = Map.unmodifiable(
            entries.map((key, value) => MapEntry(BigInt.from(key), value))),
        uncertainWrites = List.unmodifiable(uncertainWrites) {
    _validateSymbolicMapping();
  }

  /// Creates an image with arbitrary-width addresses.
  MemoryStorageImage.wide(Map<BigInt, LogicValue> entries,
      {Iterable<UncertainMemoryWrite> uncertainWrites = const [],
      this.symbolicAddressMappingId})
      : entries = Map.unmodifiable(entries),
        uncertainWrites = List.unmodifiable(uncertainWrites) {
    _validateSymbolicMapping();
  }

  void _validateSymbolicMapping() {
    if (uncertainWrites.isNotEmpty &&
        (symbolicAddressMappingId == null ||
            symbolicAddressMappingId!.isEmpty)) {
      throw ArgumentError('Symbolic writes require an address-mapping ID.');
    }
  }
}

/// Raw state adapter for existing storage without changing its legacy API.
///
/// Addresses are storage words. This bypasses address-alignment and invalid
/// transaction callbacks; absent entries remain absent, distinct from stored X.
/// It does not provide RAM timing or a behavioral SystemC memory engine.
class MemoryStorageState implements MemoryStateAccess<MemoryStorageImage> {
  /// Existing storage whose state is accessed.
  final MemoryStorage storage;

  /// Wraps [storage] without constructing or modifying hardware.
  MemoryStorageState(this.storage);

  LogicValue _address(BigInt address) {
    if (address.isNegative || address >= BigInt.one << storage.addrWidth) {
      throw RangeError('Address $address is outside storage geometry.');
    }
    return LogicValue.ofBigInt(address, storage.addrWidth);
  }

  void _validate(BigInt address, LogicValue value) {
    _address(address);
    if (value.width != storage.dataWidth) {
      throw ArgumentError('Memory value width does not match storage.');
    }
  }

  @override
  LogicValue? peek(int address) => peekBigInt(BigInt.from(address));

  @override
  LogicValue? peekBigInt(BigInt address) => storage.getData(_address(address));

  @override
  void poke(int address, LogicValue value) =>
      pokeBigInt(BigInt.from(address), value);

  @override
  void pokeBigInt(BigInt address, LogicValue value) {
    _validate(address, value);
    storage.setData(_address(address), normalizeStoredValue(value));
  }

  @override
  MemoryStorageImage snapshot() {
    final target = storage;
    final symbolic = target is SymbolicMemoryStorage
        ? target as SymbolicMemoryStorage
        : null;
    final writes = symbolic?.uncertainWrites ?? const [];
    return MemoryStorageImage.wide(
      {
        for (final address in storage.addresses)
          address.toBigInt(): storage.getData(address) ??
              (throw StateError('Storage enumerated an absent address.')),
      },
      uncertainWrites: writes,
      symbolicAddressMappingId:
          writes.isEmpty ? null : symbolic!.symbolicAddressMappingId,
    );
  }

  @override
  void load(MemoryStorageImage image, {bool replace = false}) {
    for (final entry in image.entries.entries) {
      _validate(entry.key, entry.value);
    }
    if (image.uncertainWrites.isNotEmpty) {
      final target = storage;
      if (target is! SymbolicMemoryStorage) {
        throw UnsupportedError(
            'This storage cannot restore symbolic uncertain writes.');
      }
      final symbolic = target as SymbolicMemoryStorage;
      if (symbolic.symbolicAddressMappingId != image.symbolicAddressMappingId) {
        throw ArgumentError('Symbolic address mappings do not match.');
      }
      symbolic.loadSymbolicState(
        {
          for (final entry in image.entries.entries)
            _address(entry.key): entry.value
        },
        image.uncertainWrites,
        replace: replace,
      );
      return;
    }
    if (replace) {
      storage.reset();
    }
    for (final entry in image.entries.entries) {
      storage.setData(_address(entry.key), normalizeStoredValue(entry.value));
    }
  }
}
