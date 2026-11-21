// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// hardware_core_functor.dart
// Typed construction seam for protocol-neutral hardware cores.
//
// 2026 October 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Construction-time metadata for one hardware-core functor.
///
/// Concrete capabilities describe only the shape and action semantics of their
/// core. They are intentionally not a universal protocol or signal algebra.
/// {@category Flow Control}
abstract interface class HardwareCoreCapabilities {
  /// Stable definition-name fragment describing the configured capabilities.
  String get configurationIdentity;
}

/// Result of constructing a protocol-neutral hardware core.
///
/// Concrete bindings expose the constructed [module] and its output ports.
/// Action inputs remain owned by the caller and are carried only by the typed
/// construction request.
/// {@category Flow Control}
abstract interface class HardwareCoreBinding {
  /// Core module constructed by the functor.
  Module get module;
}

/// Constructs a hardware core from a typed [Request] and returns its [Binding].
///
/// A functor has a stable [identity] and immutable [capabilities]. Protocol
/// shells create their own action and payload signals, place them in a request,
/// and consume only child output ports returned by the binding.
/// {@category Flow Control}
abstract class HardwareCoreFunctor<Request,
    Binding extends HardwareCoreBinding> {
  /// Creates a typed hardware-core construction functor.
  const HardwareCoreFunctor();

  /// Stable SystemVerilog-safe identity for this construction recipe.
  String get identity;

  /// Configured action and shape metadata.
  HardwareCoreCapabilities get capabilities;

  /// Constructs the child core named [name].
  Binding construct(Request request, {required String name});

  /// Validates and returns [identity] for use in definition names.
  String get definitionIdentity {
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(identity)) {
      throw ArgumentError.value(
        identity,
        'identity',
        'Must be a valid SystemVerilog identifier fragment.',
      );
    }
    return identity;
  }
}
