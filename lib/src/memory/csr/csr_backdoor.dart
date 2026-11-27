// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_backdoor.dart
// Interface for backdoor CSR access.
//
// 2024 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A grouping for interface signals of [CsrBackdoorInterface]s.
enum CsrBackdoorPortGroup {
  /// For HW reads of CSRs.
  read,

  /// For HW writes to CSRs.
  write
}

/// An interface to interact very simply with a CSR.
///
/// Can be used for either read, write or both directions.
class CsrBackdoorInterface extends Interface<CsrBackdoorPortGroup> {
  /// Configuration for the associated CSR.
  final CsrInstanceConfig config;

  /// Should this CSR be readable by the HW.
  final bool hasRead;

  /// Should this CSR be writable by the HW.
  final bool hasWrite;

  /// The width of data in the CSR.
  final int dataWidth;

  /// The read data from the CSR.
  Csr? get rdData => tryPort(config.name) as Csr?;

  /// Write the CSR in this cycle.
  Logic? get wrEn => tryPort('${config.name}_wrEn');

  /// Data to write to the CSR in this cycle.
  Logic? get wrData => tryPort('${config.name}_wrData');

  /// Constructs a new interface of specified [dataWidth]
  /// and conditionally instantiates read and writes ports based on
  /// [hasRead] and [hasWrite].
  CsrBackdoorInterface({
    required this.config,
  })  : dataWidth = config.width,
        hasRead = config.isBackdoorReadable,
        hasWrite = config.isBackdoorWritable {
    if (hasRead) {
      setPorts([
        Csr(config),
      ], [
        CsrBackdoorPortGroup.read,
      ]);
    }

    if (hasWrite) {
      setPorts([
        Logic.port('${config.name}_wrEn'),
        Logic.port('${config.name}_wrData', dataWidth),
      ], [
        CsrBackdoorPortGroup.write,
      ]);
    }
  }

  bool _suppressRead = false;

  @override
  Map<String, Logic> getPorts([Iterable<CsrBackdoorPortGroup>? tags]) {
    final ports = super.getPorts(tags);
    return _suppressRead
        ? (Map<String, Logic>.of(ports)..remove(config.name))
        : ports;
  }

  @override
  void connectIO(Module module, Interface<dynamic> srcInterface,
      {Iterable<CsrBackdoorPortGroup>? inputTags,
      Iterable<CsrBackdoorPortGroup>? outputTags,
      Iterable<CsrBackdoorPortGroup>? inOutTags,
      String Function(String original)? uniquify}) {
    final inputs = inputTags?.toSet();
    final outputs = outputTags?.toSet();
    final inOuts = inOutTags?.toSet();
    final input =
        hasRead && (inputs?.contains(CsrBackdoorPortGroup.read) ?? false);
    final output =
        hasRead && (outputs?.contains(CsrBackdoorPortGroup.read) ?? false);
    if ((input || output) &&
        (inOuts?.contains(CsrBackdoorPortGroup.read) ?? false)) {
      throw PortTypeException.forIntendedName(
          config.name, 'CSR read ports cannot also be inOut ports.');
    }
    if (input || output) {
      final local = rdData!;
      final source = srcInterface.port(config.name);
      if (!rohdPayloadsCompatible([local, source])) {
        throw PortTypeException.forIntendedName(
            config.name, 'CSR backdoor read layout does not match.');
      }
      final name = uniquify?.call(config.name) ?? config.name;
      if (input) {
        final bridge = local.clone(name: '${config.name}_input_bridge')
          ..gets(source);
        local <= module.addTypedInput(name, bridge);
      }
      if (output) {
        final registered = module.addTypedOutput(name, local.clone);
        registered <= local;
        source <= registered;
      }
    }
    _suppressRead = input || output;
    try {
      super.connectIO(module, srcInterface,
          inputTags: inputs,
          outputTags: outputs,
          inOutTags: inOuts,
          uniquify: uniquify);
    } finally {
      _suppressRead = false;
    }
  }

  /// Makes a copy of this [Interface] with matching configuration.
  @override
  CsrBackdoorInterface clone() => CsrBackdoorInterface(config: config);
}
