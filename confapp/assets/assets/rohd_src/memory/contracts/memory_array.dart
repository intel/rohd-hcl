// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_array.dart
// Capability-checked construction of fixed-timing memory arrays.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/memory/contracts/memory.dart';

/// Read behavior when a read and a write target the same entry.
enum MemoryArrayReadCollision {
  /// Asynchronous reads reflect the current stored state.
  combinational,

  /// A synchronous read returns the state before the sampling edge.
  oldData,

  /// A synchronous read returns the state after the sampling edge.
  newData,

  /// The result is not specified.
  unspecified,
}

/// Resolution of writes to the same entry and overlapping bits.
enum MemoryArrayWriteCollision {
  /// The operation is not permitted.
  disallow,

  /// The lowest-numbered write port wins overlapping bits.
  lowestPortWins,

  /// The highest-numbered write port wins overlapping bits.
  highestPortWins,

  /// The result is not specified.
  unspecified,
}

/// How a memory array participates in generated hardware.
enum MemoryArrayImplementation {
  /// Synthesizable ROHD hardware.
  synthesizable,

  /// A software-only behavioral model.
  simulationOnly,

  /// An externally supplied hardware implementation.
  external,
}

/// Fixed-timing capabilities of one memory array implementation.
///
/// The port limits describe the ports that can be instantiated. The total
/// concurrent-access limit also describes any shared physical-port constraint.
/// With raw [DataPortInterface] ports, the caller must enforce that limit.
class MemoryArrayCapabilities {
  /// Maximum instantiated read ports, or null if unbounded.
  final int? maxReadPorts;

  /// Maximum instantiated write ports, or null if unbounded.
  final int? maxWritePorts;

  /// Maximum enabled reads in a cycle, or null if unbounded.
  final int? maxConcurrentReads;

  /// Maximum enabled writes in a cycle, or null if unbounded.
  final int? maxConcurrentWrites;

  /// Maximum enabled reads plus writes in a cycle, or null if unbounded.
  final int? maxConcurrentAccesses;

  /// Fixed read latency in cycles.
  final int readLatency;

  /// Same-entry read/write behavior.
  final MemoryArrayReadCollision readCollision;

  /// Same-entry write/write behavior.
  final MemoryArrayWriteCollision writeCollision;

  /// Whether byte-masked write ports are supported.
  final bool supportsMaskedWrites;

  /// Hardware or behavioral implementation kind.
  final MemoryArrayImplementation implementation;

  /// Creates a capability declaration.
  const MemoryArrayCapabilities({
    required this.readLatency,
    required this.readCollision,
    required this.writeCollision,
    required this.supportsMaskedWrites,
    required this.implementation,
    this.maxReadPorts,
    this.maxWritePorts,
    this.maxConcurrentReads,
    this.maxConcurrentWrites,
    this.maxConcurrentAccesses,
  });

  void _validate() {
    if (readLatency < 0 ||
        (maxReadPorts != null && maxReadPorts! < 0) ||
        (maxWritePorts != null && maxWritePorts! < 0) ||
        (maxConcurrentReads != null && maxConcurrentReads! < 0) ||
        (maxConcurrentWrites != null && maxConcurrentWrites! < 0) ||
        (maxConcurrentAccesses != null && maxConcurrentAccesses! < 1) ||
        (readLatency == 0 &&
            readCollision != MemoryArrayReadCollision.combinational) ||
        (readLatency > 0 &&
            readCollision == MemoryArrayReadCollision.combinational)) {
      throw ArgumentError('Invalid memory-array capability declaration.');
    }
  }
}

/// Builds a fixed-timing memory on the supplied typed raw ports.
typedef MemoryArrayBuilder<T extends Logic> = Memory<T> Function({
  required Logic clk,
  required Logic reset,
  required List<DataPortInterface<T>> writePorts,
  required List<DataPortInterface<T>> readPorts,
  required int entryCount,
  required String name,
});

/// A capability-checked factory for typed, fixed-timing memory arrays.
class MemoryArrayFunctor<T extends Logic> {
  /// Stable SystemVerilog-safe identity for generated module names.
  final String identity;

  /// Capabilities of the selected implementation.
  final MemoryArrayCapabilities capabilities;

  // The builder must consume the same typed ports that the functor creates.
  // ignore: unsafe_variance
  final MemoryArrayBuilder<T> _build;

  /// Creates a memory-array factory.
  const MemoryArrayFunctor({
    required this.identity,
    required this.capabilities,
    required MemoryArrayBuilder<T> build,
  }) : _build = build;

  /// Validates and instantiates an array.
  ///
  /// [maxConcurrentReads] and [maxConcurrentWrites] are the maximum
  /// simultaneous demand guaranteed by the caller's scheduler, not just
  /// the number of connected ports. By default the declared maxima may occur
  /// together. [maxConcurrentAccesses] can instead specify a tighter combined
  /// limit enforced by the caller; all enabled reads and writes count.
  /// [requiredReadCollision] and
  /// [requiredWriteCollision] reject a different collision contract.
  Memory<T> call({
    required Logic clk,
    required Logic reset,
    required List<DataPortInterface<T>> writePorts,
    required List<DataPortInterface<T>> readPorts,
    required int entryCount,
    required int readLatency,
    required int maxConcurrentReads,
    required int maxConcurrentWrites,
    required String name,
    int? maxConcurrentAccesses,
    MemoryArrayReadCollision? requiredReadCollision,
    MemoryArrayWriteCollision? requiredWriteCollision,
  }) {
    capabilities._validate();
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(identity)) {
      throw ArgumentError.value(identity, 'identity',
          'Must be a valid SystemVerilog identifier fragment.');
    }
    if (clk.width != 1 ||
        reset.width != 1 ||
        entryCount < 1 ||
        (readPorts.isEmpty && writePorts.isEmpty)) {
      throw ArgumentError('Invalid memory-array clock, reset, or geometry.');
    }
    final combined =
        maxConcurrentAccesses ?? maxConcurrentReads + maxConcurrentWrites;
    if (maxConcurrentReads < 0 ||
        maxConcurrentReads > readPorts.length ||
        maxConcurrentWrites < 0 ||
        maxConcurrentWrites > writePorts.length ||
        combined < maxConcurrentReads ||
        combined < maxConcurrentWrites ||
        combined > maxConcurrentReads + maxConcurrentWrites) {
      throw ArgumentError('Invalid memory-array concurrency requirement.');
    }
    final ports = [...writePorts, ...readPorts];
    final first = ports.first;
    if (BigInt.from(entryCount) > (BigInt.one << first.addrWidth) ||
        ports.any((port) =>
            port.addrWidth != first.addrWidth ||
            !sameDeclaredPayloadShape(first.data, port.data))) {
      throw ArgumentError('Memory-array ports have incompatible geometry '
          'or payload layouts.');
    }
    if (readPorts.any((port) => port is MaskedDataPortInterface<T>)) {
      throw ArgumentError('Masked read ports are not supported.');
    }
    if ((!capabilities.supportsMaskedWrites &&
            writePorts.any((port) => port is MaskedDataPortInterface<T>)) ||
        (capabilities.maxReadPorts != null &&
            readPorts.length > capabilities.maxReadPorts!) ||
        (capabilities.maxWritePorts != null &&
            writePorts.length > capabilities.maxWritePorts!) ||
        (capabilities.maxConcurrentReads != null &&
            maxConcurrentReads > capabilities.maxConcurrentReads!) ||
        (capabilities.maxConcurrentWrites != null &&
            maxConcurrentWrites > capabilities.maxConcurrentWrites!) ||
        (capabilities.maxConcurrentAccesses != null &&
            combined > capabilities.maxConcurrentAccesses!) ||
        (requiredReadCollision != null &&
            requiredReadCollision != capabilities.readCollision) ||
        (requiredWriteCollision != null &&
            requiredWriteCollision != capabilities.writeCollision) ||
        readLatency != capabilities.readLatency) {
      throw ArgumentError('Memory-array implementation $identity does not '
          'satisfy the requested ports, concurrency, collision, masking, '
          'or latency.');
    }
    final memory = _build(
      clk: clk,
      reset: reset,
      writePorts: writePorts,
      readPorts: readPorts,
      entryCount: entryCount,
      name: name,
    );
    if (memory.numReads != readPorts.length ||
        memory.numWrites != writePorts.length ||
        memory.addrWidth != first.addrWidth ||
        memory.dataWidth != first.dataWidth ||
        memory.readLatency != readLatency ||
        !memory.reads.indexed
            .every((entry) => identical(entry.$2, readPorts[entry.$1])) ||
        !memory.writes.indexed
            .every((entry) => identical(entry.$2, writePorts[entry.$1]))) {
      throw StateError('Memory-array implementation $identity built a '
          'module that does not match the requested binding.');
    }
    return memory;
  }
}
