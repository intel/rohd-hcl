// Copyright (C) 2021-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_model.dart
// A model for `Memory`
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A model of a [Memory] which uses a software-based [SparseMemoryStorage] to
/// store data.
///
/// This is useful to mimic a large memory.  This is *not* synthesizable, it is
/// only a model.
class MemoryModel extends Memory {
  /// The memory storage underlying this model.
  late final MemoryStorage storage;

  /// If `true`, a positive edge on reset will reset the memory asynchronously.
  final bool asyncReset;

  @override
  final int readLatency;

  /// Creates a new [MemoryModel].
  ///
  /// If no [storage] is provided, a default storage will be created.
  MemoryModel(
    super.clk,
    super.reset,
    super.writePorts,
    super.readPorts, {
    this.readLatency = 1,
    this.asyncReset = true,
    MemoryStorage? storage,
    super.definitionName,
  }) {
    this.storage = storage ??
        SparseMemoryStorage(addrWidth: addrWidth, dataWidth: dataWidth);

    _buildLogic();
  }

  void _buildLogic() {
    if (asyncReset) {
      reset.posedge.listen((event) {
        storage.reset();
      });
    }

    // on posedge of clock, sample write ports and save to memory
    clk.posedge.listen((event) {
      if (reset.previousValue == LogicValue.one) {
        storage.reset();
        return;
      }
      for (final wrPort in wrPorts) {
        if (!wrPort.en.previousValue!.isValid && !storage.isEmpty) {
          // storage doesnt have access to `en`, so check ourselves
          storage.invalidWrite();
          return;
        }

        if (wrPort.en.previousValue == LogicValue.one) {
          final addrValue = wrPort.addr.previousValue!;

          if (wrPort is MaskedDataPortInterface) {
            storage.writeData(
              addrValue,
              [
                for (var index = 0; index < dataWidth ~/ 8; index++)
                  wrPort.mask.previousValue![index].toBool()
                      ? wrPort.data.previousValue!
                          .getRange(index * 8, (index + 1) * 8)
                      : storage
                          .readData(addrValue)
                          .getRange(index * 8, (index + 1) * 8)
              ].rswizzle(),
            );
          } else {
            storage.writeData(addrValue, wrPort.data.previousValue!);
          }
        }
      }

      for (final rdPort in rdPorts) {
        if (readLatency > 0) {
          // if we have at least 1 cycle, then we wait to update the data
          if (!rdPort.en.previousValue!.isValid ||
              !rdPort.en.previousValue!.toBool() ||
              !rdPort.addr.previousValue!.isValid) {
            unawaited(_updateRead(
                rdPort, LogicValue.filled(rdPort.dataWidth, LogicValue.x)));
          } else {
            unawaited(_updateRead(
                rdPort, storage.readData(rdPort.addr.previousValue!)));
          }
        } else {
          // if we have instant read latency, we may need to update the read
          // data in zero-latency after updating a write
          _updateReadZeroLatency(rdPort);
        }
      }
    });

    // if latency is 0, we need to update immediately
    if (readLatency == 0) {
      for (final rdPort in rdPorts) {
        rdPort.en.glitch.listen((args) => _updateReadZeroLatency(rdPort));
        rdPort.addr.glitch.listen((args) => _updateReadZeroLatency(rdPort));
      }
    }
  }

  /// Updates read data for [rdPort] immediately (as if combinationally).
  void _updateReadZeroLatency(DataPortInterface rdPort) {
    if (!rdPort.en.value.isValid ||
        !rdPort.en.value.toBool() ||
        !rdPort.addr.value.isValid) {
      rdPort.data.put(LogicValue.x, fill: true);
    } else {
      rdPort.data.put(storage.readData(rdPort.addr.value));
    }
  }

  /// Updates read data for [rdPort] after [readLatency] time.
  Future<void> _updateRead(DataPortInterface rdPort, LogicValue data) async {
    if (readLatency > 1) {
      await clk.waitCycles(readLatency - 1);
    }
    rdPort.data.inject(data);
  }
}
