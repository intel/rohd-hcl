// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_implementation.dart
// CSR implementation strategy definitions.
//
// 2026 October 16
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

/// Implementation of a CSR top, independent of its architectural register map.
enum CsrImplementation {
  /// Synthesizable register and decode logic (the existing default).
  rtl,

  /// Whole-top software state with only explicitly requested hardware ports.
  software,
}

/// Elaboration policy for a CSR top.
class CsrImplementationConfiguration {
  /// Storage and execution implementation.
  final CsrImplementation implementation;

  /// Hardware-connected registers, named `block/register`.
  ///
  /// An empty set exposes none. `null` exposes all architecturally accessible
  /// registers. This does not affect software inspection or frontdoor access.
  final Set<String>? hardwareRegisters;

  /// Creates an implementation policy.
  const CsrImplementationConfiguration({
    this.implementation = CsrImplementation.rtl,
    this.hardwareRegisters,
  });

  /// Software implementation with no per-register hardware connections.
  static const software = CsrImplementationConfiguration(
    implementation: CsrImplementation.software,
    hardwareRegisters: {},
  );
}

/// Scoped construction policy, including indirectly constructed CSR tops.
abstract final class CsrImplementationScope {
  static final Object _key = Object();

  /// Policy used when a constructor does not provide an explicit override.
  static CsrImplementationConfiguration get current =>
      Zone.current[_key] as CsrImplementationConfiguration? ??
      const CsrImplementationConfiguration();

  /// Constructs [body] under [configuration], without changing global state.
  static T run<T>(
    CsrImplementationConfiguration configuration,
    T Function() body,
  ) =>
      runZoned(body, zoneValues: {_key: configuration});
}
