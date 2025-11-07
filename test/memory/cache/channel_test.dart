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

  ChannelPorts(this.upstreamReq, this.upstreamResp, this.downstreamReq,
      this.downstreamResp);
}

/// Create a fresh set of 4-bit ready/valid interfaces for tests.
/// tests to keep widths consistent and reduce duplication.
@visibleForTesting
ChannelPorts makeChannelPorts({int idWidth = 4, int addrWidth = 4}) {
  final uReq = ReadyValidInterface(
      RequestStructure(idWidth: idWidth, addrWidth: addrWidth));
  final uResp = ReadyValidInterface(
      ResponseStructure(idWidth: idWidth, dataWidth: addrWidth));
  final dReq = ReadyValidInterface(
      RequestStructure(idWidth: idWidth, addrWidth: addrWidth));
  final dResp = ReadyValidInterface(
      ResponseStructure(idWidth: idWidth, dataWidth: addrWidth));
  return ChannelPorts(uReq, uResp, dReq, dResp);
}

/// Per-test DUT constructor.
CachedRequestResponseChannel constructChannel(
  Logic clk,
  Logic reset,
  ChannelPorts cp, {
  int cacheWays = 8,
  int responseBufferDepth = 8,
  int camWays = 8,
  ReadyValidInterface<CacheWriteStructure>? cacheWriteIntf,
  Logic? resetCache,
}) =>
    CachedRequestResponseChannel(
        clk: clk,
        reset: reset,
        upstreamRequestIntf: cp.upstreamReq,
        upstreamResponseIntf: cp.upstreamResp,
        downstreamRequestIntf: cp.downstreamReq,
        downstreamResponseIntf: cp.downstreamResp,
        cacheFactory: createCacheFactory(cacheWays),
        cacheWriteIntf: cacheWriteIntf,
        resetCache: resetCache,
        responseBufferDepth: responseBufferDepth,
        camWays: camWays);

/// Reset all channel interfaces for testing.
Future<void> resetChannel(Logic clk, Logic reset, ChannelPorts cp,
    {bool upstreamRespReadyValue = true,
    bool downstreamReqReadyValue = true,
    bool downstreamRespValidValue = false,
    int preReleaseCycles = 2,
    int postReleaseCycles = 1,
    ReadyValidInterface<dynamic>? cacheWriteIntf}) async {
  // Assert reset and initialize handshake signals to known values.
  reset.inject(1);
  cp.upstreamReq.valid.inject(0);
  cp.downstreamReq.ready.inject(downstreamReqReadyValue ? 1 : 0);
  cp.upstreamResp.ready.inject(upstreamRespReadyValue ? 1 : 0);
  cp.downstreamResp.valid.inject(downstreamRespValidValue ? 1 : 0);
  cp.downstreamResp.data.nonCacheable.inject(0);
  if (cacheWriteIntf != null) {
    cacheWriteIntf.valid.inject(0);
  }
  await clk.waitCycles(preReleaseCycles);

  // Deassert reset and allow circuits to come out of reset.
  reset.inject(0);
  await clk.waitCycles(postReleaseCycles);
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
}
