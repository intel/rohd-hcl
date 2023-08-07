// Copyright (C) 2021-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_model.dart
// A model for `Memory`
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A model of a [Memory] which uses a software-based [SparseMemoryStorage] to
/// store data.
///
/// This is useful to mimic a large memory.  This is *not* synthesizable, it is
/// only a model.
class MemoryModel extends Memory {
  /// The memory storage underlying this model.
  late final MemoryStorage storage;

  /// A pre-signal before the output flops of this memory.
  late final List<Logic> _rdDataPre;

  /// If true, a positive edge on reset will reset the memory asynchronously.
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
  }) {
    this.storage = storage ??
        SparseMemoryStorage(addrWidth: addrWidth, dataWidth: dataWidth);

    _buildLogic();
  }

  void _buildLogic() {
    _rdDataPre = List.generate(
        numReads, (index) => Logic(name: 'rdDataPre$index', width: dataWidth));

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
        if (!(wrPort.en.previousValue?.isValid ?? false) && !storage.isEmpty) {
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
    });

    // on any glitch to read controls, change pre-flop version of read data
    for (var i = 0; i < rdPorts.length; i++) {
      clk.negedge.listen((event) => _updatePreRead(i));

      // flop out the read data
      var delayedData = _rdDataPre[i];
      for (var delay = 0; delay < readLatency; delay++) {
        delayedData = FlipFlop(clk, delayedData).q;
      }

      rdPorts[i].data <= delayedData;
    }
  }

  void _updatePreRead(int rdIndex) {
    final rdPort = rdPorts[rdIndex];
    final rdPortPre = _rdDataPre[rdIndex];

    if (!rdPort.en.value.isValid ||
        (rdPort.en.value == LogicValue.one && !rdPort.addr.value.isValid)) {
      rdPortPre.put(LogicValue.x, fill: true);
      return;
    }

    if (rdPort.en.value == LogicValue.one) {
      rdPortPre.put(storage.readData(rdPort.addr.value));
    }
  }
}
