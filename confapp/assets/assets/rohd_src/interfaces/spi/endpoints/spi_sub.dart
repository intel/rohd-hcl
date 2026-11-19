// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_sub.dart
// Implementation of SPI Sub component.
//
// 2024 October 4
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/interfaces/spi/endpoints/spi_shift_register.dart';

/// SPI subordinate endpoint with independently typed transmit and receive
/// payloads.
class SpiSubImplementation<TIn extends Logic, TOut extends Logic>
    extends Module {
  /// Optional input bus carrying the transmit payload.
  TIn? get busIn => tryInput('busIn') as TIn?;

  /// Output bus from Sub.
  TOut get busOut => output('busOut') as TOut;

  /// Done signal from Sub.
  Logic? get done => tryOutput('done');

  /// Creates a SPI subordinate component that interfaces with [SpiInterface].
  ///
  /// The SPI Sub component will enable via chip select from [SpiInterface.csb].
  /// Clock signal will be received on [SpiInterface.sclk], data will shift in
  /// from [SpiInterface.mosi], and shift data out from [SpiInterface.miso].
  /// Data shifted in from [SpiInterface.mosi] will be available on [busOut].
  ///
  /// If [busIn] and [reset] are provided, reset clears the receive state and
  /// prepares a transmit load. Hold [busIn] stable through the first enabled
  /// falling SPI clock edge after reset; its most significant bit is driven
  /// before the first rising edge and the rest is loaded on that rising edge.
  /// An optional [done] indicates completion.
  ///
  /// [busOutSchema] describes the receive payload even when [busIn] is
  /// omitted. Both payloads must match the interface data length; their
  /// layouts may differ. Bits are shifted without semantic conversion.
  SpiSubImplementation(
      {required SpiInterface intf,
      required TOut busOutSchema,
      TIn? busIn,
      Logic? reset,
      String name = 'spiSub',
      bool reserveName = false,
      bool reserveDefinitionName = false,
      String? definitionName})
      : this._(
            intf: intf,
            busIn: busIn,
            busOutSchema: busOutSchema,
            reset: reset,
            flatPorts: false,
            name: name,
            reserveName: reserveName,
            reserveDefinitionName: reserveDefinitionName,
            definitionName: definitionName);

  SpiSubImplementation._(
      {required SpiInterface intf,
      required TOut busOutSchema,
      required bool flatPorts,
      TIn? busIn,
      Logic? reset,
      super.name = 'spiSub',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'SpiSub_W${busIn?.width ?? 0}_'
                    '${intf.dataLength}_'
                    '${intf.sclk.width}'
                    '${flatPorts || busIn == null ? '' : '_T'}'
                    '${flatPorts || busIn == null ? '' : ''
                        '${payloadShapeIdentity(busIn)}'}'
                    '${flatPorts ? '' : '_R'}'
                    '${flatPorts ? '' : payloadShapeIdentity(busOutSchema)}') {
    if (!flatPorts &&
        (busOutSchema.width != intf.dataLength ||
            (busIn != null && busIn.width != intf.dataLength))) {
      throw ArgumentError('SPI payload widths must match the data length.');
    }
    // SPI Interface
    intf = addPairInterfacePorts(intf, PairRole.consumer);

    // Bus Input to sub, if provided.
    final localBusIn = busIn == null
        ? null
        : flatPorts
            ? addInput('busIn', busIn, width: intf.dataLength)
            : addTypedInput<TIn>('busIn', busIn);

    // If reset is provided, add the reset input and done output.
    if (reset != null) {
      reset = addInput('reset', reset);

      addOutput('done');

      // Counter to track of the number of bits shifted out.
      final count = Counter.simple(
          clk: intf.sclk,
          enable: ~intf.csb,
          reset: reset,
          asyncReset: true,
          resetValue: intf.dataLength - 1,
          maxValue: intf.dataLength - 1);

      // Done signal will be high when the counter is at the max value.
      done! <= count.equalsMax;
    }

    // Bus Output from Sub
    if (flatPorts) {
      addOutput('busOut', width: intf.dataLength);
    } else {
      addTypedPayloadOutput<TOut>(this, 'busOut', busOutSchema);
    }

    final shiftReg = buildSpiShiftRegister(
      serialIn: intf.mosi,
      enable: ~intf.csb,
      clock: intf.sclk,
      width: intf.dataLength,
      reset: reset,
      parallelIn: localBusIn?.packed,
    );

    busOut <= shiftReg.parallelOut;

    intf.miso <= shiftReg.serialOut;
  }
}

/// Compatibility SPI subordinate endpoint with flat parallel ports.
@Deprecated("Use import 'package:rohd_hcl/rohd_hcl.dart' hide SpiSub; "
    "and import 'package:rohd_hcl/interfaces/spi/endpoints/spi_sub.dart';")
class SpiSub extends SpiSubImplementation<Logic, Logic> {
  /// Creates an SPI subordinate endpoint with flat parallel ports.
  @Deprecated("Use import 'package:rohd_hcl/rohd_hcl.dart' hide SpiSub; "
      "and import 'package:rohd_hcl/interfaces/spi/endpoints/spi_sub.dart';")
  // The compatibility output schema depends on the interface width.
  // ignore: use_super_parameters
  SpiSub(
      {required SpiInterface intf,
      Logic? busIn,
      Logic? reset,
      String name = 'spiSub',
      bool reserveName = false,
      bool reserveDefinitionName = false,
      String? definitionName})
      : super._(
            intf: intf,
            busIn: busIn,
            busOutSchema: Logic(width: intf.dataLength),
            reset: reset,
            flatPorts: true,
            name: name,
            reserveName: reserveName,
            reserveDefinitionName: reserveDefinitionName,
            definitionName: definitionName);
}
