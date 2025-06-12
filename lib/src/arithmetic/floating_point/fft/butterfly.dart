// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/signals/floating_point_logics/complex_floating_point_logic.dart';

class Butterfly extends Module {
  final ComplexFloatingPoint inA;
  final ComplexFloatingPoint inB;
  final ComplexFloatingPoint twiddleFactor;

  late final outA = inA.clone()..gets(output('outA'));
  late final outB = inA.clone()..gets(output('outB'));

  Butterfly(
      {required this.inA,
      required this.inB,
      required this.twiddleFactor,
      super.name = 'butterfly'}) {
    addInput('inA', inA, width: inA.width);
    addInput('inB', inB, width: inA.width);

    final outA = addOutput('outA', width: inA.width);
    final outB = addOutput('outB', width: inA.width);

    final temp = twiddleFactor.multiplier(inB);

    outB <= inA.adder(temp.negated);
    outA <= inA.adder(temp);
  }
}
