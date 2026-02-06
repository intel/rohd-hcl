// Copyright (C) 2025 Intel Corporation
// SPDX-License-Indentifier: BSD-3-Clause
//
// floating_point_sqrt.dart
// An abstract base class defining the API for floating-point square root.
//
// 2025 March 3
// Authors: James Farwell <james.c.farwell@intel.com>,
//          Stephen Weeks <stephen.weeks@intel.com>,
//          Curtis Anderson <curtis.anders@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An abstract API for floating point square root.
abstract class FloatingPointSqrt<FpType extends FloatingPoint> extends Module {
  /// Width of the output exponent field.
  final int exponentWidth;

  /// Width of the output mantissa field.
  final int mantissaWidth;

  /// The [clk] : if a non-null clock signal is passed in, a pipestage is added
  /// to the square root to help optimize frequency.
  /// Plumbed for future work for pipelining, currently unsupported.
  @protected
  late final Logic? clk;

  /// Optional [reset], used only if a [clk] is not null to reset the pipeline
  /// flops.
  /// Plumbed for future work for pipelining, currently unsupported.
  @protected
  late final Logic? reset;

  /// Optional [enable], used only if a [clk] is not null to enable the pipeline
  /// flops.
  /// Plumbed for future work for pipelining, currently unsupported.
  @protected
  late final Logic? enable;

  /// The value [a], named this way to allow for a local variable 'a'.
  @protected
  late final FpType a;

  /// getter for the computed [FloatingPoint] output.
  late final FpType sqrt;

  /// getter for the [error] output.
  late final Logic error = Logic(name: 'error')..gets(output('error'));

  /// Square root a floating point number [a], returning result in [sqrt].
  /// - [clk], [reset], [enable] are optional inputs to control a pipestage
  /// (only inserted if [clk] is provided)
  FloatingPointSqrt(FpType a,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      super.name = 'floating_point_square_root',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : exponentWidth = a.exponent.width,
        mantissaWidth = a.mantissa.width,
        super(
            definitionName: definitionName ??
                'FloatingPointSquareRoot_E${a.exponent.width}'
                    'M${a.mantissa.width}') {
    this.clk = (clk != null) ? addInput('clk', clk) : null;
    this.reset = (reset != null) ? addInput('reset', reset) : null;
    this.enable = (enable != null) ? addInput('enable', enable) : null;
    this.a = addTypedInput('a', a);

    sqrt = addTypedOutput('sqrt', a.clone as FpType Function({String? name}));
    addOutput('error');
  }

  /// Pipelining helper that uses the context for signals clk/enable/reset
  Logic localFlop(Logic input) =>
      condFlop(clk, input, en: enable, reset: reset);
}
