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
class Axi4SystemInterface extends PairInterface {
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
      PairDirection.sharedInputs,
    ]);
  }

  /// Constructs a new [Axi4SystemInterface] with identical parameters.
  Axi4SystemInterface clone() => Axi4SystemInterface();
}

/// Base abstraction that applies to all AXI channels.
abstract class Axi4ChannelInterface extends PairInterface {
  /// Number of channel ID bits.
  final int idWidth;

  /// Number of user field bits.
  final int userWidth;

  /// Prefix string for port declarations
  final String prefix;

  /// Helper to control which direction the signals should be coming from.
  final bool main;

  /// User-defined extension for the channel.
  ///
  /// Width is equal to [userWidth].
  Logic? get user => tryPort('${prefix}USER');

  /// Indicates that the channel signals are valid.
  ///
  /// Width is always 1.
  Logic get valid => port('${prefix}VALID');

  /// Indicates that a transfer on the channel can be accepted.
  ///
  /// Width is always 1.
  Logic get ready => port('${prefix}READY');

  /// Identification tag for transaction.
  ///
  /// Width is equal to [idWidth].
  Logic? get id => tryPort('${prefix}ID');

  /// Constructor.
  Axi4ChannelInterface({
    required this.prefix,
    required this.main,
    this.idWidth = 4,
    this.userWidth = 32,
  }) {
    setPorts([
      if (idWidth > 0) Logic.port('${prefix}ID', idWidth),
      if (userWidth > 0) Logic.port('${prefix}USER', userWidth),
      Logic.port('${prefix}VALID'),
    ], [
      if (main) PairDirection.fromProvider,
      if (!main) PairDirection.fromConsumer,
    ]);

    setPorts([
      Logic.port('${prefix}READY'),
    ], [
      if (main) PairDirection.fromConsumer,
      if (!main) PairDirection.fromProvider,
    ]);
  }
}

/// Wrapper for commonality in AXI Request channels (AR, AW, etc.).
abstract class Axi4RequestChannelInterface extends Axi4ChannelInterface {
  /// Width of the address bus.
  final int addrWidth;

  /// Width of len field.
  final int lenWidth;

  /// Width of the size field is fixed for AXI4.
  final int sizeWidth;

  /// Width of the burst field is fixed for AXI4.
  final int burstWidth;

  /// Width of the cache field is fixed for AXI4.
  final int cacheWidth;

  /// Width of the prot field is fixed for AXI4.
  final int protWidth;

  /// Width of the QoS field is fixed for AXI4.
  final int qosWidth;

  /// Width of the region field is fixed for AXI4.
  final int regionWidth;

  /// Controls the presence of lock which is an optional port.
  final bool useLock;

  /// The address of the first transfer in a transaction.
  ///
  /// Width is equal to [addrWidth].
  Logic get addr => port('${prefix}ADDR');

  /// Length, the exact number of data transfers in a transaction.
  ///
  /// Width is equal to [lenWidth].
  Logic? get len => tryPort('${prefix}LEN');

  /// Size, the number of bytes in each data transfer in a transaction.
  ///
  /// Width is equal to [sizeWidth].
  Logic? get size => tryPort('${prefix}SIZE');

  /// Burst type, indicates how address changes between
  /// each transfer in a transaction.
  ///
  /// Width is equal to [burstWidth].
  Logic? get burst => tryPort('${prefix}BURST');

  /// Provides information about atomic characteristics of a transaction.
  ///
  /// Width is always 1.
  Logic? get lock => tryPort('${prefix}LOCK');

  /// Indicates how a transaction is required to progress through a system.
  ///
  /// Width is equal to [cacheWidth].
  Logic? get cache => tryPort('${prefix}CACHE');

  /// Protection attributes of a transaction.
  ///
  /// Width is equal to [protWidth].
  Logic get prot => port('${prefix}PROT');

  /// Quality of service identifier for a transaction.
  ///
  /// Width is equal to [qosWidth].
  Logic? get qos => tryPort('${prefix}QOS');

  /// Region indicator for a transaction.
  ///
  /// Width is equal to [regionWidth].
  Logic? get region => tryPort('${prefix}REGION');

  /// Constructor.
  Axi4RequestChannelInterface({
    required super.prefix,
    super.idWidth = 4,
    super.userWidth = 4,
    this.addrWidth = 32,
    this.lenWidth = 8,
    this.useLock = true,
    this.sizeWidth = 3,
    this.burstWidth = 2,
    this.cacheWidth = 4,
    this.protWidth = 3,
    this.qosWidth = 4,
    this.regionWidth = 4,
  }) : super(main: true) {
    _validateParameters();

    setPorts([
      Logic.port('${prefix}ADDR', addrWidth),
      if (lenWidth > 0) Logic.port('${prefix}LEN', lenWidth),
      if (sizeWidth > 0) Logic.port('${prefix}SIZE', sizeWidth),
      if (burstWidth > 0) Logic.port('${prefix}BURST', burstWidth),
      if (useLock) Logic.port('${prefix}LOCK'),
      if (cacheWidth > 0) Logic.port('${prefix}CACHE', cacheWidth),
      Logic.port('${prefix}PROT', protWidth),
      if (qosWidth > 0) Logic.port('${prefix}QOS', qosWidth),
      if (regionWidth > 0) Logic.port('${prefix}REGION', regionWidth),
    ], [
      PairDirection.fromProvider,
    ]);
  }

  /// Checks that the values set for parameters follow the specification's
  /// restrictions.
  void _validateParameters() {
    if (addrWidth > 64 || addrWidth < 1) {
      throw RohdHclException('addrWidth must be >= 1 and <= 64.');
    }

    if (lenWidth < 0 || lenWidth > 8) {
      throw RohdHclException('lenWidth must be >= 0 and <= 8');
    }

    if (idWidth < 0 || idWidth > 32) {
      throw RohdHclException('idWidth must be >= 0 and <= 32');
    }
  }
}

/// AXI4 AR channel base. Need this to differentiate between AXI and AXI-Lite.
abstract class Axi4BaseArChannelInterface extends Axi4RequestChannelInterface {
  /// Constructor..
  Axi4BaseArChannelInterface({
    super.idWidth = 4,
    super.userWidth = 4,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.useLock = true,
    super.sizeWidth = 3,
    super.burstWidth = 2,
    super.cacheWidth = 4,
    super.protWidth = 3,
    super.qosWidth = 4,
    super.regionWidth = 4,
  }) : super(prefix: 'AR');
}

/// AXI4 AW channel base. Need this to differentiate between AXI and AXI-Lite.
abstract class Axi4BaseAwChannelInterface extends Axi4RequestChannelInterface {
  /// Constructor..
  Axi4BaseAwChannelInterface({
    super.idWidth = 4,
    super.userWidth = 4,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.useLock = true,
    super.sizeWidth = 3,
    super.burstWidth = 2,
    super.cacheWidth = 4,
    super.protWidth = 3,
    super.qosWidth = 4,
    super.regionWidth = 4,
  }) : super(prefix: 'AW');
}

/// Thin wrapper around abstract class to enforce certain paramater values.
class Axi4ArChannelInterface extends Axi4BaseArChannelInterface {
  /// Constructor.
  Axi4ArChannelInterface({
    super.idWidth = 4,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.userWidth = 32,
    super.useLock = true,
  }) : super(
          sizeWidth: 3,
          burstWidth: 2,
          cacheWidth: 4,
          protWidth: 3,
          qosWidth: 4,
          regionWidth: 4,
        );

  /// Copy constructor.
  Axi4ArChannelInterface clone() => Axi4ArChannelInterface(
        idWidth: idWidth,
        addrWidth: addrWidth,
        lenWidth: lenWidth,
        userWidth: userWidth,
        useLock: useLock,
      );
}

/// Thin wrapper around abstract class to enforce certain paramater values.
class Axi4AwChannelInterface extends Axi4BaseAwChannelInterface {
  /// Constructor.
  Axi4AwChannelInterface({
    super.idWidth = 4,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.userWidth = 32,
    super.useLock = true,
  }) : super(
          sizeWidth: 3,
          burstWidth: 2,
          cacheWidth: 4,
          protWidth: 3,
          qosWidth: 4,
          regionWidth: 4,
        );

  /// Copy constructor.
  Axi4AwChannelInterface clone() => Axi4AwChannelInterface(
        idWidth: idWidth,
        addrWidth: addrWidth,
        lenWidth: lenWidth,
        userWidth: userWidth,
        useLock: useLock,
      );
}

/// Wrapper for commonality in AXI Data channels (R, W, etc.).
abstract class Axi4DataChannelInterface extends Axi4ChannelInterface {
  /// Width of the transaction data bus.
  final int dataWidth;

  /// Controls the presence of last which is an optional port
  /// for multi burst transactions.
  final bool useLast;

  /// Transaction data.
  ///
  /// Width is equal to [dataWidth].
  Logic get data => port('${prefix}DATA');

  /// Indicates whether this is the last data transfer in a transaction.
  ///
  /// Width is always 1.
  Logic? get last => tryPort('${prefix}LAST');

  /// Constructor.
  Axi4DataChannelInterface({
    required super.prefix,
    required super.main,
    super.idWidth = 4,
    super.userWidth = 32,
    this.dataWidth = 64,
    this.useLast = true,
  }) {
    _validateParameters();

    setPorts([
      Logic.port('${prefix}DATA', dataWidth),
      if (useLast) Logic.port('${prefix}LAST'),
    ], [
      if (main) PairDirection.fromProvider,
      if (!main) PairDirection.fromConsumer,
    ]);
  }

  /// Checks that the values set for parameters follow the specification's
  /// restrictions.
  void _validateParameters() {
    const legalDataWidths = [8, 16, 32, 64, 128, 256, 512, 1024];
    if (!legalDataWidths.contains(dataWidth)) {
      throw RohdHclException('dataWidth must be one of $legalDataWidths');
    }
  }
}

/// AXI4 R channel base. Need this to differentiate between AXI and AXI-Lite.
abstract class Axi4BaseRChannelInterface extends Axi4DataChannelInterface {
  /// Width of the RRESP field is fixed for AXI4.
  final int respWidth;

  /// Read response, indicates the status of a read transfer.
  ///
  /// Width is equal to [respWidth].
  Logic? get resp => tryPort('RRESP');

  /// Constructor.
  Axi4BaseRChannelInterface({
    super.idWidth = 4,
    super.userWidth = 32,
    super.dataWidth = 64,
    super.useLast = true,
    this.respWidth = 2,
  }) : super(prefix: 'R', main: false) {
    setPorts([
      if (respWidth > 0) Logic.port('RRESP', respWidth),
    ], [
      PairDirection.fromConsumer,
    ]);
  }
}

/// AXI4 W channel base. Need this to differentiate between AXI and AXI-Lite.
abstract class Axi4BaseWChannelInterface extends Axi4DataChannelInterface {
  /// Width of the write strobe.
  final int strbWidth;

  /// Write strobes, indicate which byte lanes hold valid data.
  ///
  /// Width is equal to [strbWidth].
  Logic get strb => port('WSTRB');

  /// Constructor.
  Axi4BaseWChannelInterface({
    super.idWidth = 4,
    super.userWidth = 32,
    super.dataWidth = 64,
    super.useLast = true,
  })  : strbWidth = dataWidth ~/ 8,
        super(prefix: 'W', main: true) {
    setPorts([
      Logic.port('WSTRB', strbWidth),
    ], [
      PairDirection.fromProvider,
    ]);
  }
}

/// Thin wrapper around abstract class to enforce certain paramater values.
class Axi4RChannelInterface extends Axi4BaseRChannelInterface {
  /// Constructor.
  Axi4RChannelInterface({
    super.idWidth = 4,
    super.userWidth = 32,
    super.dataWidth = 64,
    super.useLast = true,
  }) : super(
          respWidth: 2,
        );

  /// Copy constructor.
  Axi4RChannelInterface clone() => Axi4RChannelInterface(
        idWidth: idWidth,
        userWidth: userWidth,
        dataWidth: dataWidth,
        useLast: useLast,
      );
}

/// Thin wrapper around abstract class to enforce certain paramater values.
class Axi4WChannelInterface extends Axi4BaseWChannelInterface {
  /// Constructor.
  Axi4WChannelInterface({
    super.idWidth = 4,
    super.userWidth = 32,
    super.dataWidth = 64,
    super.useLast = true,
  });

  /// Copy constructor.
  Axi4WChannelInterface clone() => Axi4WChannelInterface(
        idWidth: idWidth,
        userWidth: userWidth,
        dataWidth: dataWidth,
        useLast: useLast,
      );
}

/// AXI4 response channel base functionality.
abstract class Axi4ResponseChannelInterface extends Axi4ChannelInterface {
  /// Width of the BRESP field is fixed for AXI4.
  final int respWidth;

  /// Read response, indicates the status of a write transfer.
  ///
  /// Width is equal to [respWidth].
  Logic? get resp => tryPort('${prefix}RESP');

  /// Constructor.
  Axi4ResponseChannelInterface({
    required super.prefix,
    super.idWidth = 4,
    super.userWidth = 16,
    this.respWidth = 2,
  }) : super(main: false) {
    setPorts([
      if (respWidth > 0) Logic.port('${prefix}RESP', respWidth),
    ], [
      PairDirection.fromConsumer,
    ]);
  }
}

/// AXI4 R channel base. Need this to differentiate between AXI and AXI-Lite.
abstract class Axi4BaseBChannelInterface extends Axi4ResponseChannelInterface {
  /// Constructor.
  Axi4BaseBChannelInterface({
    super.idWidth = 4,
    super.userWidth = 16,
    super.respWidth = 2,
  }) : super(prefix: 'B');
}

/// Thin wrapper around abstract class to enforce certain paramater values.
class Axi4BChannelInterface extends Axi4BaseBChannelInterface {
  /// Constructor.
  Axi4BChannelInterface({
    super.idWidth = 4,
    super.userWidth = 16,
  }) : super(
          respWidth: 2,
        );

  /// Copy constructor.
  Axi4BChannelInterface clone() => Axi4BChannelInterface(
        idWidth: idWidth,
        userWidth: userWidth,
      );
}

/// A pairing of the AXI read channels (AR, R).
abstract class Axi4BaseReadCluster extends PairInterface {
  /// AR channel.
  late final Axi4BaseArChannelInterface arIntf;

  /// R channel.
  late final Axi4BaseRChannelInterface rIntf;

  /// Constructor.
  Axi4BaseReadCluster({
    required this.arIntf,
    required this.rIntf,
  }) {
    addSubInterface('AR', arIntf);
    addSubInterface('R', rIntf);
  }
}

/// A pairing of the AXI write channels (AW, W, B).
abstract class Axi4BaseWriteCluster extends PairInterface {
  /// AW channel.
  late final Axi4BaseAwChannelInterface awIntf;

  /// W channel.
  late final Axi4BaseWChannelInterface wIntf;

  /// B channel.
  late final Axi4BaseBChannelInterface bIntf;

  /// Constructor.
  Axi4BaseWriteCluster({
    required this.awIntf,
    required this.wIntf,
    required this.bIntf,
  }) {
    addSubInterface('AW', awIntf);
    addSubInterface('W', wIntf);
    addSubInterface('B', bIntf);
  }
}

/// A pairing of all AXI channels (read + write).
abstract class Axi4BaseCluster extends PairInterface {
  /// Read channels.
  late final Axi4BaseReadCluster read;

  /// Write channels.
  late final Axi4BaseWriteCluster write;

  /// Constructor.
  Axi4BaseCluster({
    required this.read,
    required this.write,
  }) {
    addSubInterface('READ', read);
    addSubInterface('WRITE', write);
  }
}

/// AXI4 read cluster.
class Axi4ReadCluster extends Axi4BaseReadCluster {
  /// Constructor.
  Axi4ReadCluster({
    int idWidth = 4, // TODO: split??
    int addrWidth = 32,
    int lenWidth = 8,
    int userWidth = 32, // TODO: split??
    bool useLock = false,
    int dataWidth = 64,
    bool useLast = true,
  }) : super(
            arIntf: Axi4ArChannelInterface(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth),
            rIntf: Axi4RChannelInterface(
                idWidth: idWidth,
                userWidth: userWidth,
                dataWidth: dataWidth,
                useLast: useLast));

  /// Copy constructor.
  Axi4ReadCluster clone() => Axi4ReadCluster(
        idWidth: arIntf.idWidth,
        addrWidth: arIntf.addrWidth,
        lenWidth: arIntf.lenWidth,
        userWidth: arIntf.userWidth,
        useLast: rIntf.useLast,
        useLock: arIntf.useLock,
        dataWidth: rIntf.dataWidth,
      );
}

/// AXI4 write cluster.
class Axi4WriteCluster extends Axi4BaseWriteCluster {
  /// Constructor.
  Axi4WriteCluster({
    int idWidth = 4, // TODO: split??
    int addrWidth = 32,
    int lenWidth = 8,
    int userWidth = 32, // TODO: split??
    bool useLock = false,
    int dataWidth = 64,
    bool useLast = true,
  }) : super(
            awIntf: Axi4AwChannelInterface(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth),
            wIntf: Axi4WChannelInterface(
                idWidth: idWidth,
                userWidth: userWidth,
                dataWidth: dataWidth,
                useLast: useLast),
            bIntf:
                Axi4BChannelInterface(idWidth: idWidth, userWidth: userWidth));

  /// Copy constructor.
  Axi4WriteCluster clone() => Axi4WriteCluster(
        idWidth: awIntf.idWidth,
        addrWidth: awIntf.addrWidth,
        lenWidth: awIntf.lenWidth,
        userWidth: awIntf.userWidth,
        useLast: wIntf.useLast,
        useLock: awIntf.useLock,
        dataWidth: wIntf.dataWidth,
      );
}

/// AXI4 cluster.
class Axi4Cluster extends Axi4BaseCluster {
  /// Constructor.
  ///
  /// TODO: split params??
  Axi4Cluster({
    int idWidth = 4,
    int addrWidth = 32,
    int lenWidth = 8,
    int userWidth = 32,
    bool useLock = false,
    int dataWidth = 64,
    bool useLast = true,
  }) : super(
            read: Axi4ReadCluster(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth,
                dataWidth: dataWidth,
                useLast: useLast),
            write: Axi4WriteCluster(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth,
                dataWidth: dataWidth,
                useLast: useLast));

  /// Copy constructor.
  Axi4Cluster clone() => Axi4Cluster(
        idWidth: read.arIntf.idWidth,
        addrWidth: read.arIntf.addrWidth,
        lenWidth: read.arIntf.lenWidth,
        userWidth: read.arIntf.userWidth,
        useLast: read.rIntf.useLast,
        useLock: read.arIntf.useLock,
        dataWidth: read.rIntf.dataWidth,
      );
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
