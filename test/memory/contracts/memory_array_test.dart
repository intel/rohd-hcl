// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_array_test.dart
// Tests capability-checked memory-array construction.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

MemoryArrayFunctor<Logic> _factory({
  int? maxConcurrentAccesses,
  int? maxConcurrentReads,
  int? maxConcurrentWrites,
  int latency = 0,
  bool masked = true,
  bool incorrectLatency = false,
}) =>
    MemoryArrayFunctor<Logic>(
      identity: 'testArray',
      capabilities: MemoryArrayCapabilities(
        readLatency: latency,
        readCollision: latency == 0
            ? MemoryArrayReadCollision.combinational
            : MemoryArrayReadCollision.newData,
        writeCollision: MemoryArrayWriteCollision.unspecified,
        supportsMaskedWrites: masked,
        implementation: MemoryArrayImplementation.simulationOnly,
        maxReadPorts: 2,
        maxWritePorts: 1,
        maxConcurrentReads: maxConcurrentReads,
        maxConcurrentWrites: maxConcurrentWrites,
        maxConcurrentAccesses: maxConcurrentAccesses,
      ),
      build: ({
        required clk,
        required reset,
        required writePorts,
        required readPorts,
        required entryCount,
        required name,
      }) =>
          MemoryModel<Logic>(clk, reset, writePorts, readPorts,
              readLatency: incorrectLatency ? latency + 1 : latency,
              name: name),
    );

void main() {
  tearDown(Simulator.reset);

  test('validates port geometry, masks, and simultaneous demand', () {
    final read = DataPortInterface<Logic>(8, 2);
    final write = MaskedDataPortInterface<Logic>(8, 2);
    final factory = _factory(maxConcurrentAccesses: 1);
    Memory<Logic> build({
      required int reads,
      required int writes,
      int latency = 0,
      int entries = 4,
    }) =>
        factory(
          clk: Logic(),
          reset: Logic(),
          writePorts: [write],
          readPorts: [read],
          entryCount: entries,
          readLatency: latency,
          maxConcurrentReads: reads,
          maxConcurrentWrites: writes,
          name: 'array',
        );
    expect(() => build(reads: 1, writes: 1), throwsArgumentError);
    expect(() => build(reads: 1, writes: 0, latency: 1), throwsArgumentError);
    expect(() => build(reads: 1, writes: 0, entries: 5), throwsArgumentError);
    expect(build(reads: 1, writes: 0), isA<MemoryModel<Logic>>());
  });

  test('rejects unsupported masked writes', () {
    expect(
      () => _factory(masked: false)(
        clk: Logic(),
        reset: Logic(),
        writePorts: [MaskedDataPortInterface<Logic>(8, 2)],
        readPorts: [DataPortInterface<Logic>(8, 2)],
        entryCount: 4,
        readLatency: 0,
        maxConcurrentReads: 1,
        maxConcurrentWrites: 1,
        name: 'array',
      ),
      throwsArgumentError,
    );
  });

  test('accepts a caller-enforced shared read/write access limit', () {
    final factory = _factory(maxConcurrentAccesses: 1);
    Memory<Logic> build(int combined) => factory(
          clk: Logic(),
          reset: Logic(),
          writePorts: [DataPortInterface<Logic>(8, 2)],
          readPorts: [DataPortInterface<Logic>(8, 2)],
          entryCount: 4,
          readLatency: 0,
          maxConcurrentReads: 1,
          maxConcurrentWrites: 1,
          maxConcurrentAccesses: combined,
          name: 'shared_array',
        );
    expect(build(1), isA<MemoryModel<Logic>>());
    expect(() => build(0), throwsArgumentError);
    expect(() => build(2), throwsArgumentError);
    expect(() => build(3), throwsArgumentError);
  });

  test('checks directional limits independently of total access limit', () {
    final reads = List.generate(2, (_) => DataPortInterface<Logic>(8, 2));
    final writes = [DataPortInterface<Logic>(8, 2)];
    final factory = _factory(
        maxConcurrentAccesses: 3,
        maxConcurrentReads: 1,
        maxConcurrentWrites: 1);
    Memory<Logic> build(int readCount, int writeCount) => factory(
          clk: Logic(),
          reset: Logic(),
          writePorts: writes,
          readPorts: reads,
          entryCount: 4,
          readLatency: 0,
          maxConcurrentReads: readCount,
          maxConcurrentWrites: writeCount,
          name: 'directional_array',
        );
    expect(() => build(2, 0), throwsArgumentError);
    expect(build(1, 1), isA<MemoryModel<Logic>>());
    final readOnly = _factory(maxConcurrentWrites: 0);
    expect(
      () => readOnly(
        clk: Logic(),
        reset: Logic(),
        writePorts: writes,
        readPorts: reads,
        entryCount: 4,
        readLatency: 0,
        maxConcurrentReads: 1,
        maxConcurrentWrites: 1,
        name: 'read_only_array',
      ),
      throwsArgumentError,
    );
    expect(
      () => _factory(maxConcurrentReads: -1)(
        clk: Logic(),
        reset: Logic(),
        writePorts: writes,
        readPorts: reads,
        entryCount: 4,
        readLatency: 0,
        maxConcurrentReads: 1,
        maxConcurrentWrites: 0,
        name: 'invalid_array',
      ),
      throwsArgumentError,
    );
  });

  test('rejects a factory whose module violates its latency contract', () {
    expect(
      () => _factory(incorrectLatency: true)(
        clk: Logic(),
        reset: Logic(),
        writePorts: [DataPortInterface<Logic>(8, 2)],
        readPorts: [DataPortInterface<Logic>(8, 2)],
        entryCount: 4,
        readLatency: 0,
        maxConcurrentReads: 1,
        maxConcurrentWrites: 1,
        name: 'array',
      ),
      throwsStateError,
    );
  });

  test('checks synchronous latency and collision requirements', () {
    final factory = _factory(latency: 1);
    final read = DataPortInterface<Logic>(8, 2);
    final write = DataPortInterface<Logic>(8, 2);
    Memory<Logic> build(MemoryArrayReadCollision collision) => factory(
          clk: Logic(),
          reset: Logic(),
          writePorts: [write],
          readPorts: [read],
          entryCount: 4,
          readLatency: 1,
          maxConcurrentReads: 1,
          maxConcurrentWrites: 1,
          requiredReadCollision: collision,
          name: 'array',
        );
    expect(() => build(MemoryArrayReadCollision.oldData), throwsArgumentError);
    expect(build(MemoryArrayReadCollision.newData).readLatency, 1);
  });
}
