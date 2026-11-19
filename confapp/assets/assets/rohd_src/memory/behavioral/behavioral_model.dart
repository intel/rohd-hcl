// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// behavioral_model.dart
// Behavioral memory model port and state definitions.
//
// 2026 October 16
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

/// Representation of signals at a behavioral SystemC boundary.
enum SystemCModelPortType {
  /// sc_logic/sc_lv ports retain X and Z.
  fourState,

  /// bool/sc_uint/sc_biguint ports match two-state generated hierarchies.
  twoState,
}

/// Explicit treatment of unknown outputs at a two-state boundary.
enum SystemCUnknownOutputPolicy {
  /// Report an error whenever an output contains unknown bits.
  error,

  /// Drive zero for unknown outputs until reset, then report errors.
  zeroUntilReset,
}

/// Execution-boundary choices, independent of storage and memory family.
final class SystemCModelOptions {
  /// Types used for external ports; internal state remains four-state.
  final SystemCModelPortType portType;

  /// Unknown-output treatment when using two-state ports.
  final SystemCUnknownOutputPolicy unknownOutputs;

  /// Creates a behavioral SystemC export policy.
  const SystemCModelOptions({
    this.portType = SystemCModelPortType.fourState,
    this.unknownOutputs = SystemCUnknownOutputPolicy.error,
  });
}

/// Simulator-independent elaborated metadata for a behavioral component.
///
/// Implementations must freeze configuration and must not capture Logic
/// objects, simulator subscriptions, live state, or executable field callbacks.
abstract interface class BehavioralModelDescription {
  /// Family identifier, such as `csr`; this does not select physical storage.
  String get kind;

  /// External input names and widths.
  Map<String, int> get inputPorts;

  /// External output names and widths.
  Map<String, int> get outputPorts;
}

/// A portable behavioral implementation, not a synthesized RTL graph.
abstract interface class BehavioralModel {
  /// Immutable configuration shared by execution backends.
  BehavioralModelDescription get description;

  /// Emits a standalone SystemC definition using [className].
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  });
}

/// Optional capability for modules with a portable behavioral implementation.
///
/// RTL instances return null. Existing memory base classes need not implement
/// this interface, and unsupported custom modules are not silently substituted.
abstract interface class BehavioralModelProvider {
  /// The selected portable model, or null when this is an RTL implementation.
  BehavioralModel? get behavioralModel;
}

/// Generic discovery callback for external exporters, without family checks.
///
/// Null means the object has no selected portable model. Errors from a
/// supported model propagate; unsupported exports never fall back silently.
String? generateBehavioralSystemC(
  Object candidate,
  String className, {
  SystemCModelOptions options = const SystemCModelOptions(),
}) =>
    candidate is BehavioralModelProvider
        ? candidate.behavioralModel
            ?.generateSystemC(className: className, options: options)
        : null;

/// Addressed data-port geometry, without imposing latency or access rules.
final class MemoryPortGeometry {
  /// Width of a logical address; address units are defined by the family.
  final int addressWidth;

  /// Width of the transferred data.
  final int dataWidth;

  /// Creates validated port geometry.
  MemoryPortGeometry({required this.addressWidth, required this.dataWidth}) {
    if (addressWidth <= 0 || dataWidth <= 0) {
      throw ArgumentError('Address and data widths must be positive.');
    }
  }
}
