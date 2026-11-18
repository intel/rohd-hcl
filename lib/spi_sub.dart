// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_sub.dart
// Public typed SPI subordinate endpoint.
//
// 2026 November 18
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/spi/endpoints/spi_sub.dart'
    as implementation;

/// SPI subordinate with independently typed transmit and receive payloads.
class SpiSub<TIn extends Logic, TOut extends Logic>
    extends implementation.SpiSubImplementation<TIn, TOut> {
  /// Constructs an SPI subordinate endpoint with typed parallel ports.
  SpiSub(
      {required super.intf,
      required super.busOutSchema,
      super.busIn,
      super.reset,
      super.name,
      super.reserveName,
      super.reserveDefinitionName,
      super.definitionName});
}
