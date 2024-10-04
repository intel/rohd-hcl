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
  // The width of the data ports [mosi] and [miso].
  // final int dataWidth;

  /// The width of the chip select port [cs].
  // CS as individual lines or one
  // final int csWidth;

  //
  final int dataLength;

  ///
  Logic get sclk => port('SCLK');

  ///
  Logic get mosi => port('MOSI');

  ///
  Logic get miso => port('MISO');

  ///
  Logic get cs => port('CSB'); //CS bar

  ///
  SpiInterface({this.dataLength = 1})
      : super(
            portsFromConsumer: [Port('MISO')],
            portsFromProvider: [Port('MOSI'), Port('CSB'), Port('SCLK')]);

  ///
  SpiInterface.clone(SpiInterface super.otherInterface)
      : dataLength = otherInterface.dataLength,
        super.clone();

  // multiple CS or 4 bits in parallel
}

// place for spi mode = cpol and cpha 
