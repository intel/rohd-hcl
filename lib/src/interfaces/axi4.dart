// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4.dart
// Definitions for the AXI interface.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// A grouping of signals on the [Axi4ReadInterface] and [Axi4WriteInterface]
/// interfaces based on direction.
enum Axi4Direction {
  /// Miscellaneous system-level signals, common inputs to both sides.
  misc,

  /// Signals driven by the main.
  fromMain,

  /// Signals driven by the subordinate.
  fromSubordinate
}

/// AXI4 clock and reset.
class Axi4SystemInterface extends Interface<Axi4Direction> {
  /// Clock for the interface.
  ///
  /// Global clock signals. Synchronous signals are sampled
  /// on the rising edge of the global clock.
  Logic get clk => port('ACLK');

  /// Reset signal (active LOW).
  ///
  /// Global reset signal. This signal is active-LOW, synchronous
  /// but can be asserted asynchronously.
  Logic get resetN => port('ARESETn');

  /// Construct a new instance of an AXI4 interface.
  Axi4SystemInterface() {
    setPorts([
      Logic.port('ACLK'),
      Logic.port('ARESETn'),
    ], [
      Axi4Direction.misc,
    ]);
  }

  /// Constructs a new [Axi4SystemInterface] with identical parameters.
  @override
  Axi4SystemInterface clone() => Axi4SystemInterface();
}

/// A standard AXI4 read interface.
class Axi4ReadInterface extends Interface<Axi4Direction> {
  /// Number of channel ID bits.
  final int idWidth;

  /// Width of the address bus.
  final int addrWidth;

  /// Width of len field.
  final int lenWidth;

  /// Width of the user AR sideband field.
  final int aruserWidth;

  /// Width of the system data buses.
  final int dataWidth;

  /// Width of the user R sideband field.
  final int ruserWidth;

  /// Width of the size field is fixed for AXI4.
  final int sizeWidth = 3;

  /// Width of the burst field is fixed for AXI4.
  final int burstWidth = 2;

  /// Width of the cache field is fixed for AXI4.
  final int cacheWidth = 4;

  /// Width of the prot field is fixed for AXI4.
  final int protWidth = 3;

  /// Width of the QoS field is fixed for AXI4.
  final int qosWidth = 4;

  /// Width of the region field is fixed for AXI4.
  final int regionWidth = 4;

  /// Width of the RRESP field is fixed for AXI4.
  final int rrespWidth = 2;

  /// Controls the presence of [arLock] which is an optional port.
  final bool useLock;

  /// Controls the presence of [rLast] which is an optional port.
  final bool useLast;

  /// Identification tag for a read transaction.
  ///
  /// Width is equal to [idWidth].
  Logic? get arId => tryPort('ARID');

  /// The address of the first transfer in a read transaction.
  ///
  /// Width is equal to [addrWidth].
  Logic get arAddr => port('ARADDR');

  /// Length, the exact number of data transfers in a read transaction.
  ///
  /// Width is equal to [lenWidth].
  Logic? get arLen => tryPort('ARLEN');

  /// Size, the number of bytes in each data transfer in a read transaction.
  ///
  /// Width is equal to [sizeWidth].
  Logic? get arSize => tryPort('ARSIZE');

  /// Burst type, indicates how address changes between
  /// each transfer in a read transaction.
  ///
  /// Width is equal to [burstWidth].
  Logic? get arBurst => tryPort('ARBURST');

  /// Provides information about atomic characteristics of a read transaction.
  ///
  /// Width is always 1.
  Logic? get arLock => tryPort('ARLOCK');

  /// Indicates how a read transaction is required to progress through a system.
  ///
  /// Width is equal to [cacheWidth].
  Logic? get arCache => tryPort('ARCACHE');

  /// Protection attributes of a read transaction.
  ///
  /// Width is equal to [protWidth].
  Logic get arProt => port('ARPROT');

  /// Quality of service identifier for a read transaction.
  ///
  /// Width is equal to [qosWidth].
  Logic? get arQos => tryPort('ARQOS');

  /// Region indicator for a Read transaction.
  ///
  /// Width is equal to [regionWidth].
  Logic? get arRegion => tryPort('ARREGION');

  /// User-defined extension for the read address channel.
  ///
  /// Width is equal to [aruserWidth].
  Logic? get arUser => tryPort('ARUSER');

  /// Indicates that the read address channel signals are valid.
  ///
  /// Width is always 1.
  Logic get arValid => port('ARVALID');

  /// Indicates that a transfer on the read address channel can be accepted.
  ///
  /// Width is always 1.
  Logic get arReady => port('ARREADY');

  /// Identification tag for read data and response.
  ///
  /// Width is equal to [idWidth].
  Logic? get rId => tryPort('RID');

  /// Read data.
  ///
  /// Width is equal to [dataWidth].
  Logic get rData => port('RDATA');

  /// Read response, indicates the status of a read transfer.
  ///
  /// Width is equal to [rrespWidth].
  Logic? get rResp => tryPort('RRESP');

  /// Indicates whether this is the last data transfer in a read transaction.
  ///
  /// Width is always 1.
  Logic? get rLast => tryPort('RLAST');

  /// User-defined extension for the read data channel.
  ///
  /// Width is equal to [ruserWidth].
  Logic? get rUser => tryPort('RUSER');

  /// Indicates that the read data channel signals are valid.
  ///
  /// Width is always 1.
  Logic get rValid => port('RVALID');

  /// Indicates that a transfer on the read data channel can be accepted.
  ///
  /// Width is always 1.
  Logic get rReady => port('RREADY');

  /// Construct a new instance of an AXI4 interface.
  ///
  /// Default values in constructor are from official spec.
  Axi4ReadInterface({
    this.idWidth = 4,
    this.addrWidth = 32,
    this.lenWidth = 8,
    this.dataWidth = 64,
    this.aruserWidth = 32,
    this.ruserWidth = 32,
    this.useLock = true,
    this.useLast = true,
  }) {
    _validateParameters();

    setPorts([
      if (idWidth > 0) Logic.port('ARID', idWidth),
      Logic.port('ARADDR', addrWidth),
      if (lenWidth > 0) Logic.port('ARLEN', lenWidth),
      if (sizeWidth > 0) Logic.port('ARSIZE', sizeWidth),
      if (burstWidth > 0) Logic.port('ARBURST', burstWidth),
      if (useLock) Logic.port('ARLOCK'),
      if (cacheWidth > 0) Logic.port('ARCACHE', cacheWidth),
      Logic.port('ARPROT', protWidth),
      if (qosWidth > 0) Logic.port('ARQOS', qosWidth),
      if (regionWidth > 0) Logic.port('ARREGION', regionWidth),
      if (aruserWidth > 0) Logic.port('ARUSER', aruserWidth),
      Logic.port('ARVALID'),
      Logic.port('RREADY'),
    ], [
      Axi4Direction.fromMain,
    ]);

    setPorts([
      if (idWidth > 0) Logic.port('RID', idWidth),
      Logic.port('RDATA', dataWidth),
      if (rrespWidth > 0) Logic.port('RRESP', rrespWidth),
      if (useLast) Logic.port('RLAST'),
      if (ruserWidth > 0) Logic.port('RUSER', ruserWidth),
      Logic.port('RVALID'),
      Logic.port('ARREADY'),
    ], [
      Axi4Direction.fromSubordinate,
    ]);
  }

  /// Constructs a new [Axi4ReadInterface] with identical parameters to [other].
  @Deprecated('Use Instance-based `clone()` instead.')
  Axi4ReadInterface.clone(Axi4ReadInterface other)
      : this(
          idWidth: other.idWidth,
          addrWidth: other.addrWidth,
          lenWidth: other.lenWidth,
          dataWidth: other.dataWidth,
          aruserWidth: other.aruserWidth,
          ruserWidth: other.ruserWidth,
          useLock: other.useLock,
          useLast: other.useLast,
        );

  /// Constructs a new [Axi4ReadInterface] with identical parameters.
  @override
  Axi4ReadInterface clone() => Axi4ReadInterface(
      idWidth: idWidth,
      addrWidth: addrWidth,
      lenWidth: lenWidth,
      dataWidth: dataWidth,
      aruserWidth: aruserWidth,
      ruserWidth: ruserWidth,
      useLock: useLock,
      useLast: useLast);

  /// Checks that the values set for parameters follow the specification's
  /// restrictions.
  void _validateParameters() {
    if (addrWidth > 64 || addrWidth < 1) {
      throw RohdHclException('addrWidth must be >= 1 and <= 64.');
    }

    const legalDataWidths = [8, 16, 32, 64, 128, 256, 512, 1024];
    if (!legalDataWidths.contains(dataWidth)) {
      throw RohdHclException('dataWidth must be one of $legalDataWidths');
    }

    if (lenWidth < 0 || lenWidth > 8) {
      throw RohdHclException('lenWidth must be >= 0 and <= 8');
    }

    if (idWidth < 0 || idWidth > 32) {
      throw RohdHclException('idWidth must be >= 0 and <= 32');
    }

    if (aruserWidth < 0 || aruserWidth > 128) {
      throw RohdHclException('aruserWidth must be >= 0 and <= 128');
    }

    if (ruserWidth < 0 || ruserWidth > (dataWidth ~/ 2)) {
      throw RohdHclException(
          'ruserWidth must be >= 0 and <= ${dataWidth ~/ 2}');
    }
  }
}

/// A standard AXI4 write interface.
class Axi4WriteInterface extends Interface<Axi4Direction> {
  /// Number of channel ID bits.
  final int idWidth;

  /// Width of the address bus.
  final int addrWidth;

  /// Width of len field.
  final int lenWidth;

  /// Width of the user AW sideband field.
  final int awuserWidth;

  /// Width of the system data buses.
  final int dataWidth;

  /// Width of the write strobe.
  final int strbWidth;

  /// Width of the user W sideband field.
  final int wuserWidth;

  /// Width of the user B sideband field.
  final int buserWidth;

  /// Width of the size field is fixed for AXI4.
  final int sizeWidth = 3;

  /// Width of the burst field is fixed for AXI4.
  final int burstWidth = 2;

  /// Width of the cache field is fixed for AXI4.
  final int cacheWidth = 4;

  /// Width of the prot field is fixed for AXI4.
  final int protWidth = 3;

  /// Width of the QoS field is fixed for AXI4.
  final int qosWidth = 4;

  /// Width of the region field is fixed for AXI4.
  final int regionWidth = 4;

  /// Width of the BRESP field is fixed for AXI4.
  final int brespWidth = 2;

  /// Controls the presence of [awLock] which is an optional port.
  final bool useLock;

  /// Identification tag for a write transaction.
  ///
  /// Width is equal to [idWidth].
  Logic? get awId => tryPort('AWID');

  /// The address of the first transfer in a write transaction.
  ///
  /// Width is equal to [addrWidth].
  Logic get awAddr => port('AWADDR');

  /// Length, the exact number of data transfers in a write transaction.
  ///
  /// Width is equal to [lenWidth].
  Logic? get awLen => tryPort('AWLEN');

  /// Size, the number of bytes in each data transfer in a write transaction.
  ///
  /// Width is equal to [sizeWidth].
  Logic? get awSize => tryPort('AWSIZE');

  /// Burst type, indicates how address changes between each transfer.
  ///
  /// Width is equal to [burstWidth].
  Logic? get awBurst => tryPort('AWBURST');

  /// Provides information about atomic characteristics of a write transaction.
  ///
  /// Width is always 1.
  Logic? get awLock => tryPort('AWLOCK');

  /// Indicates how a write transaction is required to progress in a system.
  ///
  /// Width is equal to [cacheWidth].
  Logic? get awCache => tryPort('AWCACHE');

  /// Protection attributes of a write transaction.
  ///
  /// Width is equal to [protWidth].
  Logic get awProt => port('AWPROT');

  /// Quality of service identifier for a write transaction.
  ///
  /// Width is equal to [qosWidth].
  Logic? get awQos => tryPort('AWQOS');

  /// Region indicator for a write transaction.
  ///
  /// Width is equal to [regionWidth].
  Logic? get awRegion => tryPort('AWREGION');

  /// User-defined extension for the write address channel.
  ///
  /// Width is equal to [awuserWidth].
  Logic? get awUser => tryPort('AWUSER');

  /// Indicates that the write address channel signals are valid.
  ///
  /// Width is always 1.
  Logic get awValid => port('AWVALID');

  /// Indicates that a transfer on the write address channel can be accepted.
  ///
  /// Width is always 1.
  Logic get awReady => port('AWREADY');

  /// Write data.
  ///
  /// Width is equal to [dataWidth].
  Logic get wData => port('WDATA');

  /// Write strobes, indicate which byte lanes hold valid data.
  ///
  /// Width is equal to [strbWidth].
  Logic get wStrb => port('WSTRB');

  /// Indicates whether this is the last data transfer in a write transaction.
  ///
  /// Width is always 1.
  Logic get wLast => port('WLAST');

  /// User-defined extension for the write data channel.
  ///
  /// Width is equal to [wuserWidth].
  Logic? get wUser => tryPort('WUSER');

  /// Indicates that the write data channel signals are valid.
  ///
  /// Width is always 1.
  Logic get wValid => port('WVALID');

  /// Indicates that a transfer on the write data channel can be accepted.
  ///
  /// Width is always 1.
  Logic get wReady => port('WREADY');

  /// Identification tag for a write response.
  ///
  /// Width is equal to [idWidth].
  Logic? get bId => tryPort('BID');

  /// Write response, indicates the status of a write transaction.
  ///
  /// Width is equal to [brespWidth].
  Logic? get bResp => tryPort('BRESP');

  /// User-defined extension for the write response channel.
  ///
  /// Width is equal to [buserWidth].
  Logic? get bUser => tryPort('BUSER');

  /// Indicates that the write response channel signals are valid.
  ///
  /// Width is always 1.
  Logic get bValid => port('BVALID');

  /// Indicates that a transfer on the write response channel can be accepted.
  ///
  /// Width is always 1.
  Logic get bReady => port('BREADY');

  /// Construct a new instance of an AXI4 interface.
  ///
  /// Default values in constructor are from official spec.
  Axi4WriteInterface({
    this.idWidth = 4,
    this.addrWidth = 32,
    this.lenWidth = 8,
    this.dataWidth = 64,
    this.awuserWidth = 32,
    this.wuserWidth = 32,
    this.buserWidth = 16,
    this.useLock = true,
  }) : strbWidth = dataWidth ~/ 8 {
    _validateParameters();

    setPorts([
      if (idWidth > 0) Logic.port('AWID', idWidth),
      Logic.port('AWADDR', addrWidth),
      if (lenWidth > 0) Logic.port('AWLEN', lenWidth),
      if (sizeWidth > 0) Logic.port('AWSIZE', sizeWidth),
      if (burstWidth > 0) Logic.port('AWBURST', burstWidth),
      if (useLock) Logic.port('AWLOCK'),
      if (cacheWidth > 0) Logic.port('AWCACHE', cacheWidth),
      Logic.port('AWPROT', protWidth),
      if (qosWidth > 0) Logic.port('AWQOS', qosWidth),
      if (regionWidth > 0) Logic.port('AWREGION', regionWidth),
      if (awuserWidth > 0) Logic.port('AWUSER', awuserWidth),
      Logic.port('AWVALID'),
      Logic.port('WDATA', dataWidth),
      Logic.port('WSTRB', strbWidth),
      Logic.port('WLAST'),
      if (wuserWidth > 0) Logic.port('WUSER', wuserWidth),
      Logic.port('WVALID'),
      Logic.port('BREADY'),
    ], [
      Axi4Direction.fromMain,
    ]);

    setPorts([
      if (idWidth > 0) Logic.port('BID', idWidth),
      if (brespWidth > 0) Logic.port('BRESP', brespWidth),
      if (buserWidth > 0) Logic.port('BUSER', buserWidth),
      Logic.port('BVALID'),
      Logic.port('AWREADY'),
      Logic.port('WREADY'),
    ], [
      Axi4Direction.fromSubordinate,
    ]);
  }

  /// Constructs a new [Axi4WriteInterface] with
  /// identical parameters to [other].
  @Deprecated('Use Instance-based `clone()` instead.')
  Axi4WriteInterface.clone(Axi4WriteInterface other)
      : this(
          idWidth: other.idWidth,
          addrWidth: other.addrWidth,
          lenWidth: other.lenWidth,
          dataWidth: other.dataWidth,
          awuserWidth: other.awuserWidth,
          wuserWidth: other.wuserWidth,
          buserWidth: other.buserWidth,
          useLock: other.useLock,
        );

  /// Constructs a new [Axi4WriteInterface] with identical parameters.
  @override
  Axi4WriteInterface clone() => Axi4WriteInterface(
        idWidth: idWidth,
        addrWidth: addrWidth,
        lenWidth: lenWidth,
        dataWidth: dataWidth,
        awuserWidth: awuserWidth,
        wuserWidth: wuserWidth,
        buserWidth: buserWidth,
        useLock: useLock,
      );

  /// Checks that the values set for parameters follow the specification's
  /// restrictions.
  void _validateParameters() {
    if (addrWidth > 64 || addrWidth < 1) {
      throw RohdHclException('addrWidth must be >= 1 and <= 64.');
    }

    const legalDataWidths = [8, 16, 32, 64, 128, 256, 512, 1024];
    if (!legalDataWidths.contains(dataWidth)) {
      throw RohdHclException('dataWidth must be one of $legalDataWidths');
    }

    if (lenWidth < 0 || lenWidth > 8) {
      throw RohdHclException('lenWidth must be >= 0 and <= 8');
    }

    if (idWidth < 0 || idWidth > 32) {
      throw RohdHclException('idWidth must be >= 0 and <= 32');
    }

    if (awuserWidth < 0 || awuserWidth > 128) {
      throw RohdHclException('awuserWidth must be >= 0 and <= 128');
    }

    if (wuserWidth < 0 || wuserWidth > (dataWidth ~/ 2)) {
      throw RohdHclException(
          'wuserWidth must be >= 0 and <= ${dataWidth ~/ 2}');
    }

    if (buserWidth < 0 || buserWidth > 128) {
      throw RohdHclException('buserWidth must be >= 0 and <= 128');
    }
  }
}

/// Helper to enumerate the encodings of the xBURST signal.
enum Axi4BurstField {
  /// Address remains constants.
  fixed(0x0),

  /// Address increments by the transfer size.
  incr(0x1),

  /// Similar to incr, but wraps around to a lower boundary point
  /// when an upper boundary point is reached.
  wrap(0x2);

  /// Underlying value.
  final int value;

  const Axi4BurstField(this.value);
}

/// Helper to enumerate the encodings of the xSIZE signal.
enum Axi4SizeField {
  /// 1 byte.
  bit8(0x0),

  /// 2 bytes.
  bit16(0x1),

  /// 4 bytes.
  bit32(0x2),

  /// 8 bytes.
  bit64(0x3),

  /// 16 bytes.
  bit128(0x4),

  /// 32 bytes.
  bit256(0x5),

  /// 64 bytes.
  bit512(0x6),

  /// 128 bytes.
  bit1024(0x7);

  /// Underlying value.
  final int value;

  const Axi4SizeField(this.value);

  factory Axi4SizeField.fromValue(int value) {
    switch (value) {
      case 0x0:
        return Axi4SizeField.bit8;
      case 0x1:
        return Axi4SizeField.bit16;
      case 0x2:
        return Axi4SizeField.bit32;
      case 0x3:
        return Axi4SizeField.bit64;
      case 0x4:
        return Axi4SizeField.bit128;
      case 0x5:
        return Axi4SizeField.bit256;
      case 0x6:
        return Axi4SizeField.bit512;
      case 0x7:
        return Axi4SizeField.bit1024;
      default:
        throw ArgumentError('Invalid field value: $value');
    }
  }

  factory Axi4SizeField.fromSize(int value) {
    switch (value) {
      case 0x8:
        return Axi4SizeField.bit8;
      case 0x10:
        return Axi4SizeField.bit16;
      case 0x20:
        return Axi4SizeField.bit32;
      case 0x40:
        return Axi4SizeField.bit64;
      case 0x80:
        return Axi4SizeField.bit128;
      case 0x100:
        return Axi4SizeField.bit256;
      case 0x200:
        return Axi4SizeField.bit512;
      case 0x400:
        return Axi4SizeField.bit1024;
      default:
        throw ArgumentError('Invalid size value: $value');
    }
  }

  /// Helper to determine the implied size of the access.
  static int getImpliedSize(Axi4SizeField size) {
    switch (size) {
      case Axi4SizeField.bit8:
        return 8;
      case Axi4SizeField.bit16:
        return 16;
      case Axi4SizeField.bit32:
        return 32;
      case Axi4SizeField.bit64:
        return 64;
      case Axi4SizeField.bit128:
        return 128;
      case Axi4SizeField.bit256:
        return 256;
      case Axi4SizeField.bit512:
        return 512;
      case Axi4SizeField.bit1024:
        return 1024;
    }
  }
}

/// Helper to enumerate the one hot encodings of the AxPROT signal.
enum Axi4ProtField {
  /// Transaction to be performed in privileged mode (1) or non-privileged (0).
  privileged(0x1),

  /// Transaction is accessing secure memory (0) or unsecure memory (1).
  secure(0x2),

  /// Transaction is performing an instruction fetch (1) or data fetch (0).
  instruction(0x4);

  /// Underlying value.
  final int value;

  const Axi4ProtField(this.value);
}

/// Helper to enumerate the one hot encodings of the AxCACHE signal.
enum Axi4CacheField {
  /// Transaction can be buffered.
  bufferable(0x1),

  /// Transaction can be cached.
  cacheable(0x2),

  /// Cache space can be allocated during a read.
  readAllocate(0x4),

  /// Cache space can be allocated during a write
  writeAllocate(0x8);

  /// Underlying one hot encoded value.
  final int value;

  const Axi4CacheField(this.value);
}

/// Helper to enumerate the encodings of the xRESP signal.
enum Axi4RespField {
  /// Expected result.
  okay(0x0),

  /// Okay, exclusive access granted.
  exOkay(0x1),

  /// Subordinate recoverable error.
  slvErr(0x2),

  /// Subordinate fatal error.
  decErr(0x3);

  /// Underlying value.
  final int value;

  const Axi4RespField(this.value);
}
