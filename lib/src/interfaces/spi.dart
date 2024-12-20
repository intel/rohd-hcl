// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi.dart
// Definitions for the SPI interface.
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd/rohd.dart';

/// A standard SPI interface.
class SpiInterface extends PairInterface {
  /// Data length.
  final int dataLength;
// TODO(rtorres): add CPOL/CPHA
  /// Serial clock.
  ///
  /// Clock signal driven by main.
  Logic get sclk => port('SCLK');

  /// Main Out Sub In.
  ///
  /// Serial data from main to sub.
  Logic get mosi => port('MOSI');

  /// Main In Sub Out.
  ///
  /// Serial data from sub to main.
  Logic get miso => port('MISO');

  /// Chip select (active low).
  ///
  /// Chip select signal from main to sub.
  Logic get csb => port('CSB');
  // TODO(cs): add multiple CSB support
  ///
  SpiInterface({this.dataLength = 1})
      : super(
            portsFromConsumer: [Port('MISO')],
            portsFromProvider: [Port('MOSI'), Port('CSB'), Port('SCLK')]);

  ///
  SpiInterface.clone(SpiInterface super.otherInterface)
      : dataLength = otherInterface.dataLength,
        super.clone();
}
