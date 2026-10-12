// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// component_registry.dart
// Registy of configurators.
//
// 2023 December 5
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';

/// A list of [Configurator]s for ROHD-HCL components.
List<Configurator> get componentRegistry => [
      RotateConfigurator(),
      ApbCsrCompleterConfigurator(),
      AsyncFifoConfigurator(),
      OnesComplementAdderConfigurator(),
      SignMagnitudeAdderConfigurator(),
      CarrySelectOnesComplementCompoundAdderConfigurator(),
      BinaryToGrayConfigurator(),
      GrayToBinaryConfigurator(),
      CamConfigurator(),
      ClockGateConfigurator(),
      FifoConfigurator(),
      EccConfigurator(),
      RoundRobinArbiterConfigurator(),
      CounterConfigurator(),
      CountConfigurator(),
      SumConfigurator(),
      PriorityArbiterConfigurator(),
      RippleCarryAdderConfigurator(),
      CarrySaveMultiplierConfigurator(),
      BitonicSortConfigurator(),
      OneHotConfigurator(),
      RegisterFileConfigurator(),
      EdgeDetectorConfigurator(),
      FindConfigurator(),
      FindPatternConfigurator(),
      Float8ToFixedConfigurator(),
      FloatingPointAdderConfigurator(),
      FloatingPointConverterConfigurator(),
      FloatingPointMultiplierSimpleConfigurator(),
      ParallelPrefixAdderConfigurator(),
      ParallelPrefixOperationConfigurator(),
      MultiplierConfigurator(),
      MultiplyAccumulateConfigurator(),
      DotProductConfigurator(),
      MultiCycleDividerConfigurator(),
      ExtremaConfigurator(),
      CompoundAdderConfigurator(),
      FixedToFloatConfigurator(),
      FloatToFixedConfigurator(),
      LeadingDigitAnticipateConfigurator(),
      SerializationConfigurator(),
      ShiftRegisterConfigurator(),
      SignedShifterConfigurator(),
      SpiConfigurator(),
      ToggleGateConfigurator(),
      PriorityEncoderConfigurator(),
      ParityConfigurator(),
      ReductionTreeConfigurator(),
      FixedPointSqrtConfigurator(),
      FloatingPointSqrtConfigurator()
    ];
