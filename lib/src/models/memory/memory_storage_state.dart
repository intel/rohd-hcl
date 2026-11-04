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

/// Raw state adapter for existing storage without changing its legacy API.
///
/// Addresses are storage words. This bypasses address-alignment and invalid
/// transaction callbacks; absent entries remain absent, distinct from stored X.
/// It does not provide RAM timing or a behavioral SystemC memory engine.
class MemoryStorageState implements MemoryStateAccess<Map<int, LogicValue>> {
  /// Existing storage whose state is accessed.
  final MemoryStorage storage;

  /// Wraps [storage] without constructing or modifying hardware.
  MemoryStorageState(this.storage);

  LogicValue _address(int address) {
    if (address < 0 ||
        BigInt.from(address) >= BigInt.one << storage.addrWidth) {
      throw RangeError.value(address, 'address', 'Outside storage geometry.');
    }
    return LogicValue.ofInt(address, storage.addrWidth);
  }

  void _validate(int address, LogicValue value) {
    _address(address);
    if (value.width != storage.dataWidth) {
      throw ArgumentError('Memory value width does not match storage.');
    }
  }

  @override
  LogicValue? peek(int address) => storage.getData(_address(address));

  @override
  void poke(int address, LogicValue value) {
    _validate(address, value);
    storage.setData(_address(address), value);
  }

  @override
  Map<int, LogicValue> snapshot() => Map.unmodifiable({
        for (final address in storage.addresses)
          address.toInt(): storage.getData(address) ??
              (throw StateError('Storage enumerated an absent address.')),
      });

  @override
  void load(Map<int, LogicValue> image, {bool replace = false}) {
    for (final entry in image.entries) {
      _validate(entry.key, entry.value);
    }
    if (replace) {
      storage.reset();
    }
    for (final entry in image.entries) {
      storage.setData(_address(entry.key), entry.value);
    }
  }
}
