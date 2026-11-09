// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// module_source_assets.dart
// Maps configurable modules to bundled ROHD source assets.
//
// 2026 August 29
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

// Retain the source mapping for the legacy FIFO.
// ignore_for_file: deprecated_member_use

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Maps configurable module runtime types to bundled ROHD source assets.
const moduleSourceAssets = <String, String>{
  'AbsoluteValue': 'rohd_src/arithmetic/normalization/absolute_value.dart',
  'ApbCsrCompleter':
      'rohd_src/interfaces/amba/endpoints/apb_csr_completer.dart',
  'AsyncFifo': 'rohd_src/flow_control/storage/async_fifo.dart',
  'BinaryToOneHot': 'rohd_src/encodings/one_hot/binary_to_one_hot.dart',
  'BinaryToGrayConverter': 'rohd_src/encodings/gray/binary_gray.dart',
  'BinaryToThermometer': 'rohd_src/encodings/thermometer/thermometer_code.dart',
  'BitonicSort': 'rohd_src/dataflow/ordering/sort.dart',
  'BitwiseMux': 'rohd_src/bit_operations/selection/bitwise_mux.dart',
  'Cache': 'rohd_src/memory/cache/cache.dart',
  'CacheTransactionAdapter':
      'rohd_src/memory/cache/cache_transaction_adapter.dart',
  'Cam': 'rohd_src/memory/associative/cam.dart',
  'CarrySaveMultiplier':
      'rohd_src/arithmetic/multiplication/carry_save_multiplier.dart',
  'CarrySelectCompoundAdder':
      'rohd_src/arithmetic/addition/compound_adder.dart',
  'CarrySelectOnesComplementCompoundAdder':
      'rohd_src/arithmetic/addition/compound_adder.dart',
  'CaseOneHotToBinary':
      'rohd_src/encodings/one_hot/case_one_hot_to_binary.dart',
  'CeilDivide': 'rohd_src/arithmetic/division_and_roots/ceil_divide.dart',
  'CircularPointer': 'rohd_src/arithmetic/accumulation/circular_pointer.dart',
  'ClockGate': 'rohd_src/clocking/gating/clock_gating.dart',
  'ClockDivider': 'rohd_src/clocking/generation/clock_divider.dart',
  'CompressionTreeDotProduct':
      'rohd_src/arithmetic/multiply_accumulate/dotproduct.dart',
  'CompressionTreeMultiplyAccumulate':
      'rohd_src/arithmetic/multiply_accumulate/multiply_accumulate.dart',
  'CompressionTreeMultiplier':
      'rohd_src/arithmetic/multiplication/multiplier.dart',
  'Counter': 'rohd_src/arithmetic/accumulation/counter.dart',
  'Count': 'rohd_src/bit_operations/population_count/count.dart',
  'CsrBlock': 'rohd_src/memory/csr/csr_block.dart',
  'CsrTop': 'rohd_src/memory/csr/csr_top.dart',
  'Deserializer': 'rohd_src/dataflow/serialization/serialization.dart',
  'EdgeDetector': 'rohd_src/clocking/event_detection/edge_detector.dart',
  'Extrema': 'rohd_src/dataflow/selection/extrema.dart',
  'Fifo': 'rohd_src/flow_control/storage/fifo.dart',
  'Find': 'rohd_src/bit_operations/search/find.dart',
  'FindPattern': 'rohd_src/bit_operations/search/find_pattern.dart',
  'Float8ToFixed': 'rohd_src/arithmetic/conversion/float_to_fixed.dart',
  'FixedPointSqrt': 'rohd_src/arithmetic/division_and_roots/fixed_sqrt.dart',
  'FixedPriorityCacheScheduler':
      'rohd_src/memory/cache/fixed_priority_cache_scheduler.dart',
  'FixedToFloat': 'rohd_src/arithmetic/conversion/fixed_to_float.dart',
  'FloatToFixed': 'rohd_src/arithmetic/conversion/float_to_fixed.dart',
  'FloatingPointAdderDualPath':
      'rohd_src/arithmetic/floating_point/floating_point_adder_dualpath.dart',
  'FloatingPointAdderSinglePath':
      'rohd_src/arithmetic/floating_point/floating_point_adder_singlepath.dart',
  'FloatingPointMultiplierSimple':
      'rohd_src/arithmetic/floating_point/floating_point_multiplier_simple.dart',
  'FloatingPointSqrtSimple':
      'rohd_src/arithmetic/floating_point/floating_point_sqrt_simple.dart',
  'FloatingPointConverter':
      'rohd_src/arithmetic/floating_point/floating_point_converter.dart',
  'FloatingPointClassifier':
      'rohd_src/arithmetic/floating_point/floating_point_classification.dart',
  'FloatingPointComparator':
      'rohd_src/arithmetic/floating_point/floating_point_classification.dart',
  'GatedCounter': 'rohd_src/arithmetic/accumulation/gated_counter.dart',
  'GeneralDotProduct':
      'rohd_src/arithmetic/multiply_accumulate/dotproduct.dart',
  'GrayToBinaryConverter': 'rohd_src/encodings/gray/binary_gray.dart',
  'HammingEccReceiver': 'rohd_src/error_control/protection/ecc.dart',
  'InferredSram': 'rohd_src/memory/storage/inferred_sram.dart',
  'LeadingDigitAnticipate':
      'rohd_src/arithmetic/normalization/leading_digit_anticipate.dart',
  'LeadingZeroAnticipate':
      'rohd_src/arithmetic/normalization/leading_digit_anticipate.dart',
  'LeadingZeroAnticipateCarry':
      'rohd_src/arithmetic/normalization/leading_digit_anticipate.dart',
  'MaskRoundRobinArbiter':
      'rohd_src/flow_control/arbitration/mask_round_robin_arbiter.dart',
  'MultiCycleDivider': 'rohd_src/arithmetic/division_and_roots/divider.dart',
  'MultiPortCache': 'rohd_src/memory/cache/cache.dart',
  'NativeMultiplier': 'rohd_src/arithmetic/multiplication/multiplier.dart',
  'OneHotMux': 'rohd_src/bit_operations/selection/one_hot_mux.dart',
  'OnesComplementAdder':
      'rohd_src/arithmetic/addition/ones_complement_adder.dart',
  'ParallelPrefixAdder':
      'rohd_src/arithmetic/prefix_networks/parallel_prefix_operations.dart',
  'ParallelPrefixDecr':
      'rohd_src/arithmetic/prefix_networks/parallel_prefix_operations.dart',
  'ParallelPrefixIncr':
      'rohd_src/arithmetic/prefix_networks/parallel_prefix_operations.dart',
  'ParallelAssociativeMemory':
      'rohd_src/memory/associative/parallel_associative_memory.dart',
  'ParallelPrefixOrScan':
      'rohd_src/arithmetic/prefix_networks/parallel_prefix_operations.dart',
  'ParallelPrefixPriorityEncoder':
      'rohd_src/encodings/priority/priority_encoder.dart',
  'ParallelPrefixPriorityFinder':
      'rohd_src/arithmetic/prefix_networks/parallel_prefix_operations.dart',
  'ParityReceiver': 'rohd_src/error_control/protection/parity.dart',
  'ParityTransmitter': 'rohd_src/error_control/protection/parity.dart',
  'Pad': 'rohd_src/bit_operations/shifting/pad.dart',
  'PriorityArbiter': 'rohd_src/flow_control/arbitration/priority_arbiter.dart',
  'PriorityMux': 'rohd_src/bit_operations/selection/priority_mux.dart',
  'ReadyValidFifo':
      'rohd_src/flow_control/ready_valid/queues/ready_valid_fifo.dart',
  'ReadyValidQueue':
      'rohd_src/flow_control/ready_valid/queues/ready_valid_queue.dart',
  'RecursiveModulePriorityEncoder':
      'rohd_src/encodings/priority/priority_encoder.dart',
  'RecursivePriorityEncoder':
      'rohd_src/encodings/priority/priority_encoder.dart',
  'RegisterFile': 'rohd_src/memory/storage/register_file.dart',
  'ReductionTree': 'rohd_src/dataflow/reduction/reduction_tree.dart',
  'RippleCarryAdder': 'rohd_src/arithmetic/addition/ripple_carry_adder.dart',
  'RotateLeft': 'rohd_src/bit_operations/shifting/rotate.dart',
  'RotateLeftFixed': 'rohd_src/bit_operations/shifting/rotate.dart',
  'RotateRight': 'rohd_src/bit_operations/shifting/rotate.dart',
  'RotateRightFixed': 'rohd_src/bit_operations/shifting/rotate.dart',
  'RotateRoundRobinArbiter':
      'rohd_src/flow_control/arbitration/rotate_round_robin_arbiter.dart',
  'RoundRobinReplacement':
      'rohd_src/memory/replacement/round_robin_replacement.dart',
  'SerializedCache': 'rohd_src/memory/cache/serialized_cache.dart',
  'Serializer': 'rohd_src/dataflow/serialization/serialization.dart',
  'SetBits': 'rohd_src/bit_operations/shifting/set_bits.dart',
  'ShiftRegister': 'rohd_src/memory/sequential/shift_register.dart',
  'SignMagnitudeAdder':
      'rohd_src/arithmetic/addition/sign_magnitude_adder.dart',
  'SignMagnitudeDualAdder':
      'rohd_src/arithmetic/addition/sign_magnitude_adder.dart',
  'SignedShifter': 'rohd_src/bit_operations/shifting/signed_shifter.dart',
  'SpiMain': 'rohd_src/interfaces/spi/endpoints/spi_main.dart',
  'SpiSub': 'rohd_src/interfaces/spi/endpoints/spi_sub.dart',
  'Sum': 'rohd_src/arithmetic/accumulation/sum.dart',
  'Synchronizer': 'rohd_src/clocking/cdc/synchronizer.dart',
  'ThermometerToBinary': 'rohd_src/encodings/thermometer/thermometer_code.dart',
  'ToggleGate': 'rohd_src/clocking/gating/toggle_gate.dart',
  'TreeOneHotToBinary':
      'rohd_src/encodings/one_hot/tree_one_hot_to_binary.dart',
  'TreePseudoLruReplacement':
      'rohd_src/memory/replacement/tree_pseudo_lru_replacement.dart',
  'WithSet': 'rohd_src/bit_operations/shifting/with_set.dart',
  'XnorPopcount': 'rohd_src/bit_operations/population_count/xnor_popcount.dart',
  'XorPopcount': 'rohd_src/bit_operations/population_count/xor_popcount.dart',
};

/// Returns the bundled ROHD source asset for [module], if one is indexed.
String? moduleSourceAsset(Module module) => switch (module) {
      AbsoluteValue() => moduleSourceAssets['AbsoluteValue'],
      ApbCsrCompleter() => moduleSourceAssets['ApbCsrCompleter'],
      AsyncFifo() => moduleSourceAssets['AsyncFifo'],
      BinaryToOneHot() => moduleSourceAssets['BinaryToOneHot'],
      BinaryToGrayConverter() => moduleSourceAssets['BinaryToGrayConverter'],
      BinaryToThermometer() => moduleSourceAssets['BinaryToThermometer'],
      BitonicSort() => moduleSourceAssets['BitonicSort'],
      BitwiseMux() => moduleSourceAssets['BitwiseMux'],
      // Experimental cache components are intentionally exposed in Confapp.
      // ignore: experimental_member_use
      Cache() => moduleSourceAssets['Cache'],
      // The catalog intentionally exposes this experimental adapter.
      // ignore: experimental_member_use
      CacheTransactionAdapter() =>
        moduleSourceAssets['CacheTransactionAdapter'],
      Cam() => moduleSourceAssets['Cam'],
      CarrySaveMultiplier() => moduleSourceAssets['CarrySaveMultiplier'],
      CarrySelectCompoundAdder() =>
        moduleSourceAssets['CarrySelectCompoundAdder'],
      CarrySelectOnesComplementCompoundAdder() =>
        moduleSourceAssets['CarrySelectOnesComplementCompoundAdder'],
      CaseOneHotToBinary() => moduleSourceAssets['CaseOneHotToBinary'],
      CeilDivide() => moduleSourceAssets['CeilDivide'],
      CircularPointer() => moduleSourceAssets['CircularPointer'],
      ClockGate() => moduleSourceAssets['ClockGate'],
      ClockDivider() => moduleSourceAssets['ClockDivider'],
      CompressionTreeDotProduct() =>
        moduleSourceAssets['CompressionTreeDotProduct'],
      CompressionTreeMultiplyAccumulate() =>
        moduleSourceAssets['CompressionTreeMultiplyAccumulate'],
      CompressionTreeMultiplier() =>
        moduleSourceAssets['CompressionTreeMultiplier'],
      GatedCounter() => moduleSourceAssets['GatedCounter'],
      Counter() => moduleSourceAssets['Counter'],
      Count() => moduleSourceAssets['Count'],
      CsrBlock() => moduleSourceAssets['CsrBlock'],
      CsrTop() => moduleSourceAssets['CsrTop'],
      Deserializer() => moduleSourceAssets['Deserializer'],
      EdgeDetector() => moduleSourceAssets['EdgeDetector'],
      Extrema() => moduleSourceAssets['Extrema'],
      Fifo() => moduleSourceAssets['Fifo'],
      Find() => moduleSourceAssets['Find'],
      FindPattern() => moduleSourceAssets['FindPattern'],
      Float8ToFixed() => moduleSourceAssets['Float8ToFixed'],
      FixedPointSqrt() => moduleSourceAssets['FixedPointSqrt'],
      // The catalog intentionally exposes this experimental scheduler.
      // ignore: experimental_member_use
      FixedPriorityCacheScheduler() =>
        moduleSourceAssets['FixedPriorityCacheScheduler'],
      FixedToFloat() => moduleSourceAssets['FixedToFloat'],
      FloatToFixed() => moduleSourceAssets['FloatToFixed'],
      FloatingPointAdderDualPath() =>
        moduleSourceAssets['FloatingPointAdderDualPath'],
      FloatingPointAdderSinglePath() =>
        moduleSourceAssets['FloatingPointAdderSinglePath'],
      FloatingPointMultiplierSimple() =>
        moduleSourceAssets['FloatingPointMultiplierSimple'],
      FloatingPointSqrtSimple() =>
        moduleSourceAssets['FloatingPointSqrtSimple'],
      FloatingPointConverter() => moduleSourceAssets['FloatingPointConverter'],
      FloatingPointClassifier() =>
        moduleSourceAssets['FloatingPointClassifier'],
      FloatingPointComparator() =>
        moduleSourceAssets['FloatingPointComparator'],
      GeneralDotProduct() => moduleSourceAssets['GeneralDotProduct'],
      GrayToBinaryConverter() => moduleSourceAssets['GrayToBinaryConverter'],
      HammingEccReceiver() => moduleSourceAssets['HammingEccReceiver'],
      InferredSram() => moduleSourceAssets['InferredSram'],
      LeadingDigitAnticipate() => moduleSourceAssets['LeadingDigitAnticipate'],
      LeadingZeroAnticipate() => moduleSourceAssets['LeadingZeroAnticipate'],
      LeadingZeroAnticipateCarry() =>
        moduleSourceAssets['LeadingZeroAnticipateCarry'],
      MaskRoundRobinArbiter() => moduleSourceAssets['MaskRoundRobinArbiter'],
      MultiCycleDivider() => moduleSourceAssets['MultiCycleDivider'],
      // The catalog intentionally exposes this experimental controller.
      // ignore: experimental_member_use
      MultiPortCache() => moduleSourceAssets['MultiPortCache'],
      NativeMultiplier() => moduleSourceAssets['NativeMultiplier'],
      OneHotMux() => moduleSourceAssets['OneHotMux'],
      OnesComplementAdder() => moduleSourceAssets['OnesComplementAdder'],
      ParallelPrefixAdder() => moduleSourceAssets['ParallelPrefixAdder'],
      ParallelPrefixDecr() => moduleSourceAssets['ParallelPrefixDecr'],
      ParallelPrefixIncr() => moduleSourceAssets['ParallelPrefixIncr'],
      ParallelPrefixOrScan() => moduleSourceAssets['ParallelPrefixOrScan'],
      ParallelPrefixPriorityEncoder() =>
        moduleSourceAssets['ParallelPrefixPriorityEncoder'],
      ParallelPrefixPriorityFinder() =>
        moduleSourceAssets['ParallelPrefixPriorityFinder'],
      ParityReceiver() => moduleSourceAssets['ParityReceiver'],
      ParityTransmitter() => moduleSourceAssets['ParityTransmitter'],
      Pad() => moduleSourceAssets['Pad'],
      PriorityArbiter() => moduleSourceAssets['PriorityArbiter'],
      PriorityMux() => moduleSourceAssets['PriorityMux'],
      ReadyValidFifo() => moduleSourceAssets['ReadyValidFifo'],
      ReadyValidQueue() => moduleSourceAssets['ReadyValidQueue'],
      ParallelAssociativeMemory() =>
        moduleSourceAssets['ParallelAssociativeMemory'],
      RecursiveModulePriorityEncoder() =>
        moduleSourceAssets['RecursiveModulePriorityEncoder'],
      RecursivePriorityEncoder() =>
        moduleSourceAssets['RecursivePriorityEncoder'],
      RegisterFile() => moduleSourceAssets['RegisterFile'],
      ReductionTree() => moduleSourceAssets['ReductionTree'],
      RippleCarryAdder() => moduleSourceAssets['RippleCarryAdder'],
      RotateLeft() => moduleSourceAssets['RotateLeft'],
      RotateLeftFixed() => moduleSourceAssets['RotateLeftFixed'],
      RotateRight() => moduleSourceAssets['RotateRight'],
      RotateRightFixed() => moduleSourceAssets['RotateRightFixed'],
      RotateRoundRobinArbiter() =>
        moduleSourceAssets['RotateRoundRobinArbiter'],
      RoundRobinReplacement() => moduleSourceAssets['RoundRobinReplacement'],
      // The catalog intentionally exposes this experimental controller.
      // ignore: experimental_member_use
      SerializedCache() => moduleSourceAssets['SerializedCache'],
      Serializer() => moduleSourceAssets['Serializer'],
      SetBits() => moduleSourceAssets['SetBits'],
      Synchronizer() => moduleSourceAssets['Synchronizer'],
      ThermometerToBinary() => moduleSourceAssets['ThermometerToBinary'],
      ShiftRegister() => moduleSourceAssets['ShiftRegister'],
      SignMagnitudeAdder() => moduleSourceAssets['SignMagnitudeAdder'],
      SignMagnitudeDualAdder() => moduleSourceAssets['SignMagnitudeDualAdder'],
      SignedShifter() => moduleSourceAssets['SignedShifter'],
      SpiMain() => moduleSourceAssets['SpiMain'],
      SpiSub() => moduleSourceAssets['SpiSub'],
      Sum() => moduleSourceAssets['Sum'],
      ToggleGate() => moduleSourceAssets['ToggleGate'],
      TreeOneHotToBinary() => moduleSourceAssets['TreeOneHotToBinary'],
      TreePseudoLruReplacement() =>
        moduleSourceAssets['TreePseudoLruReplacement'],
      WithSet() => moduleSourceAssets['WithSet'],
      XnorPopcount() => moduleSourceAssets['XnorPopcount'],
      XorPopcount() => moduleSourceAssets['XorPopcount'],
      _ when InferredSramConfigurator.isConfiguredModule(module) =>
        moduleSourceAssets['InferredSram'],
      _ => null,
    };

/// Converts a logical ROHD source path to its Flutter asset-bundle key.
String bundledSourceAssetPath(String sourceAsset) => 'assets/$sourceAsset';
