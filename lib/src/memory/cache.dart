// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cache.dart
// Set-associative cache.
//
// 2025 September 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An interface to a cache memory that supplies enable [en], address [addr],
/// [valid] for indicating a hit, and [data].
///
/// Can be used for either read or write direction by grouping signals using
/// [DataPortGroup].
class ValidDataPortInterface extends DataPortInterface {
  /// The "valid" bit for a response when the data is valid.
  Logic get valid => port('valid');

  /// The name of this interface, useful for disambiguating multiple interfaces.
  late final String name;

  /// Constructs a new interface of specified [dataWidth] and [addrWidth] for
  /// interacting with a `Cache` in either the read or write direction.
  ValidDataPortInterface(super.dataWidth, super.addrWidth, {String? name})
      : super() {
    this.name = name ?? 'valid_data_port_${dataWidth}w_${addrWidth}a';
    setPorts([
      Logic.port('valid'),
    ], [
      DataPortGroup.data
    ]);
  }

  /// Makes a copy of this [ValidDataPortInterface] with matching configuration.
  @override
  ValidDataPortInterface clone() =>
      ValidDataPortInterface(dataWidth, addrWidth);
}

/// A single-ported read cache.
class SinglePortedCache extends Module {
  /// Number of lines in the cache.
  final int lines;

  /// This cache is a read-cache. It does not track dirty data to implement
  /// write-back. The write policy it would support is a write-around policy.
  SinglePortedCache(Logic clk, Logic reset, ValidDataPortInterface fill,
      ValidDataPortInterface read,
      {this.lines = 16}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    fill = fill.clone()
      ..connectIO(this, fill,
          inputTags: {DataPortGroup.control, DataPortGroup.data},
          uniquify: (original) => 'cache_fill_$original');
    read = read.clone()
      ..connectIO(this, read,
          inputTags: {DataPortGroup.control},
          outputTags: {DataPortGroup.data},
          uniquify: (original) => 'cache_read_$original');

    final dataWidth = fill.dataWidth;

    final lineAddrWidth = log2Ceil(lines);

    final writeRFPort = DataPortInterface(dataWidth, lineAddrWidth);
    final readRFPort = DataPortInterface(dataWidth, lineAddrWidth);

    RegisterFile(clk, reset, [writeRFPort], [readRFPort],
        numEntries: lines, name: 'data_rf');

    writeRFPort.en <= fill.en & fill.valid;
    writeRFPort.addr <= getLine(fill.addr);
    writeRFPort.data <= fill.data;

    final rdPort = read;
    Combinational(name: 'readRF', [
      rdPort.valid < Const(0),
      rdPort.data < Const(0, width: rdPort.dataWidth),
      readRFPort.en < Const(0),
      If(rdPort.en, then: [
        readRFPort.en < rdPort.en,
        readRFPort.addr < getLine(rdPort.addr),
        rdPort.data < readRFPort.data,
        rdPort.valid < Const(1),
      ])
    ]);
  }

  /// Extract the line index from the address.
  Logic getLine(Logic addr) => addr.slice(log2Ceil(lines) - 1, 0);
}
