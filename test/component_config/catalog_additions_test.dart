// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// catalog_additions_test.dart
// Tests for additional component configurators.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

// Verify the legacy FIFO configurator remains available.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:convert';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/component_config/components/component_registry.dart';
import 'package:test/test.dart';

class _Parent extends Module {
  _Parent(Module child) {
    final childOutput = child.outputs.values.first;
    addOutput('out', width: childOutput.width) <= childOutput;
  }
}

void main() {
  test('requested configurators are registered', () {
    final names = componentRegistry.map((configurator) => configurator.name);
    expect(
      names,
      containsAll([
        'Absolute Value',
        'Circular Pointer',
        'Ceil Divide',
        'Multiplexer',
        'Bitwise Popcount',
        'Parallel Prefix Scan',
        'Sparse to Dense',
        'Binary to Thermometer',
        'Thermometer to Binary',
        'Clock Enable Divider',
        'Floating-Point Classifier',
        'Floating-Point Comparator',
        'Accumulator',
        'Numeric Narrowing',
        'Majority',
        'First-Match Prefix',
        'Iterative Divider Engine',
        'Ready/Valid Iterative Divider',
        'Valid-Only Carry-Save Multiplier',
        'Fixed-Latency Tracker',
        'Fixed-Latency Ready/Valid Delay Example',
        '4:2 Compressor',
        'Binary Linear/Affine Transform',
        'Binary Linear Recurrence',
        'GF Constant Multiplier',
        'GF Inverse',
        'GF Polynomial Evaluator',
        'Serial LFSR',
        'Parallel LFSR',
        'Tap-List LFSR',
        'Signature Analyzer',
        'PRBS Generator',
        'PRBS Checker',
        'Pad',
        'Set Bits',
        'With Set',
        'Synchronizer',
        'Ready/Valid Queue',
        'Parallel Associative Memory',
        'CSR Example',
      ]),
    );
  });

  test('compute and binary configurators round-trip and generate', () async {
    final configs = <Configurator>[
      AccumulatorConfigurator(),
      NumericNarrowingConfigurator(),
      MajorityConfigurator(),
      FirstMatchPrefixConfigurator(),
      IterativeDividerEngineConfigurator(),
      ReadyValidIterativeDividerConfigurator(),
      ValidOnlyCarrySaveMultiplierConfigurator(),
      FixedLatencyTrackerConfigurator(),
      ReadyValidFixedLatencyConfigurator(),
      Compressor4Configurator(),
      BinaryLinearTransformConfigurator(),
      BinaryLinearRecurrenceConfigurator(),
      GfConstantMultiplierConfigurator(),
      GfInverseConfigurator(),
      GfPolynomialEvaluatorConfigurator(),
      SerialLfsrConfigurator(),
      ParallelLfsrConfigurator(),
      LfsrConfigurator(),
      SignatureAnalyzerConfigurator(),
      PrbsGeneratorConfigurator(),
      PrbsCheckerConfigurator(),
    ];
    for (final config in configs) {
      final restored = componentRegistry.singleWhere(
          (candidate) => candidate.runtimeType == config.runtimeType)
        ..loadJson(config.toJson());
      expect(restored.toJson(), config.toJson(), reason: config.name);
      expect(restored.createModule().runtimeType,
          config.createModule().runtimeType,
          reason: config.name);
      expect(await restored.generateSV(), contains('module '),
          reason: config.name);
      await _Parent(restored.createModule()).build();
    }
  });

  test('binary-math controls configure hardware and reject invalid input',
      () async {
    final transform = BinaryLinearTransformConfigurator()
      ..rowsKnob.value = '10, 01'
      ..offsetKnob.value = '1';
    final restored = BinaryLinearTransformConfigurator()
      ..loadJson(transform.toJson());
    final module = restored.createModule() as BinaryLinearTransform;
    await module.build();
    module.input('data_in').put(2);
    expect(module.result.value.toInt(), 0);

    final lfsr = LfsrConfigurator()
      ..widthKnob.value = 5
      ..tapsKnob.value = '1, 3'
      ..stepsKnob.value = 2;
    final restoredLfsr = LfsrConfigurator()..loadJson(lfsr.toJson());
    final lfsrModule = restoredLfsr.createModule() as Lfsr;
    expect(lfsrModule.lfsrDescriptor.polynomial.coefficients,
        (BigInt.one << 5) | (BigInt.one << 3) | (BigInt.one << 1));
    expect(lfsrModule.stepsPerCycle, 2);
    lfsr.tapsKnob.value = '1, invalid';
    expect(lfsr.createModule, throwsFormatException);

    final field = GfConstantMultiplierConfigurator()
      ..modulusKnob.value = '13'
      ..constantKnob.value = '3';
    final fieldModule = field.createModule() as GfConstantMultiplier;
    expect(fieldModule.constant.value, BigInt.from(3));
    field.modulusKnob.value = '15';
    expect(field.createModule, throwsA(isA<RohdHclException>()));

    final prbs = PrbsCheckerConfigurator()
      ..customPolynomialKnob.value = true
      ..polynomialKnob.value = '13'
      ..customSeedKnob.value = true
      ..seedKnob.value = '3'
      ..bitsKnob.value = 2;
    final restoredPrbs = PrbsCheckerConfigurator()..loadJson(prbs.toJson());
    final checker = restoredPrbs.createModule() as PrbsChecker;
    expect(checker.configuration.lfsrDescriptor.polynomial.coefficients,
        BigInt.from(0x13));
    expect(checker.configuration.seed, BigInt.from(3));
    expect(checker.bitsPerCycle, 2);

    final recurrence = BinaryLinearRecurrenceConfigurator()
      ..hasInputKnob.value = true
      ..inputRowsKnob.value = '10, 01, 11, 00'
      ..enableKnob.value = true
      ..loadKnob.value = true;
    final restoredRecurrence = BinaryLinearRecurrenceConfigurator()
      ..loadJson(recurrence.toJson());
    final recurrenceModule =
        restoredRecurrence.createModule() as BinaryLinearRecurrence;
    expect(recurrenceModule.descriptor.inputWidth, 2);
    expect(recurrenceModule.inputs.keys,
        containsAll(['data_in', 'enable', 'load', 'load_state']));
    await recurrenceModule.build();
  });

  test('fixed-latency wrapper configures timing and IDs', () async {
    final configured = ReadyValidFixedLatencyConfigurator()
      ..widthKnob.value = 6
      ..latencyKnob.value = 2
      ..intervalKnob.value = 2
      ..capacityKnob.value = 3
      ..useIdKnob.value = true
      ..idWidthKnob.value = 5;
    final restored = ReadyValidFixedLatencyConfigurator()
      ..loadJson(configured.toJson());
    final wrapper = restored.createModule() as ReadyValidFixedLatency;
    expect(wrapper.latency, 2);
    expect(wrapper.initiationInterval, 2);
    expect(wrapper.capacity, 3);
    expect(wrapper.input('request_id').width, 5);
    expect(wrapper.resultId!.width, 5);
    await wrapper.build();
  });

  test('compression and serialization options round-trip', () async {
    final config = MultiplyAccumulateConfigurator()
      ..use42CompressorsKnob.value = true
      ..customDelayKnob.value = true;
    (config.compressionDelayKnob.subKnobs['3:2 Sum']! as StringConfigKnob)
        .value = '2, 3, 4';
    final restored = MultiplyAccumulateConfigurator()
      ..loadJson(config.toJson());
    expect(restored.toJson(), config.toJson());
    final module = restored.createModule();
    await module.build();
    final tree = module.subModules.whereType<ColumnCompressor>().single;
    expect(tree.use42Compressors, isTrue);
    expect(tree.delayConfig.compressor3.sum, [2, 3, 4]);
    (config.compressionDelayKnob.subKnobs['3:2 Sum']! as StringConfigKnob)
        .value = 'bad';
    expect(config.createModule, throwsFormatException);
    (config.compressionDelayKnob.subKnobs['3:2 Sum']! as StringConfigKnob)
        .value = '1, -2, 3';
    expect(config.createModule, throwsArgumentError);

    final dot = DotProductConfigurator()
      ..implementationKnob.value = DotProductImplementation.compressionTree
      ..use42CompressorsKnob.value = true
      ..customDelayKnob.value = true;
    final restoredDot = DotProductConfigurator()..loadJson(dot.toJson());
    final dotModule = restoredDot.createModule();
    await dotModule.build();
    expect(
        dotModule.subModules
            .whereType<ColumnCompressor>()
            .single
            .use42Compressors,
        isTrue);
    expect(restoredDot.toJson(), dot.toJson());

    final multiplier = MultiplierConfigurator();
    multiplier.multiplierSelectKnob.compressionTreeMultiplierKnob.value = true;
    multiplier.multiplierSelectKnob.use42CompressorsKnob.value = true;
    multiplier.multiplierSelectKnob.customDelayKnob.value = true;
    final restoredMultiplier = MultiplierConfigurator()
      ..loadJson(multiplier.toJson());
    expect(restoredMultiplier.toJson(), multiplier.toJson());
    expect(await restoredMultiplier.generateSV(), contains('Compressor4'));

    final serializer = SerializationConfigurator()
      ..flopInputKnob.value = true
      ..alignOutputLatencyKnob.value = true;
    final restoredSerializer = SerializationConfigurator()
      ..loadJson(serializer.toJson());
    expect(restoredSerializer.toJson(), serializer.toJson());
    expect(await restoredSerializer.generateSV(), contains('module '));
  });

  test('configured serializer forwards aligned timing', () async {
    addTearDown(Simulator.reset);
    final config = SerializationConfigurator()
      ..inputWidthKnob.value = 8
      ..inputLengthKnob.value = 3
      ..enableKnob.value = true
      ..flopInputKnob.value = true
      ..alignOutputLatencyKnob.value = true;
    final restored = SerializationConfigurator()..loadJson(config.toJson());
    final serializer = restored.createModule();
    await serializer.build();
    await SimCompare.checkFunctionalVector(serializer, [
      Vector({'clk': 0, 'reset': 1, 'enable': 0, 'deserialized': 0x332211}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0}, {'serialized': 0x11, 'count': 0}),
      Vector({'enable': 1}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'enable': 0, 'deserialized': 0x998877},
          {'serialized': 0x22, 'count': 1}),
    ]);
  });

  test('catalog excludes legacy components and includes replacements', () {
    final names = componentRegistry.map((configurator) => configurator.name);
    expect(names, isNot(contains('Ready/Valid FIFO')));
    expect(names, isNot(contains('Content-Addressable Memory')));
    expect(names, contains('Ready/Valid Queue'));
    expect(names, contains('Parallel Associative Memory'));
  });

  test('explicit-J alignment configurators round-trip and generate', () async {
    final pairs = <(Configurator, Configurator)>[
      (
        FloatingPointClassifierConfigurator()
          ..explicitJBitKnob.value = true
          ..alignExplicitJBitKnob.value = true,
        FloatingPointClassifierConfigurator(),
      ),
      (
        FloatingPointComparatorConfigurator()
          ..explicitJBitKnob.value = true
          ..alignExplicitJBitKnob.value = true,
        FloatingPointComparatorConfigurator(),
      ),
      (
        FloatingPointConverterConfigurator()
          ..sourceExplicitJBitKnob.value = true
          ..alignExplicitJBitKnob.value = true,
        FloatingPointConverterConfigurator(),
      ),
    ];
    for (final (configured, restored) in pairs) {
      restored.loadJson(configured.toJson());
      expect(restored.toJson(), configured.toJson());
      expect(await restored.generateSV(), contains('canonical_leading_one'));
    }
  });

  test('legacy configurators remain usable outside the catalog', () async {
    final variants = <({
      Configurator config,
      Configurator restored,
      Type type,
    })>[
      (
        config: ReadyValidFifoConfigurator(),
        restored: ReadyValidFifoConfigurator(),
        type: ReadyValidFifo<Logic>,
      ),
      (
        config: CamConfigurator(),
        restored: CamConfigurator(),
        type: Cam<Logic>,
      ),
    ];
    for (final variant in variants) {
      variant.restored.loadJson(variant.config.toJson());
      expect(variant.restored.toJson(), variant.config.toJson());
      expect(variant.restored.createModule().runtimeType, variant.type);
      expect(await variant.config.generateSV(), contains('module '));
      await _Parent(variant.config.createModule()).build();
    }
  });

  test('all requested implementations generate and compose', () async {
    final variants = <({Configurator config, Type type})>[
      (config: AbsoluteValueConfigurator(), type: AbsoluteValue),
      (config: CircularPointerConfigurator(), type: CircularPointer),
      (config: CeilDivideConfigurator(), type: CeilDivide),
      for (final implementation in MuxImplementation.values)
        (
          config: MuxConfigurator()..implementationKnob.value = implementation,
          type: switch (implementation) {
            MuxImplementation.bitwise => BitwiseMux,
            MuxImplementation.oneHot => OneHotMux,
            MuxImplementation.priority => TypedPriorityMux<Logic>,
          },
        ),
      for (final operation in BitwisePopcountOperation.values)
        (
          config: BitwisePopcountConfigurator()
            ..operationKnob.value = operation,
          type: operation == BitwisePopcountOperation.xor
              ? XorPopcount
              : XnorPopcount,
        ),
      (config: PadConfigurator(), type: Pad),
      (config: SetBitsConfigurator(), type: SetBits),
      (config: WithSetConfigurator(), type: WithSet),
      for (final direction in RotateDirection.values)
        (
          config: RotateConfigurator()
            ..fixedKnob.value = true
            ..directionKnob.value = direction,
          type: direction == RotateDirection.left
              ? RotateLeftFixed
              : RotateRightFixed,
        ),
      (config: SynchronizerConfigurator(), type: Synchronizer),
      (config: ClockDividerConfigurator(), type: ClockDivider),
      (config: ParallelPrefixScanConfigurator(), type: ParallelPrefixScan),
      (config: SparseToDenseConfigurator(), type: SparseToDense),
      (config: BinaryToThermometerConfigurator(), type: BinaryToThermometer),
      (config: ThermometerToBinaryConfigurator(), type: ThermometerToBinary),
      (
        config: FloatingPointClassifierConfigurator(),
        type: FloatingPointClassifier
      ),
      (
        config: FloatingPointComparatorConfigurator(),
        type: FloatingPointComparator
      ),
      (config: ReadyValidQueueConfigurator(), type: ReadyValidQueue<Logic>),
      (
        config: ParallelAssociativeMemoryConfigurator(),
        type: ParallelAssociativeMemory,
      ),
      (
        config: CsrExampleConfigurator()
          ..boundaryKnob.value = CsrExampleBoundary.block,
        type: CsrBlock,
      ),
      (config: CsrExampleConfigurator(), type: CsrTop),
    ];
    for (final variant in variants) {
      expect(variant.config.createModule().runtimeType, variant.type,
          reason: variant.config.name);
      final restored = componentRegistry.singleWhere(
        (candidate) => candidate.runtimeType == variant.config.runtimeType,
      )..loadJson(variant.config.toJson());
      expect(restored.toJson(), variant.config.toJson(),
          reason: '${variant.config.name} did not round-trip');
      expect(restored.createModule().runtimeType, variant.type,
          reason: '${variant.config.name} changed implementation on load');
      expect(await variant.config.generateSV(), contains('module '),
          reason: variant.config.name);
      await _Parent(variant.config.createModule()).build();
    }
  });

  test('scan, scatter, and Gray topology configurations round-trip', () async {
    final scanConfig = ParallelPrefixScanConfigurator()
      ..widthKnob.value = 4
      ..operationKnob.value = PrefixScanOperation.xor
      ..directionKnob.value = PrefixScanDirection.highToLow
      ..treeKnob.value = BrentKung;
    final restoredScan = ParallelPrefixScanConfigurator()
      ..loadJson(scanConfig.toJson());
    expect(restoredScan.toJson(), scanConfig.toJson());
    final scan = restoredScan.createModule() as ParallelPrefixScan;
    await scan.build();
    scan.input('inp').put(5);
    expect(scan.out.value.toInt(), 6);

    final scatterConfig = SparseToDenseConfigurator()
      ..inputCountKnob.value = 2
      ..indexWidthKnob.value = 3
      ..outputWidthKnob.value = 5;
    final restoredScatter = SparseToDenseConfigurator()
      ..loadJson(scatterConfig.toJson());
    expect(restoredScatter.toJson(), scatterConfig.toJson());
    final scatter = restoredScatter.createModule() as SparseToDense;
    await scatter.build();
    scatter.input('index0').put(2);
    scatter.input('valid0').put(1);
    scatter.input('index1').put(4);
    scatter.input('valid1').put(1);
    expect(scatter.out.value.toInt(), 20);

    final grayConfig = GrayToBinaryConfigurator()
      ..widthKnob.value = 3
      ..topologyKnob.value = GrayToBinaryTopology.brentKung;
    final restoredGray = GrayToBinaryConfigurator()
      ..loadJson(grayConfig.toJson());
    expect(restoredGray.toJson(), grayConfig.toJson());
    final gray = restoredGray.createModule() as GrayToBinaryConverter;
    await gray.build();
    gray.input('gray').put(6);
    expect(gray.binary.value.toInt(), 4);

    final legacy =
        jsonDecode(GrayToBinaryConfigurator().toJson()) as Map<String, dynamic>;
    (legacy['knobs'] as Map<String, dynamic>).remove('Topology');
    final legacyGray = GrayToBinaryConfigurator()..loadJson(jsonEncode(legacy));
    expect(legacyGray.topologyKnob.value, GrayToBinaryTopology.linear);
  });

  test('fixed rotate settings round-trip without variable controls', () {
    final configured = RotateConfigurator()
      ..fixedKnob.value = true
      ..fixedAmountKnob.value = 0
      ..directionKnob.value = RotateDirection.left;
    expect(configured.knobs.keys, contains('Fixed Rotate Amount'));
    expect(configured.knobs.keys, isNot(contains('Rotate Amount Width')));
    final loaded = RotateConfigurator()..loadJson(configured.toJson());
    expect(loaded.fixedKnob.value, isTrue);
    expect(loaded.fixedAmountKnob.value, 0);
    expect(loaded.createModule(), isA<RotateLeftFixed>());
  });

  test('non-default geometry and behavior reach modules', () {
    final divider = (ClockDividerConfigurator()..divisorKnob.value = 5)
        .createModule() as ClockDivider;
    expect(divider.divisor, 5);

    final encoder = (BinaryToThermometerConfigurator()
          ..binaryWidthKnob.value = 3
          ..thermometerWidthKnob.value = 6)
        .createModule() as BinaryToThermometer;
    expect(encoder.input('binary').width, 3);
    expect(encoder.encoded.width, 6);

    final decoder = (ThermometerToBinaryConfigurator()
          ..thermometerWidthKnob.value = 6)
        .createModule() as ThermometerToBinary;
    expect(decoder.input('thermometer').width, 6);
    expect(decoder.binary.width, 3);

    final comparator = (FloatingPointComparatorConfigurator()
          ..exponentWidthKnob.value = 3
          ..mantissaWidthKnob.value = 2
          ..subNormalAsZeroKnob.value = true)
        .createModule() as FloatingPointComparator;
    expect(comparator.input('a').width, 6);
    expect(comparator.input('b').width, 6);

    final pointer = (CircularPointerConfigurator()
          ..slotsKnob.value = 13
          ..incrementWidthKnob.value = 4)
        .createModule() as CircularPointer;
    expect(pointer.slots, 13);
    expect(pointer.input('increment').width, 4);

    final synchronizer = (SynchronizerConfigurator()
          ..widthKnob.value = 3
          ..stagesKnob.value = 3
          ..resetKnob.value = true)
        .createModule() as Synchronizer;
    expect(synchronizer.numStages, 3);
    expect(synchronizer.syncData.width, 3);

    final fifo = (ReadyValidFifoConfigurator()
          ..widthKnob.value = 5
          ..depthKnob.value = 2
          ..replacementKnob.value = true)
        .createModule() as ReadyValidFifo<Logic>;
    expect(fifo.depth, 2);
    expect(fifo.upstream.data.width, 5);
    expect(fifo.allowSameCycleReplacement, isTrue);

    final queue = (ReadyValidQueueConfigurator()
          ..dataWidthKnob.value = 5
          ..depthKnob.value = 2
          ..fallThroughKnob.value = true
          ..storageKnob.value = ReadyValidQueueStorage.ring)
        .createModule() as ReadyValidQueue<Logic>;
    expect(queue.depth, 2);
    expect(queue.upstream.data.width, 5);
    expect(queue.policy, ReadyValidQueuePolicy.fallThrough);
    expect(queue.storage, ReadyValidQueueStorage.ring);

    final csr = (CsrExampleConfigurator()
          ..widthKnob.value = 12
          ..asyncResetKnob.value = true)
        .createModule() as CsrTop;
    expect(csr.config.asyncReset, isTrue);
    expect(
        csr.config.blocks.single.registers.map((reg) => reg.width), [12, 12]);
    expect(csr.config.blocks.single.registers.map((reg) => reg.addr),
        [BigInt.zero, BigInt.one]);
  });
}
