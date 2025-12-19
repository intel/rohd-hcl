// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sparse_memory_storage.dart
// Implementation of memory storage.
//
// 2023 June 12

import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';
import 'package:rohd_hcl/src/utils.dart';

/// A storage for memory models.
abstract class MemoryStorage {
  /// The width of addresses.
  final int addrWidth;

  /// The width of data.
  final int dataWidth;

  /// A function called if an invalid write is made when not [isEmpty].
  ///
  /// An invalid write will reset the entire memory after calling this function.
  ///
  /// By default, this will print a warning message.
  final void Function() onInvalidWrite;

  /// Default behavior for [onInvalidWrite].
  static void _defaultOnInvalidWrite() {
    // ignore: avoid_print
    print('WARNING: Memory was cleared by invalid write!');
  }

  /// A function called if a read is made to an address that has no data.
  ///
  /// By default, this will print a warning message and return `x`.
  ///
  /// This is *not* called when a read's valid or address has invalid bits; in
  /// those cases the memory will return `x` always.
  final LogicValue Function(LogicValue addr, int dataWidth) onInvalidRead;

  /// Default behavior for [onInvalidRead].
  static LogicValue _defaultOnInvalidRead(LogicValue addr, int dataWidth) {
    // ignore: avoid_print
    print('WARNING: reading from address $addr that has no data!');
    return LogicValue.filled(dataWidth, LogicValue.x);
  }

  /// A function to align addresses when used for transactions.
  ///
  /// By default, this will perform no modification to the address.
  ///
  /// As an example, to align (mask) addresses to multiples of 4:
  /// ```dart
  /// (addr) => addr - (addr % 4)
  /// ```
  final LogicValue Function(LogicValue addr) alignAddress;

  /// Default behavior for [alignAddress].
  static LogicValue _defaultAlignAddress(LogicValue addr) => addr;

  /// Constrcuts a [MemoryStorage] with specified [addrWidth] and [dataWidth].
  MemoryStorage({
    required this.addrWidth,
    required this.dataWidth,
    void Function()? onInvalidWrite = _defaultOnInvalidWrite,
    LogicValue Function(LogicValue addr, int dataWidth)? onInvalidRead,
    LogicValue Function(LogicValue addr)? alignAddress,
  })  : onInvalidWrite = onInvalidWrite ?? _defaultOnInvalidWrite,
        onInvalidRead = onInvalidRead ?? _defaultOnInvalidRead,
        alignAddress = alignAddress ?? _defaultAlignAddress;

  /// Reads a verilog-compliant mem file and preloads memory with it.
  ///
  /// The loaded address will increment each [dataWidth] bits of data between
  /// address `@` annotations.  Data is parsed according to the provided
  /// [radix], which must be a positive power of 2 up to 16. The address for
  /// data will increment by 1 for each [bitsPerAddress] bits of data, which
  /// must be a power of 2 less than [dataWidth].
  ///
  /// Line comments (`//`) are supported and any whitespace is supported as a
  /// separator between data.  Block comments (`/* */`) are not supported.
  ///
  /// Example input format:
  /// ```text
  /// @80000000
  /// B3 02 00 00 33 05 00 00 B3 05 00 00 13 05 F5 1F
  /// 6F 00 40 00 93 02 10 00 17 03 00 00 13 03 83 02
  /// 23 20 53 00 6F 00 00 00
  /// @80000040
  /// 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  /// 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  /// ```
  void loadMemString(String memContents,
      {int radix = 16, int bitsPerAddress = 8}) {
    if (radix <= 0 || (radix & (radix - 1) != 0) || radix > 16) {
      throw RohdHclException('Radix must be a positive power of 2 (max 16).');
    }

    if (dataWidth % bitsPerAddress != 0) {
      throw RohdHclException('dataWidth must be a multiple of bitsPerAddress.');
    }

    final bitsPerChar = log2Ceil(radix);
    final charsPerLine = dataWidth ~/ bitsPerChar;
    final addrIncrPerLine = dataWidth ~/ bitsPerAddress;

    var address = 0;
    final chunks = <String>[];
    var chunksLength = 0;

    void addChunk([String? chunk]) {
      if (chunk != null) {
        chunk = chunk.trim();

        chunks.add(chunk);
        chunksLength += chunk.length;
      }

      while (chunksLength >= charsPerLine) {
        final pendingData = chunks.reversed.join();
        final cutPoint = chunksLength - charsPerLine;
        final thisData = pendingData.substring(cutPoint);
        chunks.clear();

        final remaining = pendingData.substring(0, cutPoint);

        chunksLength = 0;

        if (remaining.isNotEmpty) {
          chunks.add(remaining);
          chunksLength = remaining.length;
        }

        final lvData = LogicValue.ofBigInt(
            BigInt.parse(thisData, radix: radix), dataWidth);
        final addr =
            LogicValue.ofInt(address - (address % addrIncrPerLine), addrWidth);
        setData(addr, lvData);

        address += addrIncrPerLine;
      }
    }

    void padToAlignment() {
      addChunk();
      while (chunksLength != 0) {
        addChunk('0');
      }
    }

    for (var line in memContents.split('\n')) {
      // if there's a `//` comment on this line, ditch everything after it
      final commentIdx = line.indexOf('//');
      if (commentIdx != -1) {
        line = line.substring(0, commentIdx);
      }

      line = line.trim();

      if (line.isEmpty) {
        continue;
      }

      if (line.startsWith('@')) {
        // pad out remaining bytes as 0
        padToAlignment();

        // if it doesn't match the format, throw
        if (!RegExp('@([0-9a-fA-F]+)').hasMatch(line)) {
          throw RohdHclException('Invalid address format: $line');
        }

        // check to see if this block already exists in memory
        final lineAddr = int.parse(line.substring(1), radix: 16);
        final lineAddrLv =
            LogicValue.ofInt(lineAddr - lineAddr % addrIncrPerLine, addrWidth);
        if (getData(lineAddrLv) != null) {
          // must reconstruct the bytes array ending at the provided address
          final endOff = lineAddr % addrIncrPerLine;
          final origData = getData(lineAddrLv);
          chunks.clear();

          if (endOff != 0) {
            chunks.add(origData!
                .getRange(0, endOff * bitsPerAddress)
                .toInt()
                .toRadixString(radix));
          }
        }

        address = lineAddrLv.toInt();
      } else {
        line.split(RegExp(r'\s')).forEach(addChunk);
      }
    }
    // pad out remaining bytes as 0
    padToAlignment();
  }

  /// Dumps the contents of memory to a verilog-compliant hex file.
  ///
  /// The address will increment each [bitsPerAddress] bits of data between
  /// address `@` annotations. Data is output according to the provided [radix],
  /// which must be a positive power of 2 up to 16.
  String dumpMemString({int radix = 16, int bitsPerAddress = 8}) {
    if (radix <= 0 || (radix & (radix - 1) != 0) || radix > 16) {
      throw RohdHclException('Radix must be a positive power of 2 (max 16).');
    }

    if (isEmpty) {
      return '';
    }

    final bitsPerChar = log2Ceil(radix);

    final addrs = addresses.sorted();

    final memString = StringBuffer();

    LogicValue? currentAddr;

    for (final addr in addrs) {
      if (currentAddr != addr) {
        memString.writeln('@${addr.toInt().toRadixString(16)}');
        currentAddr = addr;
      }

      final data = getData(addr)!;
      memString.writeln(data
          .toInt()
          .toRadixString(radix)
          .padLeft(data.width ~/ bitsPerChar, '0'));
      currentAddr = currentAddr! +
          LogicValue.ofInt(dataWidth ~/ bitsPerAddress, addrWidth);
    }

    return memString.toString();
  }

  /// Reads a verilog-compliant hex file and preloads memory with it.
  ///
  /// Example input format:
  /// ```text
  /// @80000000
  /// B3 02 00 00 33 05 00 00 B3 05 00 00 13 05 F5 1F
  /// 6F 00 40 00 93 02 10 00 17 03 00 00 13 03 83 02
  /// 23 20 53 00 6F 00 00 00
  /// @80000040
  /// 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  /// 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  /// ```
  @Deprecated('Use `loadMemString` instead.')
  void loadMemHex(String hexMemContents) {
    loadMemString(hexMemContents);
  }

  /// Resets all memory to initial state.
  void reset();

  /// Triggers behavior associated with an invalid write, including calling
  /// [onInvalidWrite] and [reset]ting all of memory.
  void invalidWrite() {
    onInvalidWrite();
    reset();
  }

  /// Performs some validation on a write, aligns the address with
  /// [alignAddress], and then calls [setData].
  void writeData(LogicValue addr, LogicValue data) {
    if (!addr.isValid) {
      if (!isEmpty) {
        invalidWrite();
      }

      return;
    }

    setData(alignAddress(addr), data);
  }

  /// Loads [data] into [addr] directly into storage.
  void setData(LogicValue addr, LogicValue data);

  /// Aligns the address with [alignAddress], then returns either the [getData]
  /// result in storage or else [onInvalidRead]'s result.
  LogicValue readData(LogicValue addr) {
    final alignedAddr = alignAddress(addr);
    return getData(alignedAddr) ?? onInvalidRead(alignedAddr, dataWidth);
  }

  /// Returns the data at [addr], or `null` if it is not present.
  LogicValue? getData(LogicValue addr);

  /// Returns `true` if there is no data stored in this memory.
  bool get isEmpty;

  /// A list of [addresses] which have data stored in this memory.
  List<LogicValue> get addresses;
}

/// A sparse storage for memory models.
class SparseMemoryStorage extends MemoryStorage {
  final Map<LogicValue, LogicValue> _memory = {};

  /// Constructs a new sparse memory storage with specified [addrWidth] for all
  /// addresses.
  SparseMemoryStorage({
    required super.addrWidth,
    required super.dataWidth,
    super.alignAddress,
    super.onInvalidRead,
    super.onInvalidWrite,
  });

  @override
  void setData(LogicValue addr, LogicValue data) {
    if (!addr.isValid) {
      throw RohdHclException('Can only write to valid addresses.');
    }

    if (addr.width != addrWidth) {
      throw RohdHclException('Address width must be $addrWidth.');
    }

    if (data.width != dataWidth) {
      throw RohdHclException('Data width must be $dataWidth.');
    }

    _memory[addr] = data;
  }

  @override
  LogicValue? getData(LogicValue addr) {
    if (addr.width != addrWidth) {
      throw RohdHclException('Address width must be $addrWidth.');
    }

    return _memory[addr];
  }

  @override
  void reset() => _memory.clear();

  @override
  bool get isEmpty => _memory.isEmpty;

  @override
  List<LogicValue> get addresses => _memory.keys.toList();
}
