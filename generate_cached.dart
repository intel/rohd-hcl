// Generate SystemVerilog for CachedRequestResponseChannel
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
  print('Generating SystemVerilog for CachedRequestResponseChannel...');

  final clk = SimpleClockGenerator(10).clk;
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

  // Generate CachedRequestResponseChannel SystemVerilog.
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

  Directory('generated').createSync(recursive: true);
  File('generated/CachedRequestResponseChannel.sv').writeAsStringSync(cachedSv);

  print('SystemVerilog generation complete!');
  print('Generated: generated/CachedRequestResponseChannel.sv');
  print('This shows the complete cached channel with clean FIFO naming!');
}
