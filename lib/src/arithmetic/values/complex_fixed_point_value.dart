// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:math';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

@immutable
class ComplexFixedPointValue {
  final FixedPointValue realPart;
  final FixedPointValue imaginaryPart;

  ComplexFixedPointValue({
    required this.realPart,
    required this.imaginaryPart,
  })  : assert(realPart.signed == imaginaryPart.signed),
        assert(realPart.m == imaginaryPart.m),
        assert(realPart.n == imaginaryPart.n);
}
