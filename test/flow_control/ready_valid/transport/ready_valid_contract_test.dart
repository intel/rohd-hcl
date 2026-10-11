// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_contract_test.dart
// Tests ready/valid contract and typed-interface foundations.
//
// 2026 October 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Packet extends LogicStructure {
  Logic get data => elements[0];
  Logic get tag => elements[1];

  _Packet({String name = 'packet'})
      : super(
          [
            Logic(name: 'data', width: 8),
            Logic(name: 'tag', width: 2),
          ],
          name: name,
        );

  _Packet._clone(LogicStructure original, {String? name})
      : super(
          original.elements.map((element) => element.clone()).toList(),
          name: name ?? original.name,
        );

  @override
  _Packet clone({String? name}) => _Packet._clone(this, name: name);
}

class _ConsumerPortHarness extends Module {
  late final ReadyValidInterface<_Packet> channel;

  _ConsumerPortHarness(ReadyValidInterface<_Packet> source) {
    channel = addPairInterface(
      source,
      PairRole.consumer,
      uniquify: (original) => 'channel_$original',
    );
  }
}

class _ProviderPortHarness extends Module {
  late final ReadyValidInterface<_Packet> channel;

  _ProviderPortHarness(ReadyValidInterface<_Packet> source) {
    channel = addPairInterface(
      source,
      PairRole.provider,
      uniquify: (original) => 'channel_$original',
    );
  }
}

class _PredicateHarness extends Module {
  Logic get accepted => output('accepted');
  Logic get stalled => output('stalled');

  _PredicateHarness({
    required Logic ready,
    required Logic valid,
  }) {
    final channel = ReadyValidInterface<Logic>(
      Logic(width: 8, name: 'payload'),
    );
    channel.ready <= addInput('ready', ready);
    channel.valid <= addInput('valid', valid);
    addOutput('accepted') <= channel.accepted;
    addOutput('stalled') <= channel.stalled;
  }
}

class _ReadyThenAdapterHarness extends Module {
  late final ReadyAndValidInterface<_Packet> downstream;

  _ReadyThenAdapterHarness({
    required Logic clk,
    required Logic reset,
    required ReadyThenValidInterface<_Packet> upstream,
    required ReadyAndValidInterface<_Packet> downstream,
  }) : super(definitionName: 'ReadyThenAdapterHarness') {
    final localUpstream = addPairInterface(
      upstream,
      PairRole.consumer,
      uniquify: (original) => 'upstream_$original',
    );
    this.downstream = localUpstream.toDownstreamReadyAndValid(
      addInput('clk', clk),
      addInput('reset', reset),
    );
    addPairInterfaceFrom(
      this.downstream,
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );
  }
}

void main() {
  tearDown(Simulator.reset);

  group('ReadyValidContract', () {
    test('supports value equality, hashing, and immutable copies', () {
      final equivalent = ReadyValidContract.irrevocable.copyWith();
      final equivalentSet = <ReadyValidContract>{equivalent}
        ..add(ReadyValidContract.irrevocable);

      expect(equivalent, ReadyValidContract.irrevocable);
      expect(equivalent.hashCode, ReadyValidContract.irrevocable.hashCode);
      expect(equivalentSet, hasLength(1));
      expect(
        equivalent.copyWith(payloadMustRemainStableWhileStalled: false),
        const ReadyValidContract(
          validMayDependOnReady: false,
          readyMayDependOnValid: true,
          validMustRemainAssertedWhileStalled: true,
        ),
      );
    });

    test('defines the complete compatibility relation', () {
      final contracts = <String, ReadyValidContract>{
        'unconstrained': ReadyValidContract.unconstrained,
        'readyAndValid': ReadyValidContract.readyAndValid,
        'readyThenValid': ReadyValidContract.readyThenValid,
        'validThenReady': ReadyValidContract.validThenReady,
        'irrevocable': ReadyValidContract.irrevocable,
      };
      final satisfiedRequirements = <String, Set<String>>{
        'unconstrained': {'unconstrained'},
        'readyAndValid': {
          'unconstrained',
          'readyAndValid',
          'readyThenValid',
          'validThenReady',
        },
        'readyThenValid': {'unconstrained', 'readyThenValid'},
        'validThenReady': {'unconstrained', 'validThenReady'},
        'irrevocable': {'unconstrained', 'validThenReady', 'irrevocable'},
      };

      for (final actual in contracts.entries) {
        for (final required in contracts.entries) {
          expect(
            actual.value.satisfies(required.value),
            satisfiedRequirements[actual.key]!.contains(required.key),
            reason: '${actual.key} satisfying ${required.key}',
          );
        }
      }
    });

    test('detects only provider-valid/consumer-ready dependency cycles', () {
      expect(
        ReadyValidContract.readyThenValid.mayFormDependencyCycleWith(
          ReadyValidContract.validThenReady,
        ),
        isTrue,
      );
      expect(
        ReadyValidContract.validThenReady.mayFormDependencyCycleWith(
          ReadyValidContract.readyThenValid,
        ),
        isFalse,
      );
      expect(
        () => ReadyValidContract.requireComposable(
          provider: ReadyValidContract.readyThenValid,
          consumer: ReadyValidContract.validThenReady,
          providerName: 'producer',
          consumerName: 'consumer',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            allOf(contains('producer'), contains('consumer')),
          ),
        ),
      );
      expect(
        () => ReadyValidContract.requireComposable(
          provider: ReadyValidContract.readyAndValid,
          consumer: ReadyValidContract.validThenReady,
          providerName: 'producer',
          consumerName: 'consumer',
        ),
        returnsNormally,
      );
    });
  });

  group('ReadyValidInterface', () {
    test('preserves constructor compatibility and clone metadata', () {
      final base = ReadyValidInterface<Logic>(Logic(width: 8));
      final custom = ReadyValidInterface<Logic>(
        Logic(width: 8),
        contract: ReadyValidContract.irrevocable,
      );

      expect(base.contract, ReadyValidContract.unconstrained);
      expect(custom.clone().contract, same(custom.contract));
      expect(custom.clone().data, isNot(same(custom.data)));
    });

    test('exposes finalized variants and preserves their concrete types', () {
      final independent = ReadyAndValidInterface<Logic>(Logic(width: 8));
      final readyFirst = ReadyThenValidInterface<Logic>(Logic(width: 8));
      final validFirst = ValidThenReadyInterface<Logic>(Logic(width: 8));
      final irrevocable =
          IrrevocableReadyValidInterface<Logic>(Logic(width: 8));

      expect(independent.contract, ReadyValidContract.readyAndValid);
      expect(readyFirst.contract, ReadyValidContract.readyThenValid);
      expect(validFirst.contract, ReadyValidContract.validThenReady);
      expect(irrevocable.contract, ReadyValidContract.irrevocable);
      expect(independent.clone(), isA<ReadyAndValidInterface<Logic>>());
      expect(readyFirst.clone(), isA<ReadyThenValidInterface<Logic>>());
      expect(validFirst.clone(), isA<ValidThenReadyInterface<Logic>>());
      expect(
        irrevocable.clone(),
        isA<IrrevocableReadyValidInterface<Logic>>(),
      );
    });

    test('exposes cached accepted and stalled predicates', () async {
      final channel = ReadyValidInterface<Logic>(
        Logic(width: 8, name: 'payload'),
      );

      expect(identical(channel.accepted, channel.accepted), isTrue);
      expect(identical(channel.stalled, channel.stalled), isTrue);
      expect(channel.accepted.name, 'payload_accepted');
      expect(channel.stalled.name, 'payload_stalled');

      final ready = Logic();
      final valid = Logic();
      final harness = _PredicateHarness(ready: ready, valid: valid);
      await harness.build();
      valid.inject(1);
      ready.inject(0);
      await Simulator.tick();
      expect(harness.accepted.value, LogicValue.zero);
      expect(harness.stalled.value, LogicValue.one);
      ready.inject(1);
      await Simulator.tick();
      expect(harness.accepted.value, LogicValue.one);
      expect(harness.stalled.value, LogicValue.zero);
    });

    test('offers interface-level composability checks', () {
      final provider = ReadyThenValidInterface<Logic>(
        Logic(width: 8, name: 'provider_payload'),
      );
      final consumer = ValidThenReadyInterface<Logic>(
        Logic(width: 8, name: 'consumer_payload'),
      );

      expect(
        () => provider.requireProviderComposableWith(
          consumer.contract,
          consumerName: consumer.data.name,
        ),
        throwsArgumentError,
      );
      expect(
        () => consumer.requireConsumerComposableWith(
          provider.contract,
          providerName: provider.data.name,
        ),
        throwsArgumentError,
      );
    });

    test('retains typed structure ports and contract metadata as consumer',
        () async {
      final source = ReadyValidInterface<_Packet>(
        _Packet(),
        contract: ReadyValidContract.irrevocable,
      );
      final harness = _ConsumerPortHarness(source);

      expect(harness.inputs['channel_packet'], isA<_Packet>());
      expect(harness.inputs['channel_valid'], isA<Logic>());
      expect(harness.outputs['channel_ready'], isA<Logic>());
      expect(harness.channel.data, isA<_Packet>());
      expect(harness.channel.contract, ReadyValidContract.irrevocable);

      await harness.build();
      expect(
        harness.generateSynth(),
        contains('input logic [9:0] channel_packet'),
      );
      expect(harness.generateSynth(), contains('packet_data'));
      expect(harness.generateSynth(), contains('packet_tag'));
    });

    test('retains typed structure ports as provider', () async {
      final source = ReadyValidInterface<_Packet>(_Packet());
      final harness = _ProviderPortHarness(source);

      expect(harness.inputs['channel_ready'], isA<Logic>());
      expect(harness.outputs['channel_packet'], isA<_Packet>());
      expect(harness.outputs['channel_valid'], isA<Logic>());
      expect(harness.channel.data, isA<_Packet>());

      await harness.build();
      expect(
        harness.generateSynth(),
        contains('output logic [9:0] channel_packet'),
      );
      expect(harness.generateSynth(), contains('packet_data'));
      expect(harness.generateSynth(), contains('packet_tag'));
    });

    test('ready-then-valid compatibility adapter builds with the P00 FIFO',
        () async {
      final harness = _ReadyThenAdapterHarness(
        clk: Logic(),
        reset: Logic(),
        upstream: ReadyThenValidInterface<_Packet>(_Packet()),
        downstream: ReadyAndValidInterface<_Packet>(_Packet()),
      );

      await harness.build();
      final systemVerilog = harness.generateSynth();
      expect(systemVerilog, contains('Fifo_D2_W10'));
      expect(systemVerilog, contains('ReadyThenAdapterHarness'));
    });
  });
}
