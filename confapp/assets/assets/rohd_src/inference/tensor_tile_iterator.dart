// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_tile_iterator.dart
// Runtime M/N/K nested tile iterator.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Iterates runtime-bounded M/N/K tile coordinates with K as the inner loop.
///
/// A start request is accepted only while idle. Runtime extents are retained
/// for the complete traversal. `advance` consumes the current coordinate.
/// [done] pulses when the final coordinate is consumed.
/// {@category Inference}
class TensorTileIterator extends Module {
  /// Width of the M tile index and extent.
  final int mWidth;

  /// Width of the N tile index and extent.
  final int nWidth;

  /// Width of the K tile index and extent.
  final int kWidth;

  /// Current M tile index.
  Logic get mIndex => output('mIndex');

  /// Current N tile index.
  Logic get nIndex => output('nIndex');

  /// Current K tile index.
  Logic get kIndex => output('kIndex');

  /// High while a current coordinate is valid.
  Logic get busy => output('busy');

  /// High when a start request can be accepted.
  Logic get startReady => output('startReady');

  /// High on the current final coordinate.
  Logic get last => output('last');

  /// Pulses when the final coordinate is consumed.
  Logic get done => output('done');

  /// Pulses when an accepted start contains a zero extent.
  Logic get invalidExtent => output('invalidExtent');

  /// Pulses when start is asserted while an iteration is already active.
  Logic get startRejected => output('startRejected');

  /// Creates a nested runtime tile iterator.
  TensorTileIterator({
    required Logic clk,
    required Logic reset,
    required Logic start,
    required Logic advance,
    required Logic mTiles,
    required Logic nTiles,
    required Logic kTiles,
    super.name = 'tensor_tile_iterator',
  })  : mWidth = mTiles.width,
        nWidth = nTiles.width,
        kWidth = kTiles.width,
        super(
          definitionName: 'TensorTileIterator_'
              'M${mTiles.width}_N${nTiles.width}_K${kTiles.width}',
        ) {
    if (mWidth < 1 || nWidth < 1 || kWidth < 1) {
      throw ArgumentError('Tile extent widths must be positive.');
    }
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    start = addInput('start', start);
    advance = addInput('advance', advance);
    mTiles = addInput('mTiles', mTiles, width: mWidth);
    nTiles = addInput('nTiles', nTiles, width: nWidth);
    kTiles = addInput('kTiles', kTiles, width: kWidth);
    final mIndex = addOutput('mIndex', width: mWidth);
    final nIndex = addOutput('nIndex', width: nWidth);
    final kIndex = addOutput('kIndex', width: kWidth);
    final busy = addOutput('busy');
    final done = addOutput('done');
    final invalidExtent = addOutput('invalidExtent');
    final startRejected = addOutput('startRejected');
    final retainedM = Logic(name: '${name}_retained_m', width: mWidth);
    final retainedN = Logic(name: '${name}_retained_n', width: nWidth);
    final retainedK = Logic(name: '${name}_retained_k', width: kWidth);
    final ready = ~busy;
    final acceptedStart = start & ready;
    final invalidStart =
        acceptedStart & (~mTiles.or() | ~nTiles.or() | ~kTiles.or());
    final lastM = mIndex.eq(retainedM - 1);
    final lastN = nIndex.eq(retainedN - 1);
    final lastK = kIndex.eq(retainedK - 1);
    final finalCoordinate = busy & lastM & lastN & lastK;

    addOutput('startReady') <= ready;
    addOutput('last') <= finalCoordinate;

    Sequential(localClk, reset: localReset, resetValues: {
      mIndex: 0,
      nIndex: 0,
      kIndex: 0,
      busy: 0,
      done: 0,
      invalidExtent: 0,
      startRejected: 0,
      retainedM: 0,
      retainedN: 0,
      retainedK: 0,
    }, [
      done < 0,
      invalidExtent < 0,
      startRejected < start & busy,
      If(acceptedStart, then: [
        mIndex < 0,
        nIndex < 0,
        kIndex < 0,
        If(invalidStart, then: [
          busy < 0,
          invalidExtent < 1,
        ], orElse: [
          busy < 1,
          retainedM < mTiles,
          retainedN < nTiles,
          retainedK < kTiles,
        ]),
      ]),
      If(busy & advance, then: [
        If(lastK, then: [
          kIndex < 0,
          If(lastN, then: [
            nIndex < 0,
            If(lastM, then: [
              mIndex < 0,
              busy < 0,
              done < 1,
            ], orElse: [
              mIndex < mIndex + 1,
            ]),
          ], orElse: [
            nIndex < nIndex + 1,
          ]),
        ], orElse: [
          kIndex < kIndex + 1,
        ]),
      ]),
    ]);
  }
}
