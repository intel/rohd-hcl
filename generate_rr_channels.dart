// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// generate_rr_channels.dart
// Generate SystemVerilog for request/response channel components.
//
// 2025 October 26
// Author: GitHub Copilot <github-copilot@github.com>

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Helper function to create a cache factory.
Cache Function(Logic, Logic, List<ValidDataPortInterface>,
    List<ValidDataPortInterface>) createCacheFactory(
        int ways) =>
    (clk, reset, fills, reads) => FullyAssociativeCache(
          clk,
          reset,
          fills,
          reads,
          ways: ways,
        );

void main() async {
  // Create the generated directory if it doesn't exist.
  Directory('generated').createSync(recursive: true);

  // Create basic signals.
  final clk = Logic();
  final reset = Logic();

  // Create interfaces with 4-bit widths for testing.
  final upstreamReq = ReadyValidInterface(
    RequestStructure(idWidth: 4, addrWidth: 4),
  );
  final upstreamResp = ReadyValidInterface(
    ResponseStructure(idWidth: 4, dataWidth: 4),
  );
  final downstreamReq = ReadyValidInterface(
    RequestStructure(idWidth: 4, addrWidth: 4),
  );
  final downstreamResp = ReadyValidInterface(
    ResponseStructure(idWidth: 4, dataWidth: 4),
  );

  print('Generating SystemVerilog for request/response channels...');

  // Generate RequestResponseChannel SystemVerilog.
  print('- RequestResponseChannel');
  final basicChannel = RequestResponseChannel(
    clk: clk,
    reset: reset,
    upstreamRequestIntf: upstreamReq,
    upstreamResponseIntf: upstreamResp,
    downstreamRequestIntf: downstreamReq,
    downstreamResponseIntf: downstreamResp,
  );

  await basicChannel.build();
  final basicSv = basicChannel.generateSynth();
  File('generated/RequestResponseChannel.sv').writeAsStringSync(basicSv);

  // Generate BufferedRequestResponseChannel SystemVerilog.
  print('- BufferedRequestResponseChannel');
  final bufferedChannel = BufferedRequestResponseChannel(
    clk: clk,
    reset: reset,
    upstreamRequestIntf: upstreamReq,
    upstreamResponseIntf: upstreamResp,
    downstreamRequestIntf: downstreamReq,
    downstreamResponseIntf: downstreamResp,
  );

  await bufferedChannel.build();
  final bufferedSv = bufferedChannel.generateSynth();
  File('generated/BufferedRequestResponseChannel.sv')
      .writeAsStringSync(bufferedSv);

  // Generate CachedRequestResponseChannel SystemVerilog.
  print('- CachedRequestResponseChannel');
  final cachedChannel = CachedRequestResponseChannel(
    clk: clk,
    reset: reset,
    upstreamRequestIntf: upstreamReq,
    upstreamResponseIntf: upstreamResp,
    downstreamRequestIntf: downstreamReq,
    downstreamResponseIntf: downstreamResp,
    cacheFactory: createCacheFactory(8),
    responseBufferDepth: 8,
  );

  await cachedChannel.build();
  final cachedSv = cachedChannel.generateSynth();
  File('generated/CachedRequestResponseChannel.sv').writeAsStringSync(cachedSv);

  print('SystemVerilog generation complete! Files saved to generated/');
  print('- generated/RequestResponseChannel.sv');
  print('- generated/BufferedRequestResponseChannel.sv');
  print('- generated/CachedRequestResponseChannel.sv');
}
