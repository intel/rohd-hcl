// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_s.dart
// Definitions for the AXI-S interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A standard AXI4 read interface.
class Axi4StreamInterface extends Axi4ChannelInterface {
  /// Width of the TDEST sideband field.
  final int destWidth;

  /// Width of the stream data bus.
  final int dataWidth;

  /// Width of the strobe/keep signals.
  final int strbWidth;

  /// Destination hint for the stream channel (user-defined).
  ///
  /// Width is equal to [destWidth].
  Logic? get dest => tryPort('TDEST');

  /// Stream data.
  ///
  /// Width is equal to [dataWidth].
  Logic get data => port('TDATA');

  /// Data strobes, indicate which byte lanes hold valid data.
  ///
  /// Width is equal to [strbWidth].
  Logic get strb => port('TSTRB');

  /// Keeps, which byte lanes of data shouldn't be ignored at the destination.
  ///
  /// Width is equal to [strbWidth].
  Logic get keep => port('TKEEP');

  /// Indicates whether this is the last data transfer in a stream.
  ///
  /// Width is always 1.
  Logic get last => port('TLAST');

  /// Construct a new instance of an AXI4 interface.
  ///
  /// Default values in constructor are from official spec.
  Axi4StreamInterface({
    super.idWidth = 4,
    this.dataWidth = 64,
    super.userWidth = 0,
    this.destWidth = 0,
  })  : strbWidth = dataWidth ~/ 8,
        super(main: true, prefix: 'T') {
    _validateParameters();

    setPorts([
      if (destWidth > 0) Logic.port('TDEST', destWidth),
      Logic.port('TDATA', dataWidth),
      Logic.port('TSTRB', strbWidth),
      Logic.port('TKEEP', strbWidth),
      Logic.port('TLAST'),
    ], [
      PairDirection.fromProvider,
    ]);
  }

  /// Constructs a new [Axi4StreamInterface] with identical parameters.
  Axi4StreamInterface clone() => Axi4StreamInterface(
      idWidth: idWidth,
      dataWidth: dataWidth,
      userWidth: userWidth,
      destWidth: destWidth);

  /// Checks that the values set for parameters follow the specification's
  /// restrictions.
  void _validateParameters() {
    const legalDataWidths = [8, 16, 32, 64, 128, 256, 512, 1024];
    if (!legalDataWidths.contains(dataWidth)) {
      throw RohdHclException('dataWidth must be one of $legalDataWidths');
    }

    if (idWidth < 0 || idWidth > 32) {
      throw RohdHclException('idWidth must be >= 0 and <= 32');
    }

    if (userWidth < 0 || userWidth > 128) {
      throw RohdHclException('userWidth must be >= 0 and <= 128');
    }

    if (destWidth < 0 || destWidth > 128) {
      throw RohdHclException('destWidth must be >= 0 and <= 128');
    }
  }
}
