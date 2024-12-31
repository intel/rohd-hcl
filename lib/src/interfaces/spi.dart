// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi.dart
// Definitions for Serial Peripheral Interface (SPI).
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd/rohd.dart';

/// A standard Serial Peripheral Interface.
class SpiInterface extends PairInterface {
  /// The data length for serial transmissions on this interface.
  final int dataLength;

  /// Serial clock (SCLK). Clock signal from main to sub(s).
  Logic get sclk => port('SCLK');
  // TODO(rt): add CPOL/CPHA support

  /// Main Out Sub In (MOSI). Serial data from main to sub(s).
  Logic get mosi => port('MOSI');

  /// Main In Sub Out (MISO). Serial data from sub(s) to main.
  Logic get miso => port('MISO');

  /// Chip select (active low). Chip select signal from main to sub.
  Logic get csb => port('CSB');
  // TODO(rt): add multiple CSB support

  /// Creates a new [SpiInterface].
  SpiInterface({this.dataLength = 1})
      : super(
            portsFromConsumer: [Port('MISO')],
            portsFromProvider: [Port('MOSI'), Port('CSB'), Port('SCLK')]);

  /// Clones this [SpiInterface].
  SpiInterface.clone(SpiInterface super.otherInterface)
      : dataLength = otherInterface.dataLength,
        super.clone();
}
