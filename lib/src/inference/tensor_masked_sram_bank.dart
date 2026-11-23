// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Single-port byte-masked SRAM with pipelined, retained read responses.
///
/// Writes take priority over reads and commit on acceptance, even for partial
/// masks. Each byte is backed by an independent single-port SRAM. Read data
/// and tags are returned in order and held under response backpressure. A
/// zero-mask write is accepted and still occupies the port.
///
/// The array is uninitialized. Reset cancels in-flight reads and responses
/// but does not clear the SRAM. Quiesce before reset if reads must complete.
/// {@category Inference}
class TensorMaskedSramBank extends Module {
  /// Input read requests.
  late final ValidThenReadyInterface<TensorScratchpadReadRequest> reads;

  /// Input byte-masked writes.
  late final ValidThenReadyInterface<ByteMaskedWriteRequest> writes;

  /// Retained read responses.
  late final IrrevocableReadyValidInterface<TensorScratchpadReadResponse>
      responses;

  /// An SRAM response could not be retained.
  Logic get responseOverflow => output('responseOverflow');

  /// Creates one SRAM bank with [depth] power-of-two entries.
  TensorMaskedSramBank({
    required Logic clk,
    required Logic reset,
    required ValidThenReadyInterface<TensorScratchpadReadRequest> reads,
    required ValidThenReadyInterface<ByteMaskedWriteRequest> writes,
    required ReadyValidInterface<TensorScratchpadReadResponse> responses,
    required int depth,
    MemoryArrayFunctor<Logic>? memoryArray,
    super.name = 'tensor_masked_sram_bank',
  }) : super(
          definitionName: 'TensorMaskedSramBank_D${depth}_'
              'W${writes.data.dataWidth}_T${reads.data.tagWidth}_'
              '${memoryArray?.identity ?? 'inferredSram1p'}',
        ) {
    if (depth < 2 ||
        (depth & (depth - 1)) != 0 ||
        reads.data.addressWidth != depth.log2Ceil ||
        writes.data.addressWidth != depth.log2Ceil ||
        writes.data.dataWidth != responses.data.dataWidth ||
        reads.data.tagWidth != responses.data.tagWidth) {
      throw ArgumentError('Invalid SRAM bank geometry or payload widths.');
    }
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    this.reads = addPairInterface(reads, PairRole.consumer,
        uniquify: (original) => 'read_$original');
    this.writes = addPairInterface(writes, PairRole.consumer,
        uniquify: (original) => 'write_$original');
    this.responses = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(responses.data.clone()),
      responses,
      PairRole.provider,
      uniquify: (original) => 'response_$original',
    );

    final rawValid = Logic(name: 'rawValid');
    final rawTag = Logic(name: 'rawTag', width: reads.data.tagWidth);
    final ingress =
        ReadyAndValidInterface(responses.data.clone(name: 'bankResponse'));
    final egress =
        ReadyAndValidInterface(responses.data.clone(name: 'bankResponse'));
    final queue = ReadyValidQueue<TensorScratchpadReadResponse>(
      clk: clk,
      reset: reset,
      upstream: ingress,
      downstream: egress,
      depth: 1,
      policy: ReadyValidQueuePolicy.fallThrough,
      name: '${name}_responses',
    );
    egress.ready <= this.responses.ready;
    this.responses.valid <= egress.valid & ~reset;
    this.responses.data <= egress.data;
    ingress.valid <= rawValid & ~reset;
    ingress.data.tag <= rawTag;
    ingress.data.error <= Const(0);

    final remaining = queue.occupancy.zeroExtend(2) +
        ingress.accepted.zeroExtend(2) -
        egress.accepted.zeroExtend(2);
    this.writes.ready <= ~reset;
    this.reads.ready <= remaining.eq(0) & ~this.writes.valid & ~reset;
    final readAccepted = this.reads.accepted;
    final writeAccepted = this.writes.accepted;
    final bytes = <Logic>[];
    for (var byte = 0; byte < writes.data.dataWidth ~/ 8; byte++) {
      final read = DataPortInterface<Logic>(8, reads.data.addressWidth);
      final write = DataPortInterface<Logic>(8, reads.data.addressWidth);
      read.en <= readAccepted;
      read.addr <= this.reads.data.address;
      write.en <= writeAccepted & this.writes.data.byteEnable[byte];
      write.addr <= this.writes.data.address;
      write.data <= this.writes.data.data.getRange(byte * 8, (byte + 1) * 8);
      (memoryArray ?? inferredSramArray<Logic>())(
        clk: clk,
        reset: reset,
        writePorts: [write],
        readPorts: [read],
        entryCount: depth,
        readLatency: 1,
        maxConcurrentReads: 1,
        maxConcurrentWrites: 1,
        maxConcurrentAccesses: 1,
        name: '${name}_byte_$byte',
      );
      bytes.add(read.data);
    }
    ingress.data.data <= bytes.rconcat();
    addOutput('responseOverflow') <= ingress.valid & ~ingress.ready;
    Sequential(clk, reset: reset, resetValues: {
      rawValid: 0,
      rawTag: 0,
    }, [
      rawValid < readAccepted,
      If(readAccepted, then: [rawTag < this.reads.data.tag]),
    ]);
  }
}
