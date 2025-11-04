// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// buffered_request_response_channel_test.dart
// Tests for the BufferedRequestResponseChannel component.
//
// 2025 October 26
// Authors: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>
//          GitHub Copilot <github-copilot@github.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('BufferedRequestResponseChannel', () {
    test('should build successfully', () async {
      final clk = Logic();
      final reset = Logic();

      final upstreamReq = ReadyValidInterface(
        RequestStructure(idWidth: 2, addrWidth: 8),
      );
      final upstreamResp = ReadyValidInterface(
        ResponseStructure(idWidth: 2, dataWidth: 8),
      );
      final downstreamReq = ReadyValidInterface(
        RequestStructure(idWidth: 2, addrWidth: 8),
      );
      final downstreamResp = ReadyValidInterface(
        ResponseStructure(idWidth: 2, dataWidth: 8),
      );

      final channel = BufferedRequestResponseChannel(
        clk: clk,
        reset: reset,
        upstreamRequestIntf: upstreamReq,
        upstreamResponseIntf: upstreamResp,
        downstreamRequestIntf: downstreamReq,
        downstreamResponseIntf: downstreamResp,
        requestBufferDepth: 3,
        responseBufferDepth: 3,
      );

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
      final upstreamReq = ReadyValidInterface(
        RequestStructure(idWidth: 2, addrWidth: 4),
      );
      final upstreamResp = ReadyValidInterface(
        ResponseStructure(idWidth: 2, dataWidth: 4),
      );
      final downstreamReq = ReadyValidInterface(
        RequestStructure(idWidth: 2, addrWidth: 4),
      );
      final downstreamResp = ReadyValidInterface(
        ResponseStructure(idWidth: 2, dataWidth: 4),
      );

      final channel = BufferedRequestResponseChannel(
        clk: clk,
        reset: reset,
        upstreamRequestIntf: upstreamReq,
        upstreamResponseIntf: upstreamResp,
        downstreamRequestIntf: downstreamReq,
        downstreamResponseIntf: downstreamResp,
        requestBufferDepth: 2, // Small FIFO for easy testing.
        responseBufferDepth: 2,
      );

      await channel.build();

      // Add WaveDumper at the beginning of simulation.
      // WaveDumper(channel, outputPath: 'rr_channel_backpressure.vcd');

      Simulator.setMaxSimTime(1000);
      unawaited(Simulator.run());

      // Reset sequence.
      reset.inject(1);
      upstreamReq.valid.inject(0);
      downstreamReq.ready
          .inject(0); // Initially not ready - creates backpressure.
      upstreamResp.ready.inject(1);
      downstreamResp.valid.inject(0);
      await clk.waitCycles(2);

      reset.inject(0);
      await clk.waitCycles(1);

      // Phase 1: Test FIFO filling and backpressure.
      // Phase 1: Testing FIFO capacity and backpressure

      // Send first request.
      upstreamReq.valid.inject(1);
      upstreamReq.data.id.inject(1);
      upstreamReq.data.addr.inject(0xA);
      await clk.nextPosedge;
      expect(upstreamReq.ready.value.toBool(), isTrue,
          reason: 'After req1: ready=${upstreamReq.ready.value}');

      // Send second request.
      upstreamReq.data.id.inject(2);
      upstreamReq.data.addr.inject(0xB);
      await clk.nextPosedge;
      // After req2: ready should be false since FIFO becomes full

      // FIFO should now be full (depth=2).
      expect(upstreamReq.ready.value.toBool(), isFalse,
          reason: 'FIFO should be full after 2 requests');

      // Phase 2: Test draining behavior.
      // Phase 2: Testing FIFO draining

      // Stop sending new requests to focus on draining.
      upstreamReq.valid.inject(0);

      // Enable downstream to start draining.
      downstreamReq.ready.inject(1);
      await clk.nextPosedge;

      // Verify basic draining behavior.
      expect(downstreamReq.valid.value.toBool(), isTrue,
          reason: 'Downstream should see valid data when draining');
      expect(upstreamReq.ready.value.toBool(), isTrue,
          reason: 'First item drained, ready=${upstreamReq.ready.value}');

      // Drain second item.
      await clk.nextPosedge;
      // Second item drained

      // FIFO should now be empty.
      await clk.nextPosedge;
      expect(downstreamReq.valid.value.toBool(), isFalse,
          reason: 'FIFO drained successfully - downstream should not be '
              'valid when FIFO empty');

      await Simulator.endSimulation();

      // Waveforms saved to rr_channel_backpressure.vcd
    });

    test('RR channel: response path backpressure', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      // Use narrow widths as requested.
      final upstreamReq = ReadyValidInterface(
        RequestStructure(idWidth: 2, addrWidth: 4),
      );
      final upstreamResp = ReadyValidInterface(
        ResponseStructure(idWidth: 2, dataWidth: 4),
      );
      final downstreamReq = ReadyValidInterface(
        RequestStructure(idWidth: 2, addrWidth: 4),
      );
      final downstreamResp = ReadyValidInterface(
        ResponseStructure(idWidth: 2, dataWidth: 4),
      );

      final channel = BufferedRequestResponseChannel(
        clk: clk,
        reset: reset,
        upstreamRequestIntf: upstreamReq,
        upstreamResponseIntf: upstreamResp,
        downstreamRequestIntf: downstreamReq,
        downstreamResponseIntf: downstreamResp,
        requestBufferDepth: 2,
        responseBufferDepth: 2, // Small FIFO for easy testing.
      );

      await channel.build();

      // WaveDumper(channel, outputPath:
      // 'rr_channel_response_backpressure.vcd');

      Simulator.setMaxSimTime(1000);
      unawaited(Simulator.run());

      // Reset sequence.
      reset.inject(1);
      upstreamReq.valid.inject(0);
      downstreamReq.ready.inject(1);
      upstreamResp.ready
          .inject(0); // Initially not ready - creates backpressure.
      downstreamResp.valid.inject(0);
      await clk.waitCycles(2);

      reset.inject(0);
      await clk.waitCycles(1);

      // Testing response path backpressure

      // Send responses from downstream back to upstream.
      downstreamResp.valid.inject(1);
      downstreamResp.data.id.inject(1);
      downstreamResp.data.data.inject(0xF1);
      await clk.nextPosedge;
      expect(downstreamResp.ready.value.toBool(), isTrue,
          reason: 'After resp1: ready=${downstreamResp.ready.value}');

      // Send second response.
      downstreamResp.data.id.inject(2);
      downstreamResp.data.data.inject(0xF2);
      await clk.nextPosedge;
      // After resp2: ready should be false since response FIFO becomes full

      // Response FIFO should now be full (depth=2).
      expect(downstreamResp.ready.value.toBool(), isFalse,
          reason: 'Response FIFO should be full after 2 responses');

      // Enable upstream to start draining response FIFO.
      upstreamResp.ready.inject(1);
      await clk.nextPosedge;

      // Verify draining behavior.
      expect(upstreamResp.valid.value.toBool(), isTrue,
          reason: 'Upstream should see valid response when draining');
      expect(downstreamResp.ready.value.toBool(), isTrue,
          reason: 'Response path backpressure test passed - '
              'downstream should become ready when space available');

      await Simulator.endSimulation();

      // Response waveforms saved to rr_channel_response_backpressure.vcd
    });
  });
}
