// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_s.dart
// Definitions for the AXI-S interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

// TODO: parity signals

/// A standard AXI5 stream interface.
class Axi5StreamInterface extends Axi5TransportInterface {
  /// Width of the TDEST sideband field.
  final int destWidth;

  /// Width of the stream data bus.
  final int dataWidth;

  /// Width of the strobe/keep signals.
  final int strbWidth;

  /// Width of the ID signal.
  final int idWidth;

  /// Width of the USER signal.
  final int userWidth;

  /// Presence of LAST signal.
  final bool useLast;

  /// Presence of KEEP signal.
  final bool useKeep;

  /// Presence of STRB signal.
  final bool useStrb;

  /// Presence of WAKEUP signal.
  final bool useWakeup;

  /// Destination hint for the stream channel (user-defined).
  ///
  /// Width is equal to [destWidth].
  Logic? get dest => tryPort('TDEST');

  /// Stream data.
  ///
  /// Width is equal to [dataWidth].
  Logic? get data => tryPort('TDATA');

  /// Data strobes, indicate which byte lanes hold valid data.
  ///
  /// Width is equal to [strbWidth].
  Logic? get strb => tryPort('TSTRB');

  /// Keeps, which byte lanes of data shouldn't be ignored at the destination.
  ///
  /// Width is always 1.
  Logic? get keep => tryPort('TKEEP');

  /// Indicates whether this is the last data transfer in a stream.
  ///
  /// Width is always 1.
  Logic? get last => tryPort('TLAST');

  /// Identifier for the stream transfer.
  ///
  /// Width is equal to [idWidth].
  Logic? get id => tryPort('TID');

  /// User extension.
  ///
  /// Width is equal to [userWidth].
  Logic? get user => tryPort('TUSER');

  /// Wake up.
  ///
  /// Width is always 1.
  Logic? get wakeup => tryPort('TWAKEUP');

  /// Construct a new instance of an AXI5-S interface.
  ///
  /// Default values in constructor are from official spec.
  Axi5StreamInterface({
    this.idWidth = 4,
    this.dataWidth = 64,
    this.userWidth = 0,
    this.destWidth = 0,
    this.useKeep = false,
    this.useLast = false,
    this.useWakeup = false,
    this.useStrb = false,
  })  : strbWidth = dataWidth ~/ 8,
        super(
            main: true,
            prefix: 'T',
            useCrediting: false,
            sharedCredits: false,
            numRp: 0) {
    _validateParameters();

    setPorts([
      if (destWidth > 0) Logic.port('TDEST', destWidth),
      if (dataWidth > 0) Logic.port('TDATA', dataWidth),
      if (useStrb) Logic.port('TSTRB', strbWidth),
      if (useKeep) Logic.port('TKEEP', strbWidth),
      if (useLast) Logic.port('TLAST'),
      if (useWakeup) Logic.port('TWAKEUP'),
      if (idWidth > 0) Logic.port('TID', idWidth),
      if (userWidth > 0) Logic.port('TUSER', userWidth),
    ], [
      PairDirection.fromProvider,
    ]);
  }

  /// Constructs a new [Axi5StreamInterface] with identical parameters.
  @override
  Axi5StreamInterface clone() => Axi5StreamInterface(
      idWidth: idWidth,
      dataWidth: dataWidth,
      userWidth: userWidth,
      destWidth: destWidth,
      useKeep: useKeep,
      useLast: useLast,
      useWakeup: useWakeup,
      useStrb: useStrb);

  /// Checks that the values set for parameters follow the specification's
  /// restrictions.
  void _validateParameters() {
    // const legalDataWidths = [8, 16, 32, 64, 128, 256, 512, 1024];
    // if (!legalDataWidths.contains(dataWidth)) {
    //   throw RohdHclException('dataWidth must be one of $legalDataWidths');
    // }

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
