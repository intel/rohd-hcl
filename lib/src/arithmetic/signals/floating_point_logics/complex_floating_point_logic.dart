// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

class ComplexFloatingPoint extends LogicStructure {
  final FloatingPoint realPart;

  final FloatingPoint imaginaryPart;

  static String _nameJoin(String? structName, String signalName) {
    if (structName == null) {
      return signalName;
    }
    return '${structName}_$signalName';
  }

  ComplexFloatingPoint({
    required int exponentWidth,
    required int mantissaWidth,
    String? name,
  }) : this._internal(
          realPart: FloatingPoint(
            exponentWidth: exponentWidth,
            mantissaWidth: mantissaWidth,
            name: _nameJoin(name, 're'),
          ),
          imaginaryPart: FloatingPoint(
            exponentWidth: exponentWidth,
            mantissaWidth: mantissaWidth,
            name: _nameJoin(name, 'im'),
          ),
          name: name,
        );

  ComplexFloatingPoint._internal(
      {required this.realPart, required this.imaginaryPart, super.name})
      : assert(realPart.exponent.width == imaginaryPart.exponent.width),
        assert(realPart.mantissa.width == imaginaryPart.mantissa.width),
        super([realPart, imaginaryPart]);

  @mustBeOverridden
  @override
  ComplexFloatingPoint clone({String? name}) => ComplexFloatingPoint(
        exponentWidth: realPart.exponent.width,
        mantissaWidth: realPart.mantissa.width,
        name: name,
      );

  ComplexFloatingPoint adder(ComplexFloatingPoint other) =>
      ComplexFloatingPoint._internal(
          realPart: FloatingPointAdderSinglePath(realPart, other.realPart).sum,
          imaginaryPart:
              FloatingPointAdderSinglePath(imaginaryPart, other.imaginaryPart)
                  .sum,
          name: _nameJoin(name, "adder"));

  ComplexFloatingPoint multiplier(ComplexFloatingPoint other) {
    // use only 3 multipliers: https://mathworld.wolfram.com/ComplexMultiplication.html
    final ac = FloatingPointMultiplierSimple(realPart, other.realPart).product;
    final bd = FloatingPointMultiplierSimple(imaginaryPart, other.imaginaryPart)
        .product;
    final abcd = FloatingPointMultiplierSimple(
            FloatingPointAdderSinglePath(realPart, imaginaryPart).sum,
            FloatingPointAdderSinglePath(other.realPart, other.imaginaryPart)
                .sum)
        .product;

    return ComplexFloatingPoint._internal(
        realPart: FloatingPointAdderSinglePath(ac, bd.negated()).sum,
        imaginaryPart: FloatingPointAdderSinglePath(abcd,
                FloatingPointAdderSinglePath(ac.negated(), bd.negated()).sum)
            .sum,
        name: _nameJoin(name, "multiplier"));
  }

  late final ComplexFloatingPoint negated = ComplexFloatingPoint._internal(
      realPart: realPart.negated(),
      imaginaryPart: imaginaryPart.negated(),
      name: _nameJoin(name, "negated"));
}
