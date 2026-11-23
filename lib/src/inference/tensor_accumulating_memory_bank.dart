// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/addition/adder.dart';
import 'package:rohd_hcl/src/memory/contracts/memory.dart';
import 'package:rohd_hcl/src/memory/contracts/memory_array.dart';
import 'package:rohd_hcl/src/memory/storage/inferred_sram.dart';

/// Serialized, byte-masked tensor storage with optional lane-wise accumulation.
///
/// Full overwrites commit on acceptance. Partial writes and accumulated writes
/// perform a read-modify-write; subsequent requests are stalled until commit.
/// A zero mask is an accepted no-op. Accumulation wraps independently in each
/// `laneWidth`-bit lane, then the byte mask selects which bytes to update.
/// Read responses retain their data and tag until accepted. Writes have
/// priority over reads when both are presented while idle.
///
/// The default backing is an uninitialized, single-port inferred SRAM. The
/// caller must initialize data before reading or accumulating it. Reset
/// abandons any pending operation and response, so callers must quiesce the
/// bank before reset when accepted operations must complete. Storage reset
/// behavior is determined by the selected memory-array factory.
/// {@category Inference}
class TensorAccumulatingMemoryBank extends Module {
  /// Whether a write can be accepted.
  Logic get writeReady => output('writeReady');

  /// Whether a read can be accepted.
  Logic get readReady => output('readReady');

  /// Whether a retained response is available.
  Logic get responseValid => output('responseValid');

  /// Data from the retained read.
  Logic get responseData => output('responseData');

  /// Tag from the accepted read.
  Logic get responseTag => output('responseTag');

  /// High while an accepted read-modify-write has yet to commit.
  Logic get writePending => output('writePending');

  /// Creates a single-bank storage engine.
  ///
  /// [depth] must be a power of two greater than one. [writeData] contains
  /// packed lanes, with lane zero in the least significant bits. [writeMask]
  /// has one bit per byte, with bit zero selecting the least significant byte.
  TensorAccumulatingMemoryBank({
    required Logic clk,
    required Logic reset,
    required Logic writeValid,
    required Logic writeAddress,
    required Logic writeData,
    required Logic writeMask,
    required Logic writeAccumulate,
    required Logic readValid,
    required Logic readAddress,
    required Logic readTag,
    required Logic responseReady,
    required int depth,
    required int laneWidth,
    MemoryArrayFunctor<Logic>? memoryArray,
    super.name = 'tensor_accumulating_memory_bank',
  }) : super(
          definitionName: 'TensorAccumulatingMemoryBank_D${depth}_'
              'W${writeData.width}_L${laneWidth}_T${readTag.width}_'
              '${memoryArray?.identity ?? 'inferredSram1p'}',
        ) {
    if (depth < 2 || (depth & (depth - 1)) != 0) {
      throw ArgumentError(
          'Bank depth must be a power of two greater than one.');
    }
    if (laneWidth < 8 ||
        laneWidth % 8 != 0 ||
        writeData.width % laneWidth != 0 ||
        writeMask.width != writeData.width ~/ 8 ||
        writeAddress.width != depth.log2Ceil ||
        readAddress.width != depth.log2Ceil) {
      throw ArgumentError('Invalid bank lane, mask, or address geometry.');
    }
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    writeValid = addInput('writeValid', writeValid);
    writeAddress =
        addInput('writeAddress', writeAddress, width: writeAddress.width);
    writeData = addInput('writeData', writeData, width: writeData.width);
    writeMask = addInput('writeMask', writeMask, width: writeMask.width);
    writeAccumulate = addInput('writeAccumulate', writeAccumulate);
    readValid = addInput('readValid', readValid);
    readAddress =
        addInput('readAddress', readAddress, width: readAddress.width);
    readTag = addInput('readTag', readTag, width: readTag.width);
    responseReady = addInput('responseReady', responseReady);

    final idle = Const(0, width: 2);
    final commit = Const(1, width: 2);
    final response = Const(2, width: 2);
    final state = Logic(name: 'state', width: 2);
    final savedAddress = Logic(name: 'savedAddress', width: writeAddress.width);
    final savedData = Logic(name: 'savedData', width: writeData.width);
    final savedMask = Logic(name: 'savedMask', width: writeMask.width);
    final savedAccumulate = Logic(name: 'savedAccumulate');
    final savedTag = Logic(name: 'savedTag', width: readTag.width);
    final canWrite = state.eq(idle) & ~reset;
    final canRead = canWrite & ~writeValid;
    final acceptWrite = canWrite & writeValid;
    final acceptRead = canRead & readValid;
    final anyMask = writeMask.or();
    final rmw = anyMask & (writeAccumulate | ~writeMask.and());

    final memoryRead =
        DataPortInterface<Logic>(writeData.width, readAddress.width);
    final memoryWrite =
        DataPortInterface<Logic>(writeData.width, writeAddress.width);
    memoryRead.en <= acceptRead | (acceptWrite & rmw);
    memoryRead.addr <= mux(acceptWrite, writeAddress, readAddress);
    memoryWrite.en <=
        (state.eq(commit) & ~reset) | (acceptWrite & anyMask & ~rmw);
    memoryWrite.addr <= mux(state.eq(commit), savedAddress, writeAddress);

    final newLanes = <Logic>[];
    for (var lane = 0; lane < writeData.width ~/ laneWidth; lane++) {
      final start = lane * laneWidth;
      final previous = memoryRead.data.getRange(start, start + laneWidth);
      final incoming = savedData.getRange(start, start + laneWidth);
      final sum = NativeAdder(previous, incoming, name: '${name}_add_$lane')
          .sum
          .getRange(0, laneWidth);
      newLanes.add(mux(savedAccumulate, sum, incoming));
    }
    final modified = newLanes.rconcat();
    final merged = [
      for (var byte = 0; byte < writeMask.width; byte++)
        mux(
          savedMask[byte],
          modified.getRange(byte * 8, (byte + 1) * 8),
          memoryRead.data.getRange(byte * 8, (byte + 1) * 8),
        ),
    ].rconcat();
    memoryWrite.data <= mux(state.eq(commit), merged, writeData);
    (memoryArray ?? inferredSramArray<Logic>())(
      clk: clk,
      reset: reset,
      writePorts: [memoryWrite],
      readPorts: [memoryRead],
      entryCount: depth,
      readLatency: 1,
      maxConcurrentReads: 1,
      maxConcurrentWrites: 1,
      maxConcurrentAccesses: 1,
      name: '${name}_storage',
    );

    addOutput('writeReady') <= canWrite;
    addOutput('readReady') <= canRead;
    addOutput('responseValid') <= state.eq(response) & ~reset;
    addOutput('responseData', width: writeData.width) <= memoryRead.data;
    addOutput('responseTag', width: readTag.width) <= savedTag;
    addOutput('writePending') <= state.eq(commit) & ~reset;

    Sequential(clk, reset: reset, resetValues: {
      state: 0,
      savedAddress: 0,
      savedData: 0,
      savedMask: 0,
      savedAccumulate: 0,
      savedTag: 0,
    }, [
      If(acceptWrite & rmw, then: [
        savedAddress < writeAddress,
        savedData < writeData,
        savedMask < writeMask,
        savedAccumulate < writeAccumulate,
        state < commit,
      ]),
      If(acceptRead, then: [
        savedTag < readTag,
        state < response,
      ]),
      If(state.eq(commit) | (state.eq(response) & responseReady), then: [
        state < idle,
      ]),
    ]);
  }
}
