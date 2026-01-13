// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// async_fifo.dart
// Implementation of an asynchronous FIFO for clock domain crossing.
//
// 2026 January 13
// Author: Maifee Ul Asad <maifeeulasad@gmail.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An asynchronous FIFO for safely passing data between two clock domains.
///
/// The [AsyncFifo] implements a dual-clock FIFO that allows data to be written
/// in one clock domain and read in another, completely independent clock domain.
/// This is essential for designs that need to transfer data between different
/// clock frequencies or phases.
///
/// **Key Features:**
/// - Independent write and read clock domains
/// - Gray-coded pointers for safe clock domain crossing
/// - Proper synchronization to prevent metastability
/// - Full/empty flag generation
/// - Data integrity across clock domains
///
/// **Implementation Details:**
/// - Uses Gray code for pointer synchronization (only 1 bit changes at a time)
/// - Multi-stage synchronizers for crossing pointer values
/// - Write pointers synchronized to read domain for empty detection
/// - Read pointers synchronized to write domain for full detection
///
/// **Important Notes:**
/// - The `depth` must be a power of 2 for proper Gray code wrapping
/// - Full/empty flags have synchronization latency (typically 2 cycles)
/// - FIFO appears empty for a few cycles after reset due to sync latency
///
/// Example:
/// ```dart
/// final asyncFifo = AsyncFifo(
///   writeClk: wrClk,
///   readClk: rdClk,
///   writeReset: wrRst,
///   readReset: rdRst,
///   writeEnable: wrEn,
///   writeData: wrData,
///   readEnable: rdEn,
///   depth: 16,
/// );
/// ```
class AsyncFifo extends Module {
  /// High if the FIFO is full and cannot accept new writes.
  ///
  /// This signal is in the write clock domain.
  Logic get full => output('full');

  /// High if the FIFO is empty and has no data to read.
  ///
  /// This signal is in the read clock domain.
  Logic get empty => output('empty');

  /// Read data output.
  ///
  /// This is the data that will be read when [readEnable] is asserted.
  /// The data is valid when [empty] is low.
  Logic get readData => output('readData');

  /// The depth of the FIFO (number of entries).
  ///
  /// Must be a power of 2 for proper Gray code pointer wrapping.
  final int depth;

  /// The width of the data being transmitted through the FIFO.
  final int dataWidth;

  /// Number of synchronization stages for CDC.
  ///
  /// Default is 2, which is suitable for most applications.
  final int syncStages;

  /// Write clock signal.
  Logic get _writeClk => input('writeClk');

  /// Read clock signal.
  Logic get _readClk => input('readClk');

  /// Write domain reset.
  Logic get _writeReset => input('writeReset');

  /// Read domain reset.
  Logic get _readReset => input('readReset');

  /// Write enable signal (write clock domain).
  Logic get _writeEnable => input('writeEnable');

  /// Read enable signal (read clock domain).
  Logic get _readEnable => input('readEnable');

  /// Write data input (write clock domain).
  Logic get _writeData => input('writeData');

  /// Address width for the FIFO memory.
  final int _addrWidth;

  /// Constructs an [AsyncFifo] with the specified parameters.
  ///
  /// - [writeClk]: Clock for the write domain.
  /// - [readClk]: Clock for the read domain.
  /// - [writeReset]: Reset signal for the write domain.
  /// - [readReset]: Reset signal for the read domain.
  /// - [writeEnable]: Write enable signal (active high).
  /// - [writeData]: Data to write into the FIFO.
  /// - [readEnable]: Read enable signal (active high).
  /// - [depth]: Number of entries in the FIFO (must be power of 2).
  /// - [syncStages]: Number of synchronizer stages (default: 2).
  AsyncFifo({
    required Logic writeClk,
    required Logic readClk,
    required Logic writeReset,
    required Logic readReset,
    required Logic writeEnable,
    required Logic writeData,
    required Logic readEnable,
    required this.depth,
    this.syncStages = 2,
    super.name = 'async_fifo',
  })  : dataWidth = writeData.width,
        _addrWidth = log2Ceil(depth),
        super(definitionName: 'AsyncFifo_D${depth}_W${writeData.width}') {
    if (depth <= 0) {
      throw RohdHclException('Depth must be at least 1.');
    }

    if (depth & (depth - 1) != 0) {
      throw RohdHclException(
          'Depth must be a power of 2, but got $depth.'
          ' Use depths like 2, 4, 8, 16, 32, etc.');
    }

    // Add inputs
    addInput('writeClk', writeClk);
    addInput('readClk', readClk);
    addInput('writeReset', writeReset);
    addInput('readReset', readReset);
    addInput('writeEnable', writeEnable);
    addInput('writeData', writeData, width: dataWidth);
    addInput('readEnable', readEnable);

    // Add outputs
    addOutput('readData', width: dataWidth);
    addOutput('full');
    addOutput('empty');

    _buildLogic();
  }

  /// Builds all the logic for the async FIFO.
  void _buildLogic() {
    // Create memory storage (dual-port RAM)
    final memory = List.generate(
      depth,
      (i) => Logic(name: 'mem_$i', width: dataWidth),
    );

    // Write domain signals
    final wrAddr = Logic(name: 'wrAddr', width: _addrWidth);
    final wrAddrGray = Logic(name: 'wrAddrGray', width: _addrWidth + 1);
    final wrAddrGrayNext = Logic(name: 'wrAddrGrayNext', width: _addrWidth + 1);

    // Read domain signals
    final rdAddr = Logic(name: 'rdAddr', width: _addrWidth);
    final rdAddrGray = Logic(name: 'rdAddrGray', width: _addrWidth + 1);
    final rdAddrGrayNext = Logic(name: 'rdAddrGrayNext', width: _addrWidth + 1);

    // Synchronized pointers
    final wrAddrGraySync =
        Logic(name: 'wrAddrGraySync', width: _addrWidth + 1);
    final rdAddrGraySync =
        Logic(name: 'rdAddrGraySync', width: _addrWidth + 1);

    // Binary to Gray converters for pointers
    // Note: We use (_addrWidth + 1) bits to distinguish full from empty
    final wrPtrBinary = Logic(name: 'wrPtrBinary', width: _addrWidth + 1);
    final rdPtrBinary = Logic(name: 'rdPtrBinary', width: _addrWidth + 1);

    final wrPtrNext = Logic(name: 'wrPtrNext', width: _addrWidth + 1);
    final rdPtrNext = Logic(name: 'rdPtrNext', width: _addrWidth + 1);

    wrPtrNext <= wrPtrBinary + _writeEnable.zeroExtend(_addrWidth + 1);
    rdPtrNext <= rdPtrBinary + _readEnable.zeroExtend(_addrWidth + 1);

    final wrGrayConverter = BinaryToGrayConverter(wrPtrNext);
    final rdGrayConverter = BinaryToGrayConverter(rdPtrNext);

    wrAddrGrayNext <= wrGrayConverter.gray;
    rdAddrGrayNext <= rdGrayConverter.gray;

    // Write pointer logic (in write clock domain)
    Sequential(
      _writeClk,
      reset: _writeReset,
      [
        wrAddrGray < wrAddrGrayNext,
        wrPtrBinary < wrPtrBinary + _writeEnable.zeroExtend(_addrWidth + 1),
      ],
    );

    // Extract write address (lower bits of pointer)
    wrAddr <= wrPtrBinary.slice(_addrWidth - 1, 0);

    // Read pointer logic (in read clock domain)
    Sequential(
      _readClk,
      reset: _readReset,
      [
        rdAddrGray < rdAddrGrayNext,
        rdPtrBinary < rdPtrBinary + _readEnable.zeroExtend(_addrWidth + 1),
      ],
    );

    // Extract read address (lower bits of pointer)
    rdAddr <= rdPtrBinary.slice(_addrWidth - 1, 0);

    // Synchronize write pointer to read clock domain
    final wrGraySync = Synchronizer(
      _readClk,
      dataIn: wrAddrGray,
      reset: _readReset,
      stages: syncStages,
      name: 'wrGraySync',
    );
    wrAddrGraySync <= wrGraySync.syncData;

    // Synchronize read pointer to write clock domain
    final rdGraySync = Synchronizer(
      _writeClk,
      dataIn: rdAddrGray,
      reset: _writeReset,
      stages: syncStages,
      name: 'rdGraySync',
    );
    rdAddrGraySync <= rdGraySync.syncData;

    // Empty flag: read domain compares its pointer to synced write pointer
    empty <= rdAddrGray.eq(wrAddrGraySync);

    // Full flag: write domain compares its pointer to synced read pointer
    // Full when MSB differs (indicating wrap) but rest matches
    // For Gray code: check if top 2 bits are inverted and remaining bits match
    final fullCondition = Logic(name: 'fullCondition');
    
    if (_addrWidth == 0) {
      // Special case for depth=2 (single address bit)
      fullCondition <= wrAddrGray[1].eq(~rdAddrGraySync[1]) &
          wrAddrGray[0].eq(rdAddrGraySync[0]);
    } else {
      fullCondition <= wrAddrGray[_addrWidth].eq(~rdAddrGraySync[_addrWidth]) &
          wrAddrGray[_addrWidth - 1].eq(~rdAddrGraySync[_addrWidth - 1]) &
          wrAddrGray.slice(_addrWidth - 2, 0).eq(
              rdAddrGraySync.slice(_addrWidth - 2, 0));
    }

    full <= fullCondition;

    // Memory write logic (write clock domain)
    for (var i = 0; i < depth; i++) {
      Sequential(_writeClk, [
        If(
          _writeEnable &
              ~full &
              wrAddr.eq(Const(i, width: _addrWidth)),
          then: [
            memory[i] < _writeData,
          ],
        ),
      ]);
    }

    // Memory read logic (combinational)
    final readDataMux = <CaseItem>[];
    for (var i = 0; i < depth; i++) {
      readDataMux.add(
        CaseItem(
          Const(i, width: _addrWidth),
          [readData < memory[i]],
        ),
      );
    }

    Combinational([
      Case(
        rdAddr,
        readDataMux,
        conditionalType: ConditionalType.unique,
        defaultItem: [readData < Const(0, width: dataWidth)],
      ),
    ]);
  }
}
