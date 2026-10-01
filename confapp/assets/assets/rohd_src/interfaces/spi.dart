// Copyright (C) 2024-2025 Intel Corporation
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

  /// Main Out Sub In (MOSI). Serial data from main to sub(s).
  Logic get mosi => port('MOSI');

  /// Main In Sub Out (MISO). Serial data from sub(s) to main.
  Logic get miso => port('MISO');

  /// Chip select (active low). Chip select signal from main to sub.
  Logic get csb => port('CSB');

  /// Creates a new [SpiInterface].
  SpiInterface({this.dataLength = 1})
      : super(portsFromConsumer: [
          Logic.port('MISO')
        ], portsFromProvider: [
          Logic.port('MOSI'),
          Logic.port('CSB'),
          Logic.port('SCLK')
        ]);

  /// Clones this [SpiInterface].
  @Deprecated('Use Instance-based `clone()` instead.')
  SpiInterface.clone(SpiInterface super.otherInterface)
      : dataLength = otherInterface.dataLength,
        super.clone();

  @override
  SpiInterface clone() => SpiInterface(dataLength: dataLength);
}
