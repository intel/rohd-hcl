// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/signals/floating_point_logics/complex_floating_point_logic.dart';

class Butterfly extends Module {
  late final ComplexFloatingPoint _inA;
  late final ComplexFloatingPoint _inB;
  late final ComplexFloatingPoint _twiddleFactor;

  late final ComplexFloatingPoint outA;
  late final ComplexFloatingPoint outB;

  Butterfly(
      {required ComplexFloatingPoint inA,
      required ComplexFloatingPoint inB,
      required ComplexFloatingPoint twiddleFactor,
      super.name = 'butterfly'}) {
    _inA = inA.clone()..gets(addInput('inA', inA, width: inA.width));
    _inB = inA.clone()..gets(addInput('inB', inB, width: inA.width));
    _twiddleFactor = inA.clone()..gets(addInput('twiddleFactor', twiddleFactor, width: twiddleFactor.width));

    final outALogic = addOutput('outA', width: inA.width);
    final outBLogic = addOutput('outB', width: inA.width);

    final temp = twiddleFactor.multiplier(_inB);

    outALogic <= _inA.adder(temp.negated);
    outBLogic <= _inA.adder(temp);

    outA = inA.clone()..gets(outALogic);
    outB = inA.clone()..gets(outBLogic);
  }
}
