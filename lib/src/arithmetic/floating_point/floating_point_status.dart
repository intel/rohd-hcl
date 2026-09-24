// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_status.dart
// IEEE 754 floating-point exception status.
//
// 2026 August 25
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// IEEE 754 floating-point exception status.
class FloatingPointStatus extends LogicStructure {
  /// An invalid operation occurred.
  late final Logic invalid;

  /// A finite nonzero value was divided by zero.
  late final Logic divideByZero;

  /// The rounded result overflowed the destination format.
  late final Logic overflow;

  /// A tiny result was inexact after rounding.
  late final Logic underflow;

  /// The rounded result differs from the exact result.
  late final Logic inexact;

  /// Creates floating-point exception status signals.
  FloatingPointStatus({String name = 'status'})
      : this._([
          Logic(name: 'invalid'),
          Logic(name: 'divideByZero'),
          Logic(name: 'overflow'),
          Logic(name: 'underflow'),
          Logic(name: 'inexact'),
        ], name: name);

  FloatingPointStatus._(List<Logic> elements, {required super.name})
      : super(elements) {
    invalid = elements[0];
    divideByZero = elements[1];
    overflow = elements[2];
    underflow = elements[3];
    inexact = elements[4];
  }

  @override
  FloatingPointStatus clone({String? name}) => FloatingPointStatus._(
      elements.map((element) => element.clone(name: element.name)).toList(),
      name: name ?? this.name);
}
