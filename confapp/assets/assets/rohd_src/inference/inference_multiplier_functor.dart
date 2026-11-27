// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// inference_multiplier_functor.dart
// Named multiplier implementations for inference dot products.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/multiplication/multiplier.dart';
import 'package:rohd_hcl/src/static_or_runtime_control.dart';

/// Builds one multiplier lane for an inference dot product.
typedef InferenceMultiplierBuilder = Multiplier Function(
  Logic a,
  Logic b, {
  Logic? clk,
  Logic? reset,
  Logic? enable,
  StaticOrRuntimeParameter? signedMultiplicand,
  StaticOrRuntimeParameter? signedMultiplier,
});

/// A named, replaceable multiplier implementation.
@immutable
class InferenceMultiplierFunctor {
  final InferenceMultiplierBuilder _build;

  /// Stable implementation identity.
  final String identity;

  /// Creates a named multiplier implementation.
  const InferenceMultiplierFunctor({
    required this.identity,
    required InferenceMultiplierBuilder build,
  }) : _build = build;

  /// Instantiates one multiplier lane.
  Multiplier call(
    Logic a,
    Logic b, {
    Logic? clk,
    Logic? reset,
    Logic? enable,
    StaticOrRuntimeParameter? signedMultiplicand,
    StaticOrRuntimeParameter? signedMultiplier,
  }) =>
      _build(
        a,
        b,
        clk: clk,
        reset: reset,
        enable: enable,
        signedMultiplicand: signedMultiplicand,
        signedMultiplier: signedMultiplier,
      );
}

Multiplier _buildNativeMultiplier(
  Logic a,
  Logic b, {
  Logic? clk,
  Logic? reset,
  Logic? enable,
  StaticOrRuntimeParameter? signedMultiplicand,
  StaticOrRuntimeParameter? signedMultiplier,
}) =>
    NativeMultiplier(
      a,
      b,
      clk: clk,
      reset: reset,
      enable: enable,
      signedMultiplicand: signedMultiplicand,
      signedMultiplier: signedMultiplier,
    );

/// Native-operator multiplier implementation.
const nativeInferenceMultiplierFunctor = InferenceMultiplierFunctor(
  identity: 'native',
  build: _buildNativeMultiplier,
);

/// Creates a compression-tree multiplier implementation.
InferenceMultiplierFunctor compressionTreeInferenceMultiplierFunctor({
  int radix = 4,
}) =>
    InferenceMultiplierFunctor(
      identity: 'compressionTreeR$radix',
      build: (
        a,
        b, {
        clk,
        reset,
        enable,
        signedMultiplicand,
        signedMultiplier,
      }) =>
          CompressionTreeMultiplier(
        a,
        b,
        radix: radix,
        clk: clk,
        reset: reset,
        enable: enable,
        signedMultiplicand: signedMultiplicand,
        signedMultiplier: signedMultiplier,
      ),
    );
