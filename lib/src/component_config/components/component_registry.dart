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
      AbsoluteValueConfigurator(),
      ApbCsrCompleterConfigurator(),
      AsyncFifoConfigurator(),
      OnesComplementAdderConfigurator(),
      SignMagnitudeAdderConfigurator(),
      CarrySelectOnesComplementCompoundAdderConfigurator(),
      BinaryToGrayConfigurator(),
      BitwisePopcountConfigurator(),
      CeilDivideConfigurator(),
      CircularPointerConfigurator(),
      GrayToBinaryConfigurator(),
      CamConfigurator(),
      ClockGateConfigurator(),
      FifoConfigurator(),
      EccConfigurator(),
      RoundRobinArbiterConfigurator(),
      CounterConfigurator(),
      CountConfigurator(),
      CsrExampleConfigurator(),
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
      MuxConfigurator(),
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
      PadConfigurator(),
      ReadyValidFifoConfigurator(),
      ReductionTreeConfigurator(),
      SetBitsConfigurator(),
      SynchronizerConfigurator(),
      WithSetConfigurator(),
      FixedPointSqrtConfigurator(),
      FloatingPointSqrtConfigurator()
    ];
