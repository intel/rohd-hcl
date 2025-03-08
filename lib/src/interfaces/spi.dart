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

  /// The number of Chip Select signals in this interface.
  final int multiChipSelects;

  /// Serial clock (SCLK). Clock signal from main to sub(s).
  Logic get sclk => port('SCLK');

  /// Main Out Sub In (MOSI). Serial data from main to sub(s).
  Logic get mosi => port('MOSI');

  /// Main In Sub Out (MISO). Serial data from sub(s) to main.
  LogicNet get miso => port('MISO') as LogicNet;

  /// Chip select (active low). Chip select signal from main to sub.
  List<Logic> get csb => List.generate(multiChipSelects, (i) => port('CSB$i'));

  /// Creates a new [SpiInterface].
  SpiInterface({this.dataLength = 1, this.multiChipSelects = 1})
      : super(
            portsFromConsumer: [LogicNet.port('MISO')],
            portsFromProvider: [Port('MOSI'), Port('SCLK')] +
                List.generate(multiChipSelects, (i) => Port('CSB$i')));

  /// Clones this [SpiInterface].
  SpiInterface.clone(SpiInterface super.otherInterface)
      : dataLength = otherInterface.dataLength,
        multiChipSelects = otherInterface.multiChipSelects,
        super.clone();
}
