// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// gf_logic.dart
// Typed hardware signals for binary extension fields.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/finite_field/binary_extension_field.dart';
import 'package:rohd_hcl/src/arithmetic/finite_field/gf_value.dart';
import 'package:rohd_hcl/src/dataflow/reduction/reduction_tree_generator.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// A packed hardware signal representing an element of [field].
///
/// This remains an ordinary [Logic] signal for synthesis and connectivity, but
/// carries a field descriptor so incompatible fields cannot participate in
/// finite-field operations accidentally.
/// {@category Arithmetic}
class GfLogic extends Logic {
  /// The field represented by this signal.
  final BinaryExtensionField field;

  /// Creates an undriven signal representing an element of [field].
  GfLogic(
    this.field, {
    super.name,
    super.naming,
  }) : super(width: field.degree);

  /// Views [signal] as an element of [field].
  GfLogic.of(
    Logic signal, {
    required this.field,
    String? name,
  }) : super(name: name ?? signal.name, width: field.degree) {
    if (signal.width != field.degree) {
      throw RohdHclException(
          'GF(2^${field.degree}) signals require width ${field.degree}, '
          'not ${signal.width}.');
    }
    gets(signal);
  }

  /// The current two-state semantic value.
  GfValue get gfValue => field.fromLogicValue(value);

  /// Adds [other] in GF(2^m), implemented as bitwise XOR.
  @override
  GfLogic operator +(dynamic other) {
    final compatible = _compatibleOperand(other);
    return GfLogic.of(this ^ compatible, field: field);
  }

  /// Subtracts [other], which is identical to addition in characteristic two.
  @override
  GfLogic operator -(dynamic other) => this + other;

  /// Multiplies [other] using polynomial-basis combinational logic.
  @override
  GfLogic operator *(dynamic other) {
    final compatible = _compatibleOperand(other);
    final productWidth = field.degree * 2 - 1;
    final extended = zeroExtend(productWidth);
    final partialProducts = [
      for (var index = 0; index < field.degree; index++)
        mux(
          compatible[index],
          extended << index,
          Const(0, width: productWidth),
        ),
    ];
    final product = partialProducts.length == 1
        ? partialProducts.single
        : ReductionTreeGenerator(
            partialProducts,
            (inputs, {depth = 0, control, name = 'xor'}) =>
                inputs.reduce((left, right) => left ^ right),
          ).out;

    var reduced = product;
    for (var exponent = productWidth - 1;
        exponent >= field.degree;
        exponent--) {
      final shiftedModulus =
          field.modulus.coefficients << (exponent - field.degree);
      reduced = mux(
        reduced[exponent],
        reduced ^ Const(shiftedModulus, width: productWidth),
        reduced,
      );
    }

    return GfLogic.of(
      reduced.slice(field.degree - 1, 0),
      field: field,
    );
  }

  /// Returns a constant field element as a typed signal.
  factory GfLogic.constant(GfValue value, {String? name}) => GfLogic.of(
        Const(value.logicValue, preferredRadix: 2),
        field: value.field,
        name: name,
      );

  /// Drives this signal with a compatible [GfValue].
  @override
  void put(dynamic val, {bool fill = false}) {
    if (val is GfValue) {
      super.put(_compatibleValue(val).logicValue);
    } else {
      super.put(val, fill: fill);
    }
  }

  /// Injects a compatible [GfValue] in the current simulator tick.
  @override
  void inject(dynamic val, {bool fill = false}) {
    if (val is GfValue) {
      super.inject(_compatibleValue(val).logicValue);
    } else {
      super.inject(val, fill: fill);
    }
  }

  /// Compares two signals from the same field.
  @override
  Logic eq(dynamic other) => super.eq(_compatibleOperand(other));

  /// Compares two signals from the same field.
  @override
  Logic neq(dynamic other) => super.neq(_compatibleOperand(other));

  /// Field division requires a dedicated inverse architecture.
  @override
  Logic operator /(dynamic other) => throw UnimplementedError(
        'GfLogic division requires an explicit finite-field inverse '
        'architecture.',
      );

  /// Integer-style modulo is not a finite-field operation.
  @override
  Logic operator %(dynamic other) => throw UnsupportedError(
        'GfLogic does not support integer-style modulo.',
      );

  /// Field exponentiation requires an explicit hardware architecture.
  @override
  Logic pow(dynamic exponent) => throw UnimplementedError(
        'GfLogic exponentiation requires an explicit finite-field '
        'architecture.',
      );

  GfLogic _compatibleOperand(dynamic other) {
    if (other is! GfLogic) {
      throw RohdHclException(
          'Finite-field hardware operations require a GfLogic operand.');
    }
    field.requireCompatible(other.field);
    return other;
  }

  GfValue _compatibleValue(dynamic value) {
    if (value is! GfValue) {
      throw RohdHclException('GfLogic may only be driven by a GfValue.');
    }
    field.requireCompatible(value.field);
    return value;
  }

  /// Creates an undriven signal with this same field descriptor.
  @override
  GfLogic clone({String? name}) => GfLogic(field, name: name ?? this.name);

  /// Creates a named signal driven by this signal.
  @override
  GfLogic named(String name, {Naming? naming}) =>
      GfLogic(field, name: name, naming: naming)..gets(this);
}
