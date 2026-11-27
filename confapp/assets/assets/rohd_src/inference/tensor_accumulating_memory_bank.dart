// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_accumulating_memory_bank.dart
// Byte-masked tensor storage with lane-wise accumulation.
//
// 2026 November 23
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/addition/adder.dart';
import 'package:rohd_hcl/src/flow_control/attachments/directional_attachments.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/inference/tensor_scratchpad.dart';
import 'package:rohd_hcl/src/interfaces/interface_port_helpers.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/memory/contracts/byte_masked_write_request.dart';
import 'package:rohd_hcl/src/memory/contracts/memory.dart';
import 'package:rohd_hcl/src/memory/contracts/memory_array.dart';
import 'package:rohd_hcl/src/memory/storage/inferred_sram.dart';

/// Serialized, byte-masked tensor storage with optional lane-wise accumulation.
///
/// Drive synchronous write/read actions only when [canWrite]/[canRead] permit
/// them. Full overwrites commit on that edge. Partial writes and accumulation
/// perform a read-modify-write; no further action is legal until commit.
/// A zero mask is a no-op. Accumulation wraps independently in each
/// `laneWidth`-bit lane, then the byte mask selects which bytes to update.
/// Read responses retain their data and tag until consumed. Writes have
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
  Logic get canWrite => output('canWrite');

  /// Whether a read can be accepted.
  Logic get canRead => output('canRead');

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
    required Logic write,
    required Logic writeAddress,
    required Logic writeData,
    required Logic writeMask,
    required Logic writeAccumulate,
    required Logic read,
    required Logic readAddress,
    required Logic readTag,
    required int depth,
    required int laneWidth,
    Logic? consumeResponse,
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
    write = addInput('write', write);
    writeAddress =
        addInput('writeAddress', writeAddress, width: writeAddress.width);
    writeData = addInput('writeData', writeData, width: writeData.width);
    writeMask = addInput('writeMask', writeMask, width: writeMask.width);
    writeAccumulate = addInput('writeAccumulate', writeAccumulate);
    read = addInput('read', read);
    readAddress =
        addInput('readAddress', readAddress, width: readAddress.width);
    readTag = addInput('readTag', readTag, width: readTag.width);
    consumeResponse = addInput('consumeResponse', consumeResponse ?? Const(1));

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
    final canRead = canWrite & ~write;
    final acceptWrite = canWrite & write;
    final acceptRead = canRead & read;
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

    addOutput('canWrite') <= canWrite;
    addOutput('canRead') <= canRead;
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
      If(state.eq(commit) | (state.eq(response) & consumeResponse), then: [
        state < idle,
      ]),
    ]);
  }
}

/// A byte-masked write with optional lane-wise accumulation.
/// {@category Inference}
class TensorAccumulatingWriteRequest extends LogicStructure {
  /// Existing word-addressed byte-masked write payload.
  ByteMaskedWriteRequest get write => elements[0] as ByteMaskedWriteRequest;

  /// Add to previous lane values rather than overwrite them.
  Logic get accumulate => elements[1];

  /// Creates an accumulating request around an existing byte-masked schema.
  TensorAccumulatingWriteRequest(ByteMaskedWriteRequest write, {String? name})
      : super([
          cloneTypedPayload(write),
          Logic(name: 'accumulate'),
        ], name: name ?? 'tensor_accumulating_write_request');

  @override
  TensorAccumulatingWriteRequest clone({String? name}) =>
      TensorAccumulatingWriteRequest(write, name: name ?? this.name);
}

/// Ready/valid adapter around the synchronous accumulating bank.
/// {@category Inference}
class ReadyValidTensorAccumulatingMemoryBank extends Module {
  /// High while a read-modify-write has yet to commit.
  Logic get writePending => output('writePending');

  /// Attaches request and response protocols to [TensorAccumulatingMemoryBank].
  ReadyValidTensorAccumulatingMemoryBank({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<TensorAccumulatingWriteRequest> writes,
    required ReadyValidInterface<TensorScratchpadReadRequest> reads,
    required ReadyValidInterface<TensorScratchpadReadResponse<Logic>> responses,
    required int depth,
    required int laneWidth,
    MemoryArrayFunctor<Logic>? memoryArray,
    super.name = 'ready_valid_tensor_accumulating_memory_bank',
  }) : super(
          definitionName: schemaQualifiedDefinitionName(
              'ReadyValidTensorAccumulatingMemoryBank_D${depth}_L${laneWidth}_',
              [
                writes.data,
                reads.data,
                responses.data,
              ],
              suffix: '_${memoryArray?.identity ?? 'inferredSram1p'}'),
        ) {
    if (writes.data.write.dataWidth != responses.data.dataWidth ||
        reads.data.tagWidth != responses.data.tagWidth) {
      throw ArgumentError('Accumulating bank response schema must match.');
    }
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localWrites = addPairInterface(writes, PairRole.consumer,
        uniquify: (original) => 'write_$original');
    final localReads = addPairInterface(reads, PairRole.consumer,
        uniquify: (original) => 'read_$original');
    final localResponses = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(responses.data.clone()),
      responses,
      PairRole.provider,
      uniquify: (original) => 'response_$original',
    );
    final write = Logic(name: '${name}_write');
    final read = Logic(name: '${name}_read');
    final consume = Logic(name: '${name}_consume');
    final writePayload = cloneTypedPayload(localWrites.data);
    final readPayload = cloneTypedPayload(localReads.data);
    final responsePayload = cloneTypedPayload(localResponses.data);
    final core = TensorAccumulatingMemoryBank(
      clk: localClk,
      reset: localReset,
      write: write,
      writeAddress: writePayload.write.address,
      writeData: writePayload.write.data,
      writeMask: writePayload.write.byteEnable,
      writeAccumulate: writePayload.accumulate,
      read: read,
      readAddress: readPayload.address,
      readTag: readPayload.tag,
      consumeResponse: consume,
      depth: depth,
      laneWidth: laneWidth,
      memoryArray: memoryArray,
      name: '${name}_core',
    );
    ReadyValidIngressAttachmentPolicy<TensorAccumulatingWriteRequest>(
      supportsSameCycleReplacement: false,
    ).attach(
      upstream: localWrites,
      canAccept: core.canWrite,
      accept: write,
      payload: writePayload,
    );
    ReadyValidIngressAttachmentPolicy<TensorScratchpadReadRequest>(
      supportsSameCycleReplacement: false,
    ).attach(
      upstream: localReads,
      canAccept: core.canRead,
      accept: read,
      payload: readPayload,
    );
    connectPackedPayload(responsePayload.data, core.responseData);
    responsePayload.tag <= core.responseTag;
    responsePayload.error <= Const(0);
    ReadyValidEgressAttachmentPolicy<TensorScratchpadReadResponse<Logic>>()
        .attach(
      downstream: localResponses,
      offerValid: core.responseValid,
      payload: responsePayload,
      transfer: consume,
    );
    addOutput('writePending') <= core.writePending;
  }
}
