// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// buffered_request_response_channel_test.dart
// Tests for the BufferedRequestResponseChannel component.
//
// 2025 October 26
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

import 'cache/channel_test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  /// Per-test DUT constructor for buffered channels.
  BufferedRequestResponseChannel constructBufferedChannel(
    Logic clk,
    Logic reset,
    ChannelPorts cp, {
    int requestBufferDepth = 8,
    int responseBufferDepth = 8,
  }) =>
      BufferedRequestResponseChannel(
        clk: clk,
        reset: reset,
        upstreamRequestIntf: cp.upstreamReq,
        upstreamResponseIntf: cp.upstreamResp,
        downstreamRequestIntf: cp.downstreamReq,
        downstreamResponseIntf: cp.downstreamResp,
        requestBufferDepth: requestBufferDepth,
        responseBufferDepth: responseBufferDepth,
      );

  group('BufferedRequestResponseChannel', () {
    test('should build successfully', () async {
      final clk = Logic();
      final reset = Logic();

      final ifs = ChannelPorts.fresh(idWidth: 2, addrWidth: 8);
      final channel = constructBufferedChannel(clk, reset, ifs,
          requestBufferDepth: 3, responseBufferDepth: 3);

      await channel.build();

      // Verify the module was built successfully.
      expect(
          channel.definitionName, contains('BufferedRequestResponseChannel'));
      expect(channel.definitionName, contains('REQBUF3'));
      expect(channel.definitionName, contains('RSPBUF3'));
    });

    test('RR channel: forward backpressure', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      // Use narrow widths as requested.
      final ifs = ChannelPorts.fresh(idWidth: 2);
      final channel = constructBufferedChannel(clk, reset, ifs,
          requestBufferDepth: 2, responseBufferDepth: 2);

      await channel.build();

      Simulator.setMaxSimTime(1000);
      unawaited(Simulator.run());

      // Reset sequence using ChannelPorts helper.
      await ifs.resetChannel(clk, reset, downstreamReqReadyValue: false);

      // Phase 1: Test FIFO filling and backpressure.

      // Send first request.
      ifs.upstreamReq.valid.inject(1);
      ifs.upstreamReq.data.id.inject(1);
      ifs.upstreamReq.data.addr.inject(0xA);
      await clk.nextPosedge;
      expect(ifs.upstreamReq.ready.value.toBool(), isTrue,
          reason: 'After req1: ready=${ifs.upstreamReq.ready.value}');

      // Send second request.
      ifs.upstreamReq.data.id.inject(2);
      ifs.upstreamReq.data.addr.inject(0xB);
      await clk.nextPosedge;

      // FIFO should now be full (depth=2).
      expect(ifs.upstreamReq.ready.value.toBool(), isFalse,
          reason: 'FIFO should be full after 2 requests');

      // Phase 2: Test draining behavior.
      // Stop sending new requests to focus on draining.
      ifs.upstreamReq.valid.inject(0);

      // Enable downstream to start draining.
      ifs.downstreamReq.ready.inject(1);
      await clk.nextPosedge;

      // Verify basic draining behavior.
      expect(ifs.downstreamReq.valid.value.toBool(), isTrue,
          reason: 'Downstream should see valid data when draining');
      expect(ifs.upstreamReq.ready.value.toBool(), isTrue,
          reason: 'First item drained, ready=${ifs.upstreamReq.ready.value}');

      // Drain second item.
      await clk.nextPosedge;

      // FIFO should now be empty.
      await clk.nextPosedge;
      expect(ifs.downstreamReq.valid.value.toBool(), isFalse,
          reason: 'FIFO drained successfully - downstream should not be '
              'valid when FIFO empty');

      await Simulator.endSimulation();

      // Waveforms saved to rr_channel_backpressure.vcd
    });

    test('RR channel: response path backpressure', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      // Use narrow widths as requested.
      final ifs = ChannelPorts.fresh(idWidth: 2);
      final channel = constructBufferedChannel(clk, reset, ifs,
          requestBufferDepth: 2, responseBufferDepth: 2);

      await channel.build();

      Simulator.setMaxSimTime(1000);
      unawaited(Simulator.run());

      // Reset sequence.
      await ifs.resetChannel(clk, reset, upstreamRespReadyValue: false);

      // Testing response path backpressure

      // Send responses from downstream back to upstream.
      ifs.downstreamResp.valid.inject(1);
      ifs.downstreamResp.data.id.inject(1);
      ifs.downstreamResp.data.data.inject(0xF1);
      await clk.nextPosedge;
      expect(ifs.downstreamResp.ready.value.toBool(), isTrue,
          reason: 'After resp1: ready=${ifs.downstreamResp.ready.value}');

      // Send second response.
      ifs.downstreamResp.data.id.inject(2);
      ifs.downstreamResp.data.data.inject(0xF2);
      await clk.nextPosedge;
      // After resp2: ready should be false since response FIFO becomes full

      // Response FIFO should now be full (depth=2).
      expect(ifs.downstreamResp.ready.value.toBool(), isFalse,
          reason: 'Response FIFO should be full after 2 responses');

      // Enable upstream to start draining response FIFO.
      ifs.upstreamResp.ready.inject(1);
      await clk.nextPosedge;

      // Verify draining behavior.
      expect(ifs.upstreamResp.valid.value.toBool(), isTrue,
          reason: 'Upstream should see valid response when draining');
      expect(ifs.downstreamResp.ready.value.toBool(), isTrue,
          reason: 'Response path backpressure test passed - '
              'downstream should become ready when space available');

      await Simulator.endSimulation();

      // Response waveforms saved to rr_channel_response_backpressure.vcd
    });
  });
}
