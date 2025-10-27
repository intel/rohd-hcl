// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// request_response_channel_test.dart
// Tests for the basic RequestResponseChannel component.
//
// 2025 October 26
// Author: GitHub Copilot <github-copilot@github.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('RequestResponseChannel', () {
    test('should build successfully', () async {
      final clk = Logic();
      final reset = Logic();

      final upstreamReq = ReadyValidInterface(
        RequestStructure(idWidth: 4, addrWidth: 32),
      );
      final upstreamResp = ReadyValidInterface(
        ResponseStructure(idWidth: 4, dataWidth: 32),
      );
      final downstreamReq = ReadyValidInterface(
        RequestStructure(idWidth: 4, addrWidth: 32),
      );
      final downstreamResp = ReadyValidInterface(
        ResponseStructure(idWidth: 4, dataWidth: 32),
      );

      final channel = RequestResponseChannel(
        clk: clk,
        reset: reset,
        upstreamRequestIntf: upstreamReq,
        upstreamResponseIntf: upstreamResp,
        downstreamRequestIntf: downstreamReq,
        downstreamResponseIntf: downstreamResp,
      );

      await channel.build();

      // Verify the module was built successfully.
      expect(channel.definitionName, contains('RequestResponseChannel'));
    });

    test('should have correct port structure', () async {
      final clk = Logic();
      final reset = Logic();

      final upstreamReq = ReadyValidInterface(
        RequestStructure(idWidth: 4, addrWidth: 32),
      );
      final upstreamResp = ReadyValidInterface(
        ResponseStructure(idWidth: 4, dataWidth: 32),
      );
      final downstreamReq = ReadyValidInterface(
        RequestStructure(idWidth: 4, addrWidth: 32),
      );
      final downstreamResp = ReadyValidInterface(
        ResponseStructure(idWidth: 4, dataWidth: 32),
      );

      final channel = RequestResponseChannel(
        clk: clk,
        reset: reset,
        upstreamRequestIntf: upstreamReq,
        upstreamResponseIntf: upstreamResp,
        downstreamRequestIntf: downstreamReq,
        downstreamResponseIntf: downstreamResp,
      );

      await channel.build();

      // Verify the module has expected inputs and outputs.
      expect(channel.inputs.keys, contains('clk'));
      expect(channel.inputs.keys, contains('reset'));

      // Check that interfaces are properly connected by looking for their
      // ports.
      final portNames = {...channel.inputs.keys, ...channel.outputs.keys};

      // Should have upstream request ports (consumer role - inputs).
      expect(portNames.any((name) => name.contains('upstream_req')), isTrue);

      // Should have upstream response ports (provider role - outputs).
      expect(portNames.any((name) => name.contains('upstream_resp')), isTrue);

      // Should have downstream request ports (provider role - outputs).
      expect(portNames.any((name) => name.contains('downstream_req')), isTrue);

      // Should have downstream response ports (consumer role - inputs).
      expect(portNames.any((name) => name.contains('downstream_resp')), isTrue);
    });
  });
}
