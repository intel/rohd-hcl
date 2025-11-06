// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// request_response_channel_test.dart
// Basic (non-buffered, non-cached) Request/Response channel tests.
//
// 2025 October 24
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
      upstreamResp.data.nonCacheable.inject(0);
      downstreamResp.data.nonCacheable.inject(0);

      final channel = RequestResponseChannel(
        upstreamRequestIntf: upstreamReq,
        upstreamResponseIntf: upstreamResp,
        downstreamRequestIntf: downstreamReq,
        downstreamResponseIntf: downstreamResp,
      );

      await channel.build();
      expect(channel.definitionName, contains('RequestResponseChannel'));
    });

    test('should have correct port structure', () async {
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
      upstreamResp.data.nonCacheable.inject(0);
      downstreamResp.data.nonCacheable.inject(0);

      final channel = RequestResponseChannel(
        upstreamRequestIntf: upstreamReq,
        upstreamResponseIntf: upstreamResp,
        downstreamRequestIntf: downstreamReq,
        downstreamResponseIntf: downstreamResp,
      );

      await channel.build();
      final portNames = {...channel.inputs.keys, ...channel.outputs.keys};
      expect(portNames.any((n) => n.contains('upstream_req')), isTrue);
      expect(portNames.any((n) => n.contains('upstream_resp')), isTrue);
      expect(portNames.any((n) => n.contains('downstream_req')), isTrue);
      expect(portNames.any((n) => n.contains('downstream_resp')), isTrue);
    });
  });
}
