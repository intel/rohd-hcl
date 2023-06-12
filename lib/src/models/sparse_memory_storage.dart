// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sparse_memory_storage.dart
// Implementation of memory storage.
//
// 2023 June 12

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// A storage for memory models.
abstract class MemoryStorage {
  /// Reads a verilog-compliant hex file and preloads memory with it.
  ///
  /// Example input format:
  /// ```
  /// @80000000
  /// B3 02 00 00 33 05 00 00 B3 05 00 00 13 05 F5 1F
  /// 6F 00 40 00 93 02 10 00 17 03 00 00 13 03 83 02
  /// 23 20 53 00 6F 00 00 00
  /// @80000040
  /// 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  /// 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  /// ```
  void loadMemHex(String hexMemContents);

  /// Resets all memory to initial state.
  void reset();

  /// Loads [data] into [addr].
  void setData(LogicValue addr, LogicValue data);

  /// Returns the data at [addr], or `null` if it is not present.
  LogicValue? getData(LogicValue addr);

  /// Returns true if there is no data stored in this memory.
  bool get isEmpty;
}

/// A sparse storage for memory models.
class SparseMemoryStorage extends MemoryStorage {
  final Map<LogicValue, LogicValue> _memory = {};

  /// The width of addresses.
  final int addrWidth;

  /// Constructs a new sparse memory storage with specified [addrWidth] for all
  /// addresses.
  SparseMemoryStorage({required this.addrWidth});

  @override
  void loadMemHex(String hexMemContents) {
    /// The number of bytes per cacheline.
    const lineBytes = 4;

    var address = 0;
    var bytes = <String>[];

    void addByte(String byte) {
      bytes.add(byte);
      if (bytes.length == lineBytes) {
        final lvData = LogicValue.ofBigInt(
            BigInt.parse(bytes.reversed.join(), radix: 16), lineBytes * 8);
        final addr = LogicValue.ofInt(address - address % lineBytes, addrWidth);
        setData(addr, lvData);
        bytes = [];
      }
    }

    List<String> reconstruct(LogicValue data) {
      final out = <String>[];
      for (var counter = 0; counter < lineBytes; counter++) {
        out.add(data
            .getRange(counter * 8, (counter + 1) * 8)
            .toInt()
            .toRadixString(16)
            .padLeft(2, '0'));
      }

      return out;
    }

    for (var line in hexMemContents.split('\n')) {
      line = line.trim();
      if (line.startsWith('@')) {
        // pad out remaining bytes as 0
        // add that many to address
        if (bytes.isNotEmpty) {
          final thres = lineBytes - bytes.length;
          for (var i = 0; i < thres; i++) {
            addByte('00');
            address++;
          }
        }

        // check to see if this block already exists in memory
        final lineAddr = int.parse(line.substring(1), radix: 16);
        final lineAddrLv =
            LogicValue.ofInt(lineAddr - lineAddr % lineBytes, addrWidth);
        if (_memory.containsKey(lineAddrLv)) {
          // must reconstruct the bytes array ending at the provided address
          final endOff = lineAddr % lineBytes;
          final origData = getData(lineAddrLv);
          final newData = reconstruct(origData!).sublist(0, endOff);
          bytes = newData;
        }

        address = lineAddr;
      } else {
        for (final byte in line.split(RegExp(r'\s'))) {
          addByte(byte);
          address++;
        }
      }
    }
    // pad out remaining bytes as 0
    // add that many to address
    final thres = lineBytes - bytes.length;
    if (bytes.isNotEmpty) {
      for (var i = 0; i < thres; i++) {
        addByte('00');
        address++;
      }
    }
  }

  @override
  void setData(LogicValue addr, LogicValue data) {
    if (!addr.isValid) {
      throw RohdHclException('Can only write to valid addresses.');
    }

    _memory[addr] = data;
  }

  @override
  LogicValue? getData(LogicValue addr) => _memory[addr];

  @override
  void reset() => _memory.clear();

  @override
  bool get isEmpty => _memory.isEmpty;
}
