// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// interface_port_helpers.dart
// Helpers for registering interface ports on HCL modules.
//
// 2026 September 7
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Convenience methods for registering ROHD interfaces on HCL modules.
///
/// These methods are the HCL migration seam for alternate ROHD interface-port
/// layouts. Module implementations should use them instead of calling
/// `connectIO` or `pairConnectIO` directly.
extension RohdHclModuleInterfacePorts on Module {
  /// Clones [source], registers its selected ports on this module, and returns
  /// the clone for use by the module implementation.
  ///
  /// Registration is delegated to ROHD's module-level interface API, so the
  /// HCL call site does not depend on the concrete port layout.
  InterfaceType addInterface<InterfaceType extends Interface<TagType>,
          TagType extends Enum>(
    InterfaceType source, {
    Iterable<TagType>? inputTags,
    Iterable<TagType>? outputTags,
    Iterable<TagType>? inOutTags,
    String Function(String original)? uniquify,
  }) =>
      addInterfacePorts(
        source,
        inputTags: inputTags,
        outputTags: outputTags,
        inOutTags: inOutTags,
        uniquify: uniquify,
      );

  /// Clones [source], registers it for the selected [role], and returns the
  /// clone for use by the module implementation.
  ///
  /// This is the pair-interface equivalent of [addInterface]. The role
  /// determines which directions are inputs and outputs at the module
  /// boundary, while the pair interface retains its specialized connection
  /// behavior.
  InterfaceType addPairInterface<InterfaceType extends PairInterface>(
    InterfaceType source,
    PairRole role, {
    String Function(String original)? uniquify,
  }) =>
      addPairInterfacePorts(source, role, uniquify: uniquify);

  /// Registers an already-constructed [target] against [source] for cases
  /// where a module intentionally changes the concrete pair-interface type.
  ///
  /// Prefer [addPairInterface] when the internal interface has the same type
  /// as the external interface. This method keeps the exceptional retyped
  /// connection pattern behind the same HCL registration seam.
  InterfaceType addPairInterfaceFrom<InterfaceType extends PairInterface>(
    InterfaceType target,
    PairInterface source,
    PairRole role, {
    String Function(String original)? uniquify,
  }) {
    target.pairConnectIO(this, source, role, uniquify: uniquify);
    return target;
  }
}
