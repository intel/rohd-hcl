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
import 'package:rohd_hcl/src/memory/csr/config/csr_container_config.dart';

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
  late final int addrWidth =
      frontWrite?.addrWidth ?? frontRead?.addrWidth ?? config.minAddrBits();

  /// Configuration for the container.
  final CsrContainerConfig config;

  /// Is it legal for the largest register width to be
  /// greater than the data width of the frontdoor interfaces.
  ///
  /// If this is true, HW generation must assign multiple addresses
  /// to any register that exceeds the data width of the frontdoor.
  final bool allowLargerRegisters;

  /// Constructs a base container.
  CsrContainer(
      {required Logic clk,
      required Logic reset,
      required DataPortInterface? frontWrite,
      required DataPortInterface? frontRead,
      required this.config,
      this.allowLargerRegisters = false,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'CsrContainer_A${config.minAddrBits()}_'
                    'W${config.maxRegWidth()}_'
                    'FW${frontWrite?.dataWidth ?? 0}_'
                    'fR${frontRead?.dataWidth ?? 0}_'
                    'LR=${allowLargerRegisters}_',
            name: config.name) {
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
      if (frontRead!.dataWidth < config.maxRegWidth() &&
          !allowLargerRegisters) {
        throw CsrValidationException(
            'Frontdoor read interface data width must be '
            'at least ${config.maxRegWidth()}.');
      }

      if (frontRead!.addrWidth < config.minAddrBits()) {
        throw CsrValidationException(
            'Frontdoor read interface address width must be '
            'at least ${config.minAddrBits()}.');
      }
    }

    if (frontWritePresent) {
      if (frontWrite!.dataWidth < config.maxRegWidth() &&
          !allowLargerRegisters) {
        throw CsrValidationException(
            'Frontdoor write interface data width must be '
            'at least ${config.maxRegWidth()}.');
      }

      if (frontWrite!.addrWidth < config.minAddrBits()) {
        throw CsrValidationException(
            'Frontdoor write interface address width must be '
            'at least ${config.minAddrBits()}.');
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
