// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sparse_memory_storage.dart
// Implementation of memory storage.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';
import 'package:rohd_vf/rohd_vf.dart' as vf;

/// Determines whether a physical word could be reached by an uncertain
/// logical address after applying a custom alignment function.
typedef UnknownAddressMatcher = bool Function(
    LogicValue uncertainAddress, LogicValue physicalAddress);

/// A symbolic write to all words compatible with an uncertain address.
class UncertainMemoryWrite {
  /// Logical address; X and Z bits can match either binary value.
  final LogicValue address;

  /// Bits made unknown at each matching word.
  final LogicValue affectedBits;

  /// Creates a symbolic write.
  const UncertainMemoryWrite(
      {required this.address, required this.affectedBits});
}

/// Storage capable of preserving uncertain-address writes in state images.
abstract interface class SymbolicMemoryStorage {
  /// Stable identity of the address mapping used by symbolic writes.
  String get symbolicAddressMappingId;

  /// Symbolic writes affecting potentially unallocated words.
  List<UncertainMemoryWrite> get uncertainWrites;

  /// Validates and atomically applies symbolic writes and explicit entries.
  void loadSymbolicState(
      Map<LogicValue, LogicValue> entries, List<UncertainMemoryWrite> writes,
      {bool replace = false});
}

/// A storage for memory models.
abstract class MemoryStorage {
  /// The width of addresses.
  final int addrWidth;

  /// The width of data.
  final int dataWidth;

  /// A function called when a write has uncertain control or address bits.
  ///
  /// By default, this logs a warning to the active ROHD-VF test, or prints a
  /// warning when no test is active.
  final void Function() onInvalidWrite;

  /// Default behavior for [onInvalidWrite].
  static void _defaultOnInvalidWrite() {
    const message = 'Memory received an uncertain write!';
    if (vf.Test.instance case final test?) {
      test.logger.warning(message);
    } else {
      // Keep the warning visible without a configured logger.
      // ignore: avoid_print
      print('WARNING: $message');
    }
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
    // The default callback must warn users without requiring a logging setup.
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

  /// Matcher required to interpret uncertain addresses with custom alignment.
  final UnknownAddressMatcher? unknownAddressMatcher;

  /// Stable identity for the custom symbolic address mapping.
  final String? unknownAddressMappingId;

  /// Whether address alignment was supplied by the caller.
  final bool hasCustomAddressAlignment;

  /// Default behavior for [alignAddress].
  static LogicValue _defaultAlignAddress(LogicValue addr) => addr;

  /// Constrcuts a [MemoryStorage] with specified [addrWidth] and [dataWidth].
  MemoryStorage({
    required this.addrWidth,
    required this.dataWidth,
    void Function()? onInvalidWrite = _defaultOnInvalidWrite,
    LogicValue Function(LogicValue addr, int dataWidth)? onInvalidRead,
    LogicValue Function(LogicValue addr)? alignAddress,
    this.unknownAddressMatcher,
    this.unknownAddressMappingId,
  })  : onInvalidWrite = onInvalidWrite ?? _defaultOnInvalidWrite,
        onInvalidRead = onInvalidRead ?? _defaultOnInvalidRead,
        hasCustomAddressAlignment = alignAddress != null,
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

    final bitsPerChar = radix.log2Ceil;
    final charsPerLine = dataWidth ~/ bitsPerChar;
    final addrIncrPerLine = dataWidth ~/ bitsPerAddress;
    final addressIncrement = BigInt.from(addrIncrPerLine);

    var address = BigInt.zero;
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
        final addr = LogicValue.ofBigInt(
            address - (address % addressIncrement), addrWidth);
        setData(addr, lvData);

        address += addressIncrement;
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
        final lineAddr = BigInt.parse(line.substring(1), radix: 16);
        final lineAddrLv = LogicValue.ofBigInt(
            lineAddr - lineAddr % addressIncrement, addrWidth);

        // if the address is not word-aligned, pre-fill the lower byte
        // positions so that new data lands at the correct byte offset within
        // the word.  When the word already has data (e.g. written by the
        // previous section), preserve those lower bytes; otherwise use zeros.
        final endOff = (lineAddr % addressIncrement).toInt();
        if (endOff != 0) {
          final lowerBytesCharsCount = endOff * bitsPerAddress ~/ bitsPerChar;
          final origData = getData(lineAddrLv);
          final lowerStr = origData != null
              ? origData
                  .getRange(0, endOff * bitsPerAddress)
                  .toBigInt()
                  .toRadixString(radix)
                  .padLeft(lowerBytesCharsCount, '0')
              : '0' * lowerBytesCharsCount;
          chunks.add(lowerStr);
          chunksLength += lowerStr.length;
        }

        address = lineAddrLv.toBigInt();
      } else {
        line.split(RegExp(r'\s')).forEach(addChunk);
      }
    }
    // pad out remaining bytes as 0
    padToAlignment();
  }

  /// Loads a Verilog-compliant hexadecimal memory file.
  ///
  /// Use [loadMemString] instead.
  // This was deprecated after v0.2.1 and remains supported in v0.3.0.
  // ignore: remove_deprecations_in_breaking_versions
  @Deprecated('Use `loadMemString` instead.')
  void loadMemHex(String hexMemContents) {
    loadMemString(hexMemContents);
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

    final bitsPerChar = radix.log2Ceil;

    final addrs = addresses.sorted();

    final memString = StringBuffer();

    LogicValue? currentAddr;

    for (final addr in addrs) {
      if (currentAddr != addr) {
        memString.writeln('@${addr.toBigInt().toRadixString(16)}');
        currentAddr = addr;
      }

      final data = getData(addr)!;
      memString.writeln(data
          .toBigInt()
          .toRadixString(radix)
          .padLeft(data.width ~/ bitsPerChar, '0'));
      currentAddr = currentAddr! +
          LogicValue.ofInt(dataWidth ~/ bitsPerAddress, addrWidth);
    }

    return memString.toString();
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
      writeUncertainAddress(addr, LogicValue.filled(dataWidth, LogicValue.one));
      return;
    }

    setData(alignAddress(addr), normalizeStoredValue(data));
  }

  /// Records a write that may affect any word compatible with [address].
  ///
  /// Storage implementations that cannot represent symbolic writes must
  /// override this method or explicitly report unsupported operations.
  void writeUncertainAddress(LogicValue address, LogicValue affectedBits) {
    throw UnsupportedError(
        'This memory storage does not support uncertain-address writes.');
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
class SparseMemoryStorage extends MemoryStorage
    implements SymbolicMemoryStorage {
  final Map<LogicValue, LogicValue> _memory = {};
  final List<UncertainMemoryWrite> _uncertainWrites = [];

  /// Symbolic writes affecting words not explicitly represented in storage.
  @override
  List<UncertainMemoryWrite> get uncertainWrites =>
      List.unmodifiable(_uncertainWrites);

  /// Constructs a new sparse memory storage with specified [addrWidth] for all
  /// addresses.
  SparseMemoryStorage({
    required super.addrWidth,
    required super.dataWidth,
    super.alignAddress,
    super.onInvalidRead,
    super.onInvalidWrite,
    super.unknownAddressMatcher,
    super.unknownAddressMappingId,
  });

  @override
  String get symbolicAddressMappingId {
    if (!hasCustomAddressAlignment && unknownAddressMatcher == null) {
      return 'identity';
    }
    if (unknownAddressMatcher == null ||
        unknownAddressMappingId == null ||
        unknownAddressMappingId!.isEmpty ||
        unknownAddressMappingId == 'identity') {
      throw UnsupportedError('Custom symbolic address mapping requires a '
          'matcher and a nonempty, non-identity mapping ID.');
    }
    return unknownAddressMappingId!;
  }

  void _validateUncertainWrite(UncertainMemoryWrite write) {
    if (write.address.width != addrWidth ||
        write.address.isValid ||
        write.affectedBits.width != dataWidth ||
        !write.affectedBits.isValid) {
      throw ArgumentError('Invalid uncertain memory write geometry or bits.');
    }
    symbolicAddressMappingId;
  }

  bool _matches(LogicValue pattern, LogicValue address) {
    if (unknownAddressMatcher case final matcher?) {
      return matcher(pattern, address);
    }
    for (var bit = 0; bit < addrWidth; bit++) {
      if (pattern[bit].isValid && pattern[bit] != address[bit]) {
        return false;
      }
    }
    return true;
  }

  LogicValue _applyUncertainty(LogicValue value, LogicValue affectedBits) {
    var result = value;
    for (var bit = 0; bit < dataWidth; bit++) {
      if (affectedBits[bit] == LogicValue.one) {
        result = result.withSet(bit, LogicValue.x);
      }
    }
    return result;
  }

  /// Validates and atomically applies symbolic writes and explicit entries.
  ///
  /// Explicit entries in [entries] take precedence over [writes].
  @override
  void loadSymbolicState(
      Map<LogicValue, LogicValue> entries, List<UncertainMemoryWrite> writes,
      {bool replace = false}) {
    for (final entry in entries.entries) {
      if (!entry.key.isValid ||
          entry.key.width != addrWidth ||
          entry.value.width != dataWidth) {
        throw ArgumentError('Invalid memory state entry.');
      }
    }
    writes.forEach(_validateUncertainWrite);

    final nextMemory = replace
        ? <LogicValue, LogicValue>{}
        : Map<LogicValue, LogicValue>.of(_memory);
    final nextWrites = replace
        ? <UncertainMemoryWrite>[]
        : List<UncertainMemoryWrite>.of(_uncertainWrites);
    for (final write in writes) {
      for (final address in nextMemory.keys.toList()) {
        if (_matches(write.address, address)) {
          nextMemory[address] =
              _applyUncertainty(nextMemory[address]!, write.affectedBits);
        }
      }
      nextWrites.add(write);
    }
    for (final entry in entries.entries) {
      nextMemory[entry.key] = normalizeStoredValue(entry.value);
    }
    _memory
      ..clear()
      ..addAll(nextMemory);
    _uncertainWrites
      ..clear()
      ..addAll(nextWrites);
  }

  @override
  void writeUncertainAddress(LogicValue address, LogicValue affectedBits) {
    final write =
        UncertainMemoryWrite(address: address, affectedBits: affectedBits);
    loadSymbolicState({}, [write]);
    onInvalidWrite();
  }

  @override
  LogicValue readData(LogicValue addr) {
    final aligned = alignAddress(addr);
    final stored = getData(aligned);
    if (stored != null) {
      return stored;
    }
    var result = onInvalidRead(aligned, dataWidth);
    for (final write in _uncertainWrites) {
      if (_matches(write.address, aligned)) {
        result = _applyUncertainty(result, write.affectedBits);
      }
    }
    return result;
  }

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

    _memory[addr] = normalizeStoredValue(data);
  }

  @override
  LogicValue? getData(LogicValue addr) {
    if (addr.width != addrWidth) {
      throw RohdHclException('Address width must be $addrWidth.');
    }

    return _memory[addr];
  }

  @override
  void reset() {
    _memory.clear();
    _uncertainWrites.clear();
  }

  @override
  bool get isEmpty => _memory.isEmpty && _uncertainWrites.isEmpty;

  @override
  List<LogicValue> get addresses => _memory.keys.toList();
}
