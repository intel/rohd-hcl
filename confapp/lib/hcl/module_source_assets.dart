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
  'ApbCsrCompleter': 'rohd_src/gaskets/amba5/apb_csr_completer.dart',
  'AsyncFifo': 'rohd_src/async_fifo.dart',
  'BinaryToOneHot': 'rohd_src/encodings/binary_to_one_hot.dart',
  'BinaryToGrayConverter': 'rohd_src/binary_gray.dart',
  'BitonicSort': 'rohd_src/sort.dart',
  'Cam': 'rohd_src/memory/cam.dart',
  'CarrySaveMultiplier': 'rohd_src/arithmetic/carry_save_mutiplier.dart',
  'CarrySelectCompoundAdder': 'rohd_src/arithmetic/compound_adder.dart',
  'CarrySelectOnesComplementCompoundAdder':
      'rohd_src/arithmetic/compound_adder.dart',
  'CaseOneHotToBinary': 'rohd_src/encodings/case_one_hot_to_binary.dart',
  'ClockGate': 'rohd_src/clock_gating.dart',
  'CompressionTreeDotProduct': 'rohd_src/arithmetic/dotproduct.dart',
  'CompressionTreeMultiplyAccumulate':
      'rohd_src/arithmetic/multiply_accumulate.dart',
  'CompressionTreeMultiplier': 'rohd_src/arithmetic/multiplier.dart',
  'Counter': 'rohd_src/summation/counter.dart',
  'Count': 'rohd_src/count.dart',
  'Deserializer': 'rohd_src/serialization/serialization.dart',
  'EdgeDetector': 'rohd_src/edge_detector.dart',
  'Extrema': 'rohd_src/extrema.dart',
  'Fifo': 'rohd_src/memory/fifo.dart',
  'Find': 'rohd_src/find.dart',
  'FindPattern': 'rohd_src/find_pattern.dart',
  'Float8ToFixed': 'rohd_src/arithmetic/float_to_fixed.dart',
  'FixedPointSqrt': 'rohd_src/arithmetic/fixed_sqrt.dart',
  'FixedToFloat': 'rohd_src/arithmetic/fixed_to_float.dart',
  'FloatToFixed': 'rohd_src/arithmetic/float_to_fixed.dart',
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
  'GatedCounter': 'rohd_src/summation/gated_counter.dart',
  'GeneralDotProduct': 'rohd_src/arithmetic/dotproduct.dart',
  'GrayToBinaryConverter': 'rohd_src/binary_gray.dart',
  'HammingEccReceiver': 'rohd_src/error_checking/ecc.dart',
  'LeadingDigitAnticipate': 'rohd_src/arithmetic/leading_digit_anticipate.dart',
  'LeadingZeroAnticipate': 'rohd_src/arithmetic/leading_digit_anticipate.dart',
  'LeadingZeroAnticipateCarry':
      'rohd_src/arithmetic/leading_digit_anticipate.dart',
  'MaskRoundRobinArbiter': 'rohd_src/arbiters/mask_round_robin_arbiter.dart',
  'MultiCycleDivider': 'rohd_src/arithmetic/divider.dart',
  'NativeMultiplier': 'rohd_src/arithmetic/multiplier.dart',
  'OnesComplementAdder': 'rohd_src/arithmetic/ones_complement_adder.dart',
  'ParallelPrefixAdder': 'rohd_src/arithmetic/parallel_prefix_operations.dart',
  'ParallelPrefixDecr': 'rohd_src/arithmetic/parallel_prefix_operations.dart',
  'ParallelPrefixIncr': 'rohd_src/arithmetic/parallel_prefix_operations.dart',
  'ParallelPrefixOrScan': 'rohd_src/arithmetic/parallel_prefix_operations.dart',
  'ParallelPrefixPriorityEncoder': 'rohd_src/priority_encoder.dart',
  'ParallelPrefixPriorityFinder':
      'rohd_src/arithmetic/parallel_prefix_operations.dart',
  'ParityReceiver': 'rohd_src/error_checking/parity.dart',
  'ParityTransmitter': 'rohd_src/error_checking/parity.dart',
  'PriorityArbiter': 'rohd_src/arbiters/priority_arbiter.dart',
  'RecursiveModulePriorityEncoder': 'rohd_src/priority_encoder.dart',
  'RecursivePriorityEncoder': 'rohd_src/priority_encoder.dart',
  'RegisterFile': 'rohd_src/memory/register_file.dart',
  'ReductionTree': 'rohd_src/reduction_tree.dart',
  'RippleCarryAdder': 'rohd_src/arithmetic/ripple_carry_adder.dart',
  'RotateLeft': 'rohd_src/rotate.dart',
  'RotateRight': 'rohd_src/rotate.dart',
  'RotateRoundRobinArbiter':
      'rohd_src/arbiters/rotate_round_robin_arbiter.dart',
  'Serializer': 'rohd_src/serialization/serialization.dart',
  'ShiftRegister': 'rohd_src/memory/shift_register.dart',
  'SignMagnitudeAdder': 'rohd_src/arithmetic/sign_magnitude_adder.dart',
  'SignMagnitudeDualAdder': 'rohd_src/arithmetic/sign_magnitude_adder.dart',
  'SignedShifter': 'rohd_src/signed_shifter.dart',
  'SpiMain': 'rohd_src/gaskets/spi/spi_main.dart',
  'SpiSub': 'rohd_src/gaskets/spi/spi_sub.dart',
  'Sum': 'rohd_src/summation/sum.dart',
  'ToggleGate': 'rohd_src/toggle_gate.dart',
  'TreeOneHotToBinary': 'rohd_src/encodings/tree_one_hot_to_binary.dart',
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
