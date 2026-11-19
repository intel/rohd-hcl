// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_spi_main.dart
// Public typed SPI main endpoint.
//
// 2026 November 18
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/spi/endpoints/spi_main.dart'
    as implementation;

/// SPI main endpoint with independently typed transmit and receive payloads.
class SpiMain<TIn extends Logic, TOut extends Logic>
    extends implementation.SpiMainImplementation<TIn, TOut> {
  /// Constructs an SPI main endpoint with typed parallel ports.
  SpiMain(super.intf,
      {required super.clk,
      required super.reset,
      required super.start,
      required super.busIn,
      required super.busOutSchema,
      super.name,
      super.reserveName,
      super.reserveDefinitionName,
      super.definitionName});
}
