// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// channel_test.dart Common tests for all channel types.
//
// 2025 November 7
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

import 'cache_test.dart';

/// Small container for a group of 4 ReadyValid interfaces used in several
/// tests to keep widths consistent and reduce duplication.
@visibleForTesting
class ChannelPorts {
  final ReadyValidInterface<RequestStructure> upstreamReq;
  final ReadyValidInterface<ResponseStructure> upstreamResp;
  final ReadyValidInterface<RequestStructure> downstreamReq;
  final ReadyValidInterface<ResponseStructure> downstreamResp;

  void reset() {
    for (final p in [
      upstreamReq,
      upstreamResp,
      downstreamReq,
      downstreamResp
    ]) {
      p.valid.inject(0);
      p.ready.inject(0);
      p.data.inject(0);
    }
  }

  /// Instance helper that constructs a CachedRequestResponseChannel using
  /// this set of interfaces. This mirrors the top-level `constructChannel`
  /// free function but lets tests or helpers call `cp.constructChannel(...)`.
  CachedRequestResponseChannel constructChannel(
    Logic clk,
    Logic reset, {
    int cacheWays = 8,
    int responseBufferDepth = 8,
    int camWays = 8,
    ReadyValidInterface<CacheWriteStructure>? cacheWriteIntf,
    Logic? resetCache,
  }) =>
      CachedRequestResponseChannel(
          clk: clk,
          reset: reset,
          upstreamRequestIntf: upstreamReq,
          upstreamResponseIntf: upstreamResp,
          downstreamRequestIntf: downstreamReq,
          downstreamResponseIntf: downstreamResp,
          cacheFactory: fullyAssociativeFactory(ways: cacheWays),
          cacheWriteIntf: cacheWriteIntf,
          resetCache: resetCache,
          responseBufferDepth: responseBufferDepth,
          camWays: camWays);

  /// Reset all channel interfaces for testing. Instance form of the
  /// top-level `resetChannel` free function. Call sites can use
  /// `await cp.resetChannel(clk, reset, ...)`.
  Future<void> resetChannel(
    Logic clk,
    Logic reset, {
    bool upstreamRespReadyValue = true,
    bool downstreamReqReadyValue = true,
    bool downstreamRespValidValue = false,
    int preReleaseCycles = 2,
    int postReleaseCycles = 1,
    ReadyValidInterface<dynamic>? cacheWriteIntf,
  }) async {
    // Assert reset and initialize handshake signals to known values.
    reset.inject(1);
    upstreamReq.valid.inject(0);
    downstreamReq.ready.inject(downstreamReqReadyValue ? 1 : 0);
    upstreamResp.ready.inject(upstreamRespReadyValue ? 1 : 0);
    downstreamResp.valid.inject(downstreamRespValidValue ? 1 : 0);
    downstreamResp.data.nonCacheable.inject(0);
    if (cacheWriteIntf != null) {
      cacheWriteIntf.valid.inject(0);
    }
    await clk.waitCycles(preReleaseCycles);

    // Deassert reset and allow circuits to come out of reset.
    reset.inject(0);
    await clk.waitCycles(postReleaseCycles);
  }

  ChannelPorts(this.upstreamReq, this.upstreamResp, this.downstreamReq,
      this.downstreamResp);

  /// Named constructor that creates fresh ReadyValidInterface instances with
  /// the provided widths. Tests should prefer `ChannelPorts.fresh(...)` to
  /// keep widths consistent and reduce duplication.
  ChannelPorts.fresh({int idWidth = 4, int addrWidth = 4})
      : upstreamReq = ReadyValidInterface(
            RequestStructure(idWidth: idWidth, addrWidth: addrWidth)),
        upstreamResp = ReadyValidInterface(
            ResponseStructure(idWidth: idWidth, dataWidth: addrWidth)),
        downstreamReq = ReadyValidInterface(
            RequestStructure(idWidth: idWidth, addrWidth: addrWidth)),
        downstreamResp = ReadyValidInterface(
            ResponseStructure(idWidth: idWidth, dataWidth: addrWidth));
}

// Legacy free helper `makeChannelPorts` removed. Tests should use
// `ChannelPorts.fresh(...)` and the instance `resetChannel(...)` helper.

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
}
