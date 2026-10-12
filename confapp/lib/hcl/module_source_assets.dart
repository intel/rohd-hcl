// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// module_source_assets.dart
// Maps configurable modules to bundled ROHD source assets.
//
// 2026 August 29
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Maps configurable module runtime types to bundled ROHD source assets.
const moduleSourceAssets = <String, String>{
  'ApbCsrCompleter':
      'rohd_src/interfaces/amba/endpoints/apb_csr_completer.dart',
  'AsyncFifo': 'rohd_src/flow_control/storage/async_fifo.dart',
  'BinaryToOneHot': 'rohd_src/encodings/one_hot/binary_to_one_hot.dart',
  'BinaryToGrayConverter': 'rohd_src/encodings/gray/binary_gray.dart',
  'BitonicSort': 'rohd_src/dataflow/ordering/sort.dart',
  'Cam': 'rohd_src/memory/associative/cam.dart',
  'CarrySaveMultiplier':
      'rohd_src/arithmetic/multiplication/carry_save_multiplier.dart',
  'CarrySelectCompoundAdder':
      'rohd_src/arithmetic/addition/compound_adder.dart',
  'CarrySelectOnesComplementCompoundAdder':
      'rohd_src/arithmetic/addition/compound_adder.dart',
  'CaseOneHotToBinary':
      'rohd_src/encodings/one_hot/case_one_hot_to_binary.dart',
  'ClockGate': 'rohd_src/clocking/gating/clock_gating.dart',
  'CompressionTreeDotProduct':
      'rohd_src/arithmetic/multiply_accumulate/dotproduct.dart',
  'CompressionTreeMultiplyAccumulate':
      'rohd_src/arithmetic/multiply_accumulate/multiply_accumulate.dart',
  'CompressionTreeMultiplier':
      'rohd_src/arithmetic/multiplication/multiplier.dart',
  'Counter': 'rohd_src/arithmetic/accumulation/counter.dart',
  'Count': 'rohd_src/bit_operations/population_count/count.dart',
  'Deserializer': 'rohd_src/dataflow/serialization/serialization.dart',
  'EdgeDetector': 'rohd_src/clocking/event_detection/edge_detector.dart',
  'Extrema': 'rohd_src/dataflow/selection/extrema.dart',
  'Fifo': 'rohd_src/flow_control/storage/fifo.dart',
  'Find': 'rohd_src/bit_operations/search/find.dart',
  'FindPattern': 'rohd_src/bit_operations/search/find_pattern.dart',
  'Float8ToFixed': 'rohd_src/arithmetic/conversion/float_to_fixed.dart',
  'FixedPointSqrt': 'rohd_src/arithmetic/division_and_roots/fixed_sqrt.dart',
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
  'GatedCounter': 'rohd_src/arithmetic/accumulation/gated_counter.dart',
  'GeneralDotProduct':
      'rohd_src/arithmetic/multiply_accumulate/dotproduct.dart',
  'GrayToBinaryConverter': 'rohd_src/encodings/gray/binary_gray.dart',
  'HammingEccReceiver': 'rohd_src/error_control/protection/ecc.dart',
  'LeadingDigitAnticipate':
      'rohd_src/arithmetic/normalization/leading_digit_anticipate.dart',
  'LeadingZeroAnticipate':
      'rohd_src/arithmetic/normalization/leading_digit_anticipate.dart',
  'LeadingZeroAnticipateCarry':
      'rohd_src/arithmetic/normalization/leading_digit_anticipate.dart',
  'MaskRoundRobinArbiter':
      'rohd_src/flow_control/arbitration/mask_round_robin_arbiter.dart',
  'MultiCycleDivider': 'rohd_src/arithmetic/division_and_roots/divider.dart',
  'NativeMultiplier': 'rohd_src/arithmetic/multiplication/multiplier.dart',
  'OnesComplementAdder':
      'rohd_src/arithmetic/addition/ones_complement_adder.dart',
  'ParallelPrefixAdder':
      'rohd_src/arithmetic/prefix_networks/parallel_prefix_operations.dart',
  'ParallelPrefixDecr':
      'rohd_src/arithmetic/prefix_networks/parallel_prefix_operations.dart',
  'ParallelPrefixIncr':
      'rohd_src/arithmetic/prefix_networks/parallel_prefix_operations.dart',
  'ParallelPrefixOrScan':
      'rohd_src/arithmetic/prefix_networks/parallel_prefix_operations.dart',
  'ParallelPrefixPriorityEncoder':
      'rohd_src/encodings/priority/priority_encoder.dart',
  'ParallelPrefixPriorityFinder':
      'rohd_src/arithmetic/prefix_networks/parallel_prefix_operations.dart',
  'ParityReceiver': 'rohd_src/error_control/protection/parity.dart',
  'ParityTransmitter': 'rohd_src/error_control/protection/parity.dart',
  'PriorityArbiter': 'rohd_src/flow_control/arbitration/priority_arbiter.dart',
  'RecursiveModulePriorityEncoder':
      'rohd_src/encodings/priority/priority_encoder.dart',
  'RecursivePriorityEncoder':
      'rohd_src/encodings/priority/priority_encoder.dart',
  'RegisterFile': 'rohd_src/memory/storage/register_file.dart',
  'ReductionTree': 'rohd_src/dataflow/reduction/reduction_tree.dart',
  'RippleCarryAdder': 'rohd_src/arithmetic/addition/ripple_carry_adder.dart',
  'RotateLeft': 'rohd_src/bit_operations/shifting/rotate.dart',
  'RotateRight': 'rohd_src/bit_operations/shifting/rotate.dart',
  'RotateRoundRobinArbiter':
      'rohd_src/flow_control/arbitration/rotate_round_robin_arbiter.dart',
  'Serializer': 'rohd_src/dataflow/serialization/serialization.dart',
  'ShiftRegister': 'rohd_src/memory/sequential/shift_register.dart',
  'SignMagnitudeAdder':
      'rohd_src/arithmetic/addition/sign_magnitude_adder.dart',
  'SignMagnitudeDualAdder':
      'rohd_src/arithmetic/addition/sign_magnitude_adder.dart',
  'SignedShifter': 'rohd_src/bit_operations/shifting/signed_shifter.dart',
  'SpiMain': 'rohd_src/interfaces/spi/endpoints/spi_main.dart',
  'SpiSub': 'rohd_src/interfaces/spi/endpoints/spi_sub.dart',
  'Sum': 'rohd_src/arithmetic/accumulation/sum.dart',
  'ToggleGate': 'rohd_src/clocking/gating/toggle_gate.dart',
  'TreeOneHotToBinary':
      'rohd_src/encodings/one_hot/tree_one_hot_to_binary.dart',
};

/// Returns the bundled ROHD source asset for [module], if one is indexed.
String? moduleSourceAsset(Module module) => switch (module) {
      ApbCsrCompleter() => moduleSourceAssets['ApbCsrCompleter'],
      AsyncFifo() => moduleSourceAssets['AsyncFifo'],
      BinaryToOneHot() => moduleSourceAssets['BinaryToOneHot'],
      BinaryToGrayConverter() => moduleSourceAssets['BinaryToGrayConverter'],
      BitonicSort() => moduleSourceAssets['BitonicSort'],
      Cam() => moduleSourceAssets['Cam'],
      CarrySaveMultiplier() => moduleSourceAssets['CarrySaveMultiplier'],
      CarrySelectCompoundAdder() =>
        moduleSourceAssets['CarrySelectCompoundAdder'],
      CarrySelectOnesComplementCompoundAdder() =>
        moduleSourceAssets['CarrySelectOnesComplementCompoundAdder'],
      CaseOneHotToBinary() => moduleSourceAssets['CaseOneHotToBinary'],
      ClockGate() => moduleSourceAssets['ClockGate'],
      CompressionTreeDotProduct() =>
        moduleSourceAssets['CompressionTreeDotProduct'],
      CompressionTreeMultiplyAccumulate() =>
        moduleSourceAssets['CompressionTreeMultiplyAccumulate'],
      CompressionTreeMultiplier() =>
        moduleSourceAssets['CompressionTreeMultiplier'],
      GatedCounter() => moduleSourceAssets['GatedCounter'],
      Counter() => moduleSourceAssets['Counter'],
      Count() => moduleSourceAssets['Count'],
      Deserializer() => moduleSourceAssets['Deserializer'],
      EdgeDetector() => moduleSourceAssets['EdgeDetector'],
      Extrema() => moduleSourceAssets['Extrema'],
      Fifo() => moduleSourceAssets['Fifo'],
      Find() => moduleSourceAssets['Find'],
      FindPattern() => moduleSourceAssets['FindPattern'],
      Float8ToFixed() => moduleSourceAssets['Float8ToFixed'],
      FixedPointSqrt() => moduleSourceAssets['FixedPointSqrt'],
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
      GeneralDotProduct() => moduleSourceAssets['GeneralDotProduct'],
      GrayToBinaryConverter() => moduleSourceAssets['GrayToBinaryConverter'],
      HammingEccReceiver() => moduleSourceAssets['HammingEccReceiver'],
      LeadingDigitAnticipate() => moduleSourceAssets['LeadingDigitAnticipate'],
      LeadingZeroAnticipate() => moduleSourceAssets['LeadingZeroAnticipate'],
      LeadingZeroAnticipateCarry() =>
        moduleSourceAssets['LeadingZeroAnticipateCarry'],
      MaskRoundRobinArbiter() => moduleSourceAssets['MaskRoundRobinArbiter'],
      MultiCycleDivider() => moduleSourceAssets['MultiCycleDivider'],
      NativeMultiplier() => moduleSourceAssets['NativeMultiplier'],
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
      PriorityArbiter() => moduleSourceAssets['PriorityArbiter'],
      RecursiveModulePriorityEncoder() =>
        moduleSourceAssets['RecursiveModulePriorityEncoder'],
      RecursivePriorityEncoder() =>
        moduleSourceAssets['RecursivePriorityEncoder'],
      RegisterFile() => moduleSourceAssets['RegisterFile'],
      ReductionTree() => moduleSourceAssets['ReductionTree'],
      RippleCarryAdder() => moduleSourceAssets['RippleCarryAdder'],
      RotateLeft() => moduleSourceAssets['RotateLeft'],
      RotateRight() => moduleSourceAssets['RotateRight'],
      RotateRoundRobinArbiter() =>
        moduleSourceAssets['RotateRoundRobinArbiter'],
      Serializer() => moduleSourceAssets['Serializer'],
      ShiftRegister() => moduleSourceAssets['ShiftRegister'],
      SignMagnitudeAdder() => moduleSourceAssets['SignMagnitudeAdder'],
      SignMagnitudeDualAdder() => moduleSourceAssets['SignMagnitudeDualAdder'],
      SignedShifter() => moduleSourceAssets['SignedShifter'],
      SpiMain() => moduleSourceAssets['SpiMain'],
      SpiSub() => moduleSourceAssets['SpiSub'],
      Sum() => moduleSourceAssets['Sum'],
      ToggleGate() => moduleSourceAssets['ToggleGate'],
      TreeOneHotToBinary() => moduleSourceAssets['TreeOneHotToBinary'],
      _ => null,
    };

/// Converts a logical ROHD source path to its Flutter asset-bundle key.
String bundledSourceAssetPath(String sourceAsset) => 'assets/$sourceAsset';
