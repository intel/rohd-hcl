// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_container.dart
// A base class for things that contain a bunch of CSR stuff.
//
// 2024 December
// Author:
//   - Josh Kimmel <joshua1.kimmel@intel.com>
//   - Max Korbel <max.korbel@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A base class for configs for [CsrContainer]s.
abstract class CsrContainerConfig {
  /// Creates a clone of the configuration.
  CsrContainerConfig clone();

  /// Validates the configuration.
  void validate();

  /// Determines the minimum number of address bits needed to address all
  /// registers.
  int minAddrBits();

  /// Determines the maximum register size.
  int maxRegWidth();

  /// Name of the configuration.
  final String name;

  /// Creates a config for containers.
  CsrContainerConfig({required this.name});
}

/// A base class for things that a bunch of CSRs inside.
abstract class CsrContainer extends Module {
  /// Clock for the module.
  @protected
  late final Logic clk;

  /// Reset for the module.
  @protected
  late final Logic reset;

  /// Interface for frontdoor writes to CSRs.
  @protected
  late final DataPortInterface? frontWrite;

  /// Indicates whether there is a front-door write interface.
  @protected
  bool get frontWritePresent => frontWrite != null;

  /// Interface for frontdoor reads to CSRs.
  @protected
  late final DataPortInterface? frontRead;

  /// Indicates whether there is a front-door read interface.
  @protected
  bool get frontReadPresent => frontRead != null;

  /// The width for addresses.
  late final int addrWidth = frontWrite?.addrWidth ??
      frontRead?.addrWidth ??
      config.minAddrBits(); // TODO: test no read or write intf

  /// Internal copy of the original config.
  final CsrContainerConfig _config;

  /// Configuration for the container.
  CsrContainerConfig get config => _config.clone();

  /// Is it legal for the largest register width to be
  /// greater than the data width of the frontdoor interfaces.
  ///
  /// If this is true, HW generation must assign multiple addresses
  /// to any register that exceeds the data width of the frontdoor.
  final bool allowLargerRegisters;

  /// Constructs a base container.
  CsrContainer({
    required Logic clk,
    required Logic reset,
    required DataPortInterface? frontWrite,
    required DataPortInterface? frontRead,
    required CsrContainerConfig config,
    this.allowLargerRegisters = false,
  })  : _config = config.clone(),
        super(name: config.name) {
    config.validate();

    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);

    this.frontWrite = frontWrite == null
        ? null
        : (frontWrite.clone()
          ..connectIO(this, frontWrite,
              inputTags: {DataPortGroup.control, DataPortGroup.data},
              outputTags: {},
              uniquify: (original) => 'frontWrite_$original'));

    this.frontRead = frontRead == null
        ? null
        : (frontRead.clone()
          ..connectIO(this, frontRead,
              inputTags: {DataPortGroup.control},
              outputTags: {DataPortGroup.data},
              uniquify: (original) => 'frontRead_$original'));

    _validate();
  }

  /// Validates the construction of the container.
  void _validate() {
    if (frontReadPresent) {
      if (frontRead!.dataWidth < _config.maxRegWidth() &&
          !allowLargerRegisters) {
        throw CsrValidationException(
            'Frontdoor read interface data width must be '
            'at least ${_config.maxRegWidth()}.');
      }

      if (frontRead!.addrWidth < _config.minAddrBits()) {
        throw CsrValidationException(
            'Frontdoor read interface address width must be '
            'at least ${_config.minAddrBits()}.');
      }
    }

    if (frontWritePresent) {
      if (frontWrite!.dataWidth < _config.maxRegWidth() &&
          !allowLargerRegisters) {
        throw CsrValidationException(
            'Frontdoor write interface data width must be '
            'at least ${_config.maxRegWidth()}.');
      }

      if (frontWrite!.addrWidth < _config.minAddrBits()) {
        throw CsrValidationException(
            'Frontdoor write interface address width must be '
            'at least ${_config.minAddrBits()}.');
      }
    }

    if (frontReadPresent &&
        frontWritePresent &&
        frontWrite!.addrWidth != frontRead!.addrWidth) {
      throw CsrValidationException(
          'Frontdoor read and write interface address widths must be '
          'the same.');
    }
  }
}
