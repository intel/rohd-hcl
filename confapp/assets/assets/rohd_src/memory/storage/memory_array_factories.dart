// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_array_factories.dart
// Shared factories for addressed memory arrays.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/contracts/memory_array.dart';
import 'package:rohd_hcl/src/memory/storage/register_file.dart';
import 'package:rohd_hcl/src/models/memory/memory_model.dart';

/// Creates the zero-latency, flop-backed register-file array factory.
MemoryArrayFunctor<T> registerFileArray<T extends Logic>() =>
    MemoryArrayFunctor<T>(
      identity: 'registerFile',
      capabilities: const MemoryArrayCapabilities(
        readLatency: 0,
        readCollision: MemoryArrayReadCollision.combinational,
        writeCollision: MemoryArrayWriteCollision.unspecified,
        supportsMaskedWrites: true,
        implementation: MemoryArrayImplementation.synthesizable,
      ),
      build: ({
        required clk,
        required reset,
        required writePorts,
        required readPorts,
        required entryCount,
        required name,
      }) =>
          RegisterFile<T>(clk, reset, writePorts, readPorts,
              numEntries: entryCount, name: name),
    );

/// Creates the behavioral equivalent of [registerFileArray].
MemoryArrayFunctor<T> behavioralRegisterFileArray<T extends Logic>() =>
    MemoryArrayFunctor<T>(
      identity: 'behavioral',
      capabilities: const MemoryArrayCapabilities(
        readLatency: 0,
        readCollision: MemoryArrayReadCollision.combinational,
        writeCollision: MemoryArrayWriteCollision.unspecified,
        supportsMaskedWrites: true,
        implementation: MemoryArrayImplementation.simulationOnly,
      ),
      build: ({
        required clk,
        required reset,
        required writePorts,
        required readPorts,
        required entryCount,
        required name,
      }) =>
          MemoryModel<T>.registerFile(clk, reset, writePorts, readPorts,
              numEntries: entryCount, name: name),
    );
