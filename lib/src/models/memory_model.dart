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

//TODO: move the X, addr adjust, etc. over to storage

/// A model of a [Memory] which uses a software-based [SparseMemoryStorage] to
/// store data.
///
/// This is useful to mimic a large memory.  This is *not* synthesizable, it is
/// only a model.
class MemoryModel extends Memory {
  /// The memory storage underlying this model.
  late final MemoryStorage storage = SparseMemoryStorage(addrWidth: addrWidth);

  /// A pre-signal before the output flops of this memory.
  late final List<Logic> _rdDataPre;

  /// If true, a positive edge on reset will reset the memory asynchronously.
  final bool asyncReset;

  /// A function called if an invalid write is made when [storage] is not empty.
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

  /// A function called if a read is made to an address that has no data in
  /// [storage].
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
  /// By default, this will align (mask) addresses to a multiple of 4.
  final LogicValue Function(LogicValue addr) alignAddress;

  /// Default behavior for [alignAddress].
  static LogicValue _defaultAlignAddress(LogicValue addr) => addr - (addr % 4);

  @override
  final int readLatency;

  /// Creates a new [MemoryModel].
  MemoryModel(
    super.clk,
    super.reset,
    super.writePorts,
    super.readPorts, {
    this.readLatency = 1,
    this.asyncReset = true,
    this.onInvalidWrite = _defaultOnInvalidWrite,
    this.onInvalidRead = _defaultOnInvalidRead,
    this.alignAddress = _defaultAlignAddress,
  }) {
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
      if (reset.value == LogicValue.one) {
        storage.reset();
        return;
      }
      for (final wrPort in wrPorts) {
        if (!wrPort.en.value.isValid ||
            (wrPort.en.value == LogicValue.one && !wrPort.addr.value.isValid)) {
          if (!storage.isEmpty) {
            onInvalidWrite();
          }

          storage.reset();

          return;
        }
        if (wrPort.en.value == LogicValue.one) {
          var addrValue = wrPort.addr.value;

          addrValue = alignAddress(addrValue);

          if (wrPort is MaskedDataPortInterface) {
            storage.setData(
                addrValue,
                List<LogicValue>.generate(
                  dataWidth ~/ 8,
                  (index) => wrPort.mask.value[index].toBool()
                      ? wrPort.data.value.getRange(index * 8, (index + 1) * 8)
                      : (storage.getData(addrValue) ??
                              onInvalidRead(addrValue, dataWidth))
                          .getRange(index * 8, (index + 1) * 8),
                ).rswizzle());
          } else {
            storage.setData(addrValue, wrPort.data.value);
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
      var addrValue = rdPort.addr.value;

      addrValue = alignAddress(addrValue);

      if (storage.getData(addrValue) == null) {
        rdPortPre.put(onInvalidRead(addrValue, dataWidth));
      } else {
        rdPortPre.put(storage.getData(addrValue));
      }
    }
  }
}
