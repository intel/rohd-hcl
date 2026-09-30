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
  'BinaryToOneHot': 'rohd_src/encodings/binary_to_one_hot.dart',
  'BinaryToGrayConverter': 'rohd_src/binary_gray.dart',
  'BitonicSort': 'rohd_src/sort.dart',
  'CarrySaveMultiplier': 'rohd_src/arithmetic/carry_save_mutiplier.dart',
  'CarrySelectCompoundAdder': 'rohd_src/arithmetic/compound_adder.dart',
  'CaseOneHotToBinary': 'rohd_src/encodings/case_one_hot_to_binary.dart',
  'CompressionTreeMultiplier': 'rohd_src/arithmetic/multiplier.dart',
  'Counter': 'rohd_src/summation/counter.dart',
  'Deserializer': 'rohd_src/serialization/serialization.dart',
  'EdgeDetector': 'rohd_src/edge_detector.dart',
  'Extrema': 'rohd_src/extrema.dart',
  'Fifo': 'rohd_src/memory/fifo.dart',
  'Find': 'rohd_src/find.dart',
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
  'GatedCounter': 'rohd_src/summation/gated_counter.dart',
  'GrayToBinaryConverter': 'rohd_src/binary_gray.dart',
  'HammingEccReceiver': 'rohd_src/error_checking/ecc.dart',
  'LeadingDigitAnticipate': 'rohd_src/arithmetic/leading_digit_anticipate.dart',
  'LeadingZeroAnticipate': 'rohd_src/arithmetic/leading_digit_anticipate.dart',
  'LeadingZeroAnticipateCarry':
      'rohd_src/arithmetic/leading_digit_anticipate.dart',
  'MaskRoundRobinArbiter': 'rohd_src/arbiters/mask_round_robin_arbiter.dart',
  'NativeMultiplier': 'rohd_src/arithmetic/multiplier.dart',
  'ParallelPrefixAdder': 'rohd_src/arithmetic/parallel_prefix_operations.dart',
  'PriorityArbiter': 'rohd_src/arbiters/priority_arbiter.dart',
  'RegisterFile': 'rohd_src/memory/register_file.dart',
  'RippleCarryAdder': 'rohd_src/arithmetic/ripple_carry_adder.dart',
  'RotateLeft': 'rohd_src/rotate.dart',
  'RotateRight': 'rohd_src/rotate.dart',
  'RotateRoundRobinArbiter':
      'rohd_src/arbiters/rotate_round_robin_arbiter.dart',
  'Serializer': 'rohd_src/serialization/serialization.dart',
  'Sum': 'rohd_src/summation/sum.dart',
  'TreeOneHotToBinary': 'rohd_src/encodings/tree_one_hot_to_binary.dart',
};

/// Returns the bundled ROHD source asset for [module], if one is indexed.
String? moduleSourceAsset(Module module) => switch (module) {
      BinaryToOneHot() => moduleSourceAssets['BinaryToOneHot'],
      BinaryToGrayConverter() => moduleSourceAssets['BinaryToGrayConverter'],
      BitonicSort() => moduleSourceAssets['BitonicSort'],
      CarrySaveMultiplier() => moduleSourceAssets['CarrySaveMultiplier'],
      CarrySelectCompoundAdder() =>
        moduleSourceAssets['CarrySelectCompoundAdder'],
      CaseOneHotToBinary() => moduleSourceAssets['CaseOneHotToBinary'],
      CompressionTreeMultiplier() =>
        moduleSourceAssets['CompressionTreeMultiplier'],
      GatedCounter() => moduleSourceAssets['GatedCounter'],
      Counter() => moduleSourceAssets['Counter'],
      Deserializer() => moduleSourceAssets['Deserializer'],
      EdgeDetector() => moduleSourceAssets['EdgeDetector'],
      Extrema() => moduleSourceAssets['Extrema'],
      Fifo() => moduleSourceAssets['Fifo'],
      Find() => moduleSourceAssets['Find'],
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
      GrayToBinaryConverter() => moduleSourceAssets['GrayToBinaryConverter'],
      HammingEccReceiver() => moduleSourceAssets['HammingEccReceiver'],
      LeadingDigitAnticipate() => moduleSourceAssets['LeadingDigitAnticipate'],
      LeadingZeroAnticipate() => moduleSourceAssets['LeadingZeroAnticipate'],
      LeadingZeroAnticipateCarry() =>
        moduleSourceAssets['LeadingZeroAnticipateCarry'],
      MaskRoundRobinArbiter() => moduleSourceAssets['MaskRoundRobinArbiter'],
      NativeMultiplier() => moduleSourceAssets['NativeMultiplier'],
      ParallelPrefixAdder() => moduleSourceAssets['ParallelPrefixAdder'],
      PriorityArbiter() => moduleSourceAssets['PriorityArbiter'],
      RegisterFile() => moduleSourceAssets['RegisterFile'],
      RippleCarryAdder() => moduleSourceAssets['RippleCarryAdder'],
      RotateLeft() => moduleSourceAssets['RotateLeft'],
      RotateRight() => moduleSourceAssets['RotateRight'],
      RotateRoundRobinArbiter() =>
        moduleSourceAssets['RotateRoundRobinArbiter'],
      Serializer() => moduleSourceAssets['Serializer'],
      Sum() => moduleSourceAssets['Sum'],
      TreeOneHotToBinary() => moduleSourceAssets['TreeOneHotToBinary'],
      _ => null,
    };

/// Converts a logical ROHD source path to its Flutter asset-bundle key.
String bundledSourceAssetPath(String sourceAsset) => 'assets/$sourceAsset';
