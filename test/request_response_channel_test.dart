// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// request_response_channel_test.dart
// Tests for the RequestResponseChannel component.
//
// 2025 October 19
// Author: Assistant

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/ready_valid_interface.dart';
import 'package:rohd_hcl/src/request_response_channel.dart';
import 'package:rohd_hcl/src/request_response_structures.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  /// Helper function to create interfaces from widths
  ({
    ReadyValidInterface<RequestStructure> upstreamRequest,
    ReadyValidInterface<ResponseStructure> upstreamResponse,
    ReadyValidInterface<RequestStructure> downstreamRequest,
    ReadyValidInterface<ResponseStructure> downstreamResponse
  }) createInterfaces({
    required int idWidth,
    required int addressWidth,
    required int dataWidth,
  }) {
    // Create the request and response structures
    final requestStructure = RequestStructure(
      idWidth: idWidth,
      addressWidth: addressWidth,
    );
    final responseStructure = ResponseStructure(
      idWidth: idWidth,
      dataWidth: dataWidth,
    );

    // Create the ReadyValidInterface pairs
    return (
      upstreamRequest: ReadyValidInterface(requestStructure),
      upstreamResponse: ReadyValidInterface(responseStructure),
      downstreamRequest: ReadyValidInterface(requestStructure.clone()),
      downstreamResponse: ReadyValidInterface(responseStructure.clone()),
    );
  }

  group('RequestResponseChannel tests', () {
    test('RequestResponseChannel smoke test - basic instantiation', () async {
      final interfaces = createInterfaces(
        idWidth: 4,
        addressWidth: 32,
        dataWidth: 64,
      );

      final channel = RequestResponseChannel(
        clk: Logic(),
        reset: Logic(),
        upstreamRequestIntf: interfaces.upstreamRequest,
        upstreamResponseIntf: interfaces.upstreamResponse,
        downstreamRequestIntf: interfaces.downstreamRequest,
        downstreamResponseIntf: interfaces.downstreamResponse,
      );

      await channel.build();

      // Verify the component was built successfully
      expect(channel.name, equals('request_response_channel'));
    });

    test('RequestResponseChannel forwarding test', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final interfaces = createInterfaces(
        idWidth: 4,
        addressWidth: 32,
        dataWidth: 64,
      );

      final channel = RequestResponseChannel(
        clk: clk,
        reset: reset,
        upstreamRequestIntf: interfaces.upstreamRequest,
        upstreamResponseIntf: interfaces.upstreamResponse,
        downstreamRequestIntf: interfaces.downstreamRequest,
        downstreamResponseIntf: interfaces.downstreamResponse,
      );

      await channel.build();

      // Create test values
      const testId = 0x5;
      const testAddress = 0x12345678;
      final testData = BigInt.from(0x12347890ABCDEF);

      // Start simulation
      unawaited(Simulator.run());

      // Reset sequence
      reset.inject(1);
      await clk.waitCycles(3);
      reset.inject(0);
      await clk.waitCycles(1);

      // Test request forwarding from upstream to downstream
      // Send a request from upstream
      channel.upstreamRequest.data.id.inject(testId);
      channel.upstreamRequest.data.address.inject(testAddress);
      channel.upstreamRequest.valid.inject(1);

      // Downstream should be ready to accept
      channel.downstreamRequest.ready.inject(1);

      await clk.nextNegedge;

      // Check that request was forwarded correctly
      expect(channel.downstreamRequest.data.id.value.toInt(), equals(testId));
      expect(channel.downstreamRequest.data.address.value.toInt(),
          equals(testAddress));
      expect(channel.downstreamRequest.valid.value.toBool(), isTrue);
      expect(channel.upstreamRequest.ready.value.toBool(), isTrue);

      // Test response forwarding from downstream to upstream
      // Send a response from downstream
      channel.downstreamResponse.data.id.inject(testId);
      channel.downstreamResponse.data.data.inject(testData);
      channel.downstreamResponse.valid.inject(1);

      // Upstream should be ready to accept
      channel.upstreamResponse.ready.inject(1);

      await clk.nextNegedge;

      // Check that response was forwarded correctly
      expect(channel.upstreamResponse.data.id.value.toInt(), equals(testId));
      expect(BigInt.from(channel.upstreamResponse.data.data.value.toInt()),
          equals(testData));
      expect(channel.upstreamResponse.valid.value.toBool(), isTrue);
      expect(channel.downstreamResponse.ready.value.toBool(), isTrue);

      await Simulator.endSimulation();
    });

    test('RequestResponseChannel with different widths', () async {
      // Test with different widths to ensure flexibility
      final interfaces = createInterfaces(
        idWidth: 8,
        addressWidth: 64,
        dataWidth: 128,
      );

      final channel = RequestResponseChannel(
        clk: Logic(),
        reset: Logic(),
        upstreamRequestIntf: interfaces.upstreamRequest,
        upstreamResponseIntf: interfaces.upstreamResponse,
        downstreamRequestIntf: interfaces.downstreamRequest,
        downstreamResponseIntf: interfaces.downstreamResponse,
      );

      await channel.build();

      // Verify the component handles different widths correctly
      expect(channel.upstreamRequest.data.id.width, equals(8));
      expect(channel.upstreamRequest.data.address.width, equals(64));
      expect(channel.upstreamResponse.data.data.width, equals(128));
      expect(channel.downstreamRequest.data.id.width, equals(8));
      expect(channel.downstreamRequest.data.address.width, equals(64));
      expect(channel.downstreamResponse.data.data.width, equals(128));
    });

    test('RequestResponseChannel backpressure test', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final interfaces = createInterfaces(
        idWidth: 4,
        addressWidth: 32,
        dataWidth: 64,
      );

      final channel = RequestResponseChannel(
        clk: clk,
        reset: reset,
        upstreamRequestIntf: interfaces.upstreamRequest,
        upstreamResponseIntf: interfaces.upstreamResponse,
        downstreamRequestIntf: interfaces.downstreamRequest,
        downstreamResponseIntf: interfaces.downstreamResponse,
      );

      await channel.build();

      unawaited(Simulator.run());

      // Reset sequence
      reset.inject(1);
      await clk.waitCycles(3);
      reset.inject(0);
      await clk.waitCycles(1);

      // Test backpressure propagation
      // Send a request but downstream is not ready
      channel.upstreamRequest.data.id.inject(1);
      channel.upstreamRequest.data.address.inject(0x1000);
      channel.upstreamRequest.valid.inject(1);

      // Downstream not ready
      channel.downstreamRequest.ready.inject(0);

      await clk.nextNegedge;

      // Upstream ready should be false (backpressure)
      expect(channel.upstreamRequest.ready.value.toBool(), isFalse);

      // Now make downstream ready
      channel.downstreamRequest.ready.inject(1);

      await clk.nextNegedge;

      // Now upstream ready should be true
      expect(channel.upstreamRequest.ready.value.toBool(), isTrue);

      await Simulator.endSimulation();
    });
  });

  group('BufferedRequestResponseChannel tests', () {
    test('BufferedRequestResponseChannel smoke test', () async {
      final interfaces = createInterfaces(
        idWidth: 4,
        addressWidth: 32,
        dataWidth: 64,
      );

      final bufferedChannel = BufferedRequestResponseChannel(
        clk: Logic(),
        reset: Logic(),
        upstreamRequestIntf: interfaces.upstreamRequest,
        upstreamResponseIntf: interfaces.upstreamResponse,
        downstreamRequestIntf: interfaces.downstreamRequest,
        downstreamResponseIntf: interfaces.downstreamResponse,
        requestBufferDepth: 8,
      );

      await bufferedChannel.build();

      // Verify the component was built successfully
      expect(bufferedChannel.name, equals('buffered_request_response_channel'));
      expect(bufferedChannel.requestBufferDepth, equals(8));
      expect(bufferedChannel.responseBufferDepth, equals(4));
    });

    test('BufferedRequestResponseChannel structure verification', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final interfaces = createInterfaces(
        idWidth: 4,
        addressWidth: 32,
        dataWidth: 64,
      );

      final bufferedChannel = BufferedRequestResponseChannel(
        clk: clk,
        reset: reset,
        upstreamRequestIntf: interfaces.upstreamRequest,
        upstreamResponseIntf: interfaces.upstreamResponse,
        downstreamRequestIntf: interfaces.downstreamRequest,
        downstreamResponseIntf: interfaces.downstreamResponse,
        requestBufferDepth: 8,
      );

      await bufferedChannel.build();

      // Verify the FIFOs were created with correct depths
      // ignore: invalid_use_of_protected_member
      expect(bufferedChannel.requestFifo, isNotNull);
      // ignore: invalid_use_of_protected_member
      expect(bufferedChannel.responseFifo, isNotNull);
      // ignore: invalid_use_of_protected_member
      expect(bufferedChannel.requestFifo.depth, equals(8));
      // ignore: invalid_use_of_protected_member
      expect(bufferedChannel.responseFifo.depth, equals(4));
      expect(bufferedChannel.requestBufferDepth, equals(8));
      expect(bufferedChannel.responseBufferDepth, equals(4));

      //  Verify that the buffered channel is a proper extension of the base
      // class
      expect(bufferedChannel, isA<RequestResponseChannelBase>());
      expect(bufferedChannel.name, equals('buffered_request_response_channel'));
    });
  });

  group('Abstract base class tests', () {
    test('Custom channel implementation', () async {
      // Test that we can extend the base class
      final interfaces = createInterfaces(
        idWidth: 4,
        addressWidth: 32,
        dataWidth: 64,
      );

      final customChannel = _TestChannel(
        clk: Logic(),
        reset: Logic(),
        upstreamRequestIntf: interfaces.upstreamRequest,
        upstreamResponseIntf: interfaces.upstreamResponse,
        downstreamRequestIntf: interfaces.downstreamRequest,
        downstreamResponseIntf: interfaces.downstreamResponse,
      );

      await customChannel.build();

      // Verify the custom channel was built successfully
      expect(customChannel.name, equals('test_channel'));
      expect(customChannel.buildLogicCalled, isTrue);
    });
  });

  group('LogicStructure tests', () {
    test('RequestStructure creation and access', () {
      final request = RequestStructure(idWidth: 4, addressWidth: 32);

      expect(request.id.width, equals(4));
      expect(request.address.width, equals(32));
      expect(request.width, equals(36)); // 4 + 32
    });

    test('ResponseStructure creation and access', () {
      final response = ResponseStructure(idWidth: 4, dataWidth: 64);

      expect(response.id.width, equals(4));
      expect(response.data.width, equals(64));
      expect(response.width, equals(68)); // 4 + 64
    });

    test('LogicStructure cloning', () {
      final request1 = RequestStructure(idWidth: 8, addressWidth: 64);
      final request2 = request1.clone();

      expect(request2.id.width, equals(8));
      expect(request2.address.width, equals(64));
      expect(request2.width, equals(request1.width));

      // They should be different instances
      expect(identical(request1, request2), isFalse);
    });
  });
}

/// Test implementation to verify the abstract base class works
class _TestChannel extends RequestResponseChannelBase {
  bool buildLogicCalled = false;

  _TestChannel({
    required super.clk,
    required super.reset,
    required super.upstreamRequestIntf,
    required super.upstreamResponseIntf,
    required super.downstreamRequestIntf,
    required super.downstreamResponseIntf,
  }) : super(name: 'test_channel');

  @override
  void buildLogic() {
    buildLogicCalled = true;
    // Minimal implementation - just connect interfaces
    downstreamRequest.data <= upstreamRequest.data;
    downstreamRequest.valid <= upstreamRequest.valid;
    upstreamRequest.ready <= downstreamRequest.ready;

    upstreamResponse.data <= downstreamResponse.data;
    upstreamResponse.valid <= downstreamResponse.valid;
    downstreamResponse.ready <= upstreamResponse.ready;
  }
}
