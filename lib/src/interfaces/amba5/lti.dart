// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// lti.dart
// Base classes for LTI interfaces.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Next level in the hierarchy to handle the flow control schemes.
abstract class LtiTransportInterface extends Axi5BaseInterface {
  /// Number of virtual channels.
  final int vcCount;

  /// Virtual channel identifier.
  ///
  /// Width is equal to log2(vcCount).
  Logic? get vc => tryPort('${prefix}VC');

  /// Credit return.
  ///
  /// Width is equal to [vcCount].
  Logic? get credit => tryPort('${prefix}CREDIT');

  /// Constructor.
  LtiTransportInterface({
    required super.prefix,
    required super.main,
    this.vcCount = 1,
  }) {
    setPorts([
      if (vcCount > 0) Logic.port('${prefix}CREDIT', vcCount),
    ], [
      if (main) PairDirection.fromConsumer,
      if (!main) PairDirection.fromProvider,
    ]);

    setPorts([
      if (vcCount > 1) Logic.port('${prefix}VC', log2Ceil(vcCount)),
    ], [
      if (main) PairDirection.fromProvider,
      if (!main) PairDirection.fromConsumer,
    ]);
  }
}

/// A config object for constructing an LTI LA channel.
class LtiLaChannelConfig {
  /// The width of the user-defined signal in bits.
  final int userWidth;

  /// The width of the ID signal in bits.
  final int idWidth;

  /// The width of the address bus in bits.
  final int addrWidth;

  /// Realm Management Extension support.
  final bool rmeSupport;

  /// Inst/priv support.
  final bool instPrivPresent;

  /// The width of PAS signal in bits.
  final int pasWidth;

  /// Loopback signal width.
  final int loopWidth;

  /// Secure stream ID width.
  final int secSidWidth;

  /// Stream ID width.
  final int sidWidth;

  /// Substream ID width.
  final int ssidWidth;

  /// Flow support.
  final bool useFlow;

  /// GDI support.
  final bool supportGdi;

  /// RME and PAS support.
  final bool supportRmeAndPasMmu;

  /// OG width.
  final int ogWidth;

  /// TLBLOCK width.
  final int tlBlockWidth;

  /// Use IDENT.
  final bool useIdent;

  /// Constructor.
  LtiLaChannelConfig({
    this.userWidth = 0,
    this.idWidth = 0,
    this.addrWidth = 0,
    this.rmeSupport = false,
    this.instPrivPresent = false,
    this.pasWidth = 0,
    this.loopWidth = 0,
    this.secSidWidth = 0,
    this.sidWidth = 0,
    this.ssidWidth = 0,
    this.useFlow = false,
    this.supportGdi = false,
    this.supportRmeAndPasMmu = false,
    this.ogWidth = 0,
    this.tlBlockWidth = 0,
    this.useIdent = false,
  });

  /// Creates a copy of this config.
  LtiLaChannelConfig clone() => LtiLaChannelConfig(
        userWidth: userWidth,
        idWidth: idWidth,
        addrWidth: addrWidth,
        rmeSupport: rmeSupport,
        instPrivPresent: instPrivPresent,
        pasWidth: pasWidth,
        loopWidth: loopWidth,
        secSidWidth: secSidWidth,
        sidWidth: sidWidth,
        ssidWidth: ssidWidth,
        useFlow: useFlow,
        supportGdi: supportGdi,
        supportRmeAndPasMmu: supportRmeAndPasMmu,
        ogWidth: ogWidth,
        tlBlockWidth: tlBlockWidth,
        useIdent: useIdent,
      );
}

/// Basis for all possible LA channels.
///
/// TODO: MMU signals don't have MMU prefix (except for valid...)
class LtiLaChannelInterface extends LtiTransportInterface
    with
        Axi5UserSignals,
        Axi5IdSignals,
        Axi5ProtSignals,
        Axi5DebugSignals,
        Axi5MmuSignals {
  /// Enable ID signal mixin
  final bool idMixInEnable;

  /// Enable MMU signal mixin
  final bool mmuMixInEnable;

  /// Enable Debug signal mixin
  final bool debugMixInEnable;

  /// Enable User signal mixin
  final bool userMixInEnable;

  @override
  final int userWidth;
  @override
  final int idWidth;
  @override
  final bool useIdUnq;
  @override
  final int protWidth;
  @override
  final bool rmeSupport;
  @override
  final bool instPrivPresent;
  @override
  final int pasWidth;
  @override
  final bool tracePresent;
  @override
  final int loopWidth;
  @override
  final int untranslatedTransVersion;
  @override
  final int secSidWidth;
  @override
  final int sidWidth;
  @override
  final int ssidWidth;
  @override
  final bool useFlow;
  @override
  final bool supportGdi;
  @override
  final bool supportRmeAndPasMmu;

  /// Address width.
  final int addrWidth;

  /// OG WIDTH.
  final int ogWidth;

  /// TLBLOCK WIDTH.
  final int tlBlockWidth;

  /// Use IDENT signal.
  final bool useIdent;

  /// Address.
  ///
  /// Width is equal to [addrWidth].
  Logic get addr => port('${prefix}ADDR');

  /// Trans.
  ///
  /// Width is equal to 4.
  Logic get trans => port('${prefix}TRANS');

  /// Attr.
  ///
  /// Width is equal to 4.
  Logic get attr => port('${prefix}ATTR');

  /// TLBLOCK.
  ///
  /// Width is equal to [tlBlockWidth].
  Logic? get tlBlock => tryPort('${prefix}TLBLOCK');

  /// OG VALID.
  ///
  /// Width is always 1.
  Logic get ogv => port('${prefix}OGV');

  /// OG.
  ///
  /// Width is equal to [ogWidth].
  Logic? get og => tryPort('${prefix}OG');

  /// IDENT.
  ///
  /// Width is always 1.
  Logic? get ident => tryPort('${prefix}IDENT');

  /// Constructor.
  LtiLaChannelInterface({
    required LtiLaChannelConfig config,
    super.vcCount = 1,
    this.debugMixInEnable = false,
    this.idMixInEnable = false,
    this.userMixInEnable = false,
    this.mmuMixInEnable = false,
  })  : userWidth = config.userWidth,
        idWidth = config.idWidth,
        useIdUnq = false,
        addrWidth = config.addrWidth,
        protWidth = 0,
        rmeSupport = config.rmeSupport,
        instPrivPresent = config.instPrivPresent,
        pasWidth = config.pasWidth,
        loopWidth = config.loopWidth,
        tracePresent = false,
        secSidWidth = config.secSidWidth,
        sidWidth = config.sidWidth,
        ssidWidth = config.ssidWidth,
        useFlow = config.useFlow,
        supportGdi = config.supportGdi,
        supportRmeAndPasMmu = config.supportRmeAndPasMmu,
        ogWidth = config.ogWidth,
        tlBlockWidth = config.tlBlockWidth,
        useIdent = config.useIdent,
        untranslatedTransVersion =
            4, // must have ability to support PM/PASUNKNOWN
        super(
          prefix: 'LA',
          main: true,
        ) {
    setPorts([
      Logic.port('${prefix}ADDR', addrWidth),
      Logic.port('${prefix}TRANS', 4),
      Logic.port('${prefix}ATTR', 4),
      if (tlBlockWidth > 0) Logic.port('${prefix}TLBLOCK', tlBlockWidth),
      Logic.port('${prefix}OGV'),
      if (ogWidth > 0) Logic.port('${prefix}OG', ogWidth),
      if (useIdent) Logic.port('${prefix}IDENT'),
    ], [
      PairDirection.fromProvider,
    ]);
    makeProtPorts();
    if (userMixInEnable) {
      makeUserPorts();
    }
    if (idMixInEnable) {
      makeIdPorts();
    }
    if (debugMixInEnable) {
      makeDebugPorts();
    }
    if (mmuMixInEnable) {
      makeMmuPorts();
    }
  }

  /// Copy Constructor.
  @override
  LtiLaChannelInterface clone() => LtiLaChannelInterface(
        config: LtiLaChannelConfig(
          userWidth: userWidth,
          idWidth: idWidth,
          loopWidth: loopWidth,
          addrWidth: addrWidth,
          rmeSupport: rmeSupport,
          instPrivPresent: instPrivPresent,
          pasWidth: pasWidth,
          secSidWidth: secSidWidth,
          sidWidth: sidWidth,
          ssidWidth: ssidWidth,
          useFlow: useFlow,
          supportGdi: supportGdi,
          supportRmeAndPasMmu: supportRmeAndPasMmu,
          ogWidth: ogWidth,
          tlBlockWidth: tlBlockWidth,
          useIdent: useIdent,
        ),
        vcCount: vcCount,
        userMixInEnable: userMixInEnable,
        idMixInEnable: idMixInEnable,
        debugMixInEnable: debugMixInEnable,
        mmuMixInEnable: mmuMixInEnable,
      );
}

/// A config object for constructing an LTI LR channel.
class LtiLrChannelConfig {
  /// The width of the user-defined signal in bits.
  final int userWidth;

  /// The width of the ID signal in bits.
  final int idWidth;

  /// The width of the address bus in bits.
  final int addrWidth;

  /// Realm Management Extension support.
  final bool rmeSupport;

  /// Inst/priv support.
  final bool instPrivPresent;

  /// The width of PAS signal in bits.
  final int pasWidth;

  /// Loopback signal width.
  final int loopWidth;

  /// MECID WIDTH.
  final int mecIdWidth;

  /// MPAM width.
  final int mpamWidth;

  /// CTAG width.
  final int ctagWidth;

  /// Constructor.
  LtiLrChannelConfig({
    this.userWidth = 0,
    this.idWidth = 0,
    this.addrWidth = 0,
    this.rmeSupport = false,
    this.instPrivPresent = false,
    this.pasWidth = 0,
    this.loopWidth = 0,
    this.mecIdWidth = 0,
    this.mpamWidth = 0,
    this.ctagWidth = 1,
  });

  /// Creates a copy of this config.
  LtiLrChannelConfig clone() => LtiLrChannelConfig(
        userWidth: userWidth,
        idWidth: idWidth,
        addrWidth: addrWidth,
        rmeSupport: rmeSupport,
        instPrivPresent: instPrivPresent,
        pasWidth: pasWidth,
        loopWidth: loopWidth,
        mecIdWidth: mecIdWidth,
        mpamWidth: mpamWidth,
        ctagWidth: ctagWidth,
      );
}

/// Basis for all possible LR channels.
///
/// TODO: numRp vs. VC?
class LtiLrChannelInterface extends LtiTransportInterface
    with
        Axi5UserSignals,
        Axi5IdSignals,
        Axi5ProtSignals,
        Axi5DebugSignals,
        Axi5ResponseSignals {
  /// Enable ID signal mixin
  final bool idMixInEnable;

  /// Enable Debug signal mixin
  final bool debugMixInEnable;

  /// Enable User signal mixin
  final bool userMixInEnable;

  @override
  final int userWidth;
  @override
  final int idWidth;
  @override
  final bool useIdUnq;
  @override
  final int protWidth;
  @override
  final bool rmeSupport;
  @override
  final bool instPrivPresent;
  @override
  final int pasWidth;
  @override
  final bool tracePresent;
  @override
  final int loopWidth;
  @override
  final int respWidth;
  @override
  final bool useBusy;

  /// Address width.
  final int addrWidth;

  /// CTAG width.
  final int ctagWidth;

  /// MECID WIDTH.
  final int mecIdWidth;

  /// MPAM width.
  final int mpamWidth;

  /// Address.
  ///
  /// Width is equal to [addrWidth].
  Logic get addr => port('${prefix}ADDR');

  /// CTAG.
  ///
  /// Width is equal to [ctagWidth].
  Logic get ctag => port('${prefix}CTAG');

  /// Attr.
  ///
  /// Width is equal to 4.
  Logic get attr => port('${prefix}ATTR');

  /// HW Attr.
  ///
  /// Width is equal to 4.
  Logic get hwAttr => port('${prefix}HWATTR');

  /// MPAM.
  ///
  /// Width is equal to [mpamWidth].
  Logic? get mpam => tryPort('${prefix}MPAM');

  /// MECID.
  ///
  /// Width is equal to [mecIdWidth].
  Logic? get mecId => tryPort('${prefix}MECID');

  /// SIZE.
  ///
  /// Width is equal to 6.
  Logic get size => port('${prefix}SIZE');

  /// Constructor.
  LtiLrChannelInterface({
    required LtiLrChannelConfig config,
    super.vcCount = 1,
    this.debugMixInEnable = false,
    this.idMixInEnable = false,
    this.userMixInEnable = false,
  })  : userWidth = config.userWidth,
        idWidth = config.idWidth,
        useIdUnq = false,
        addrWidth = config.addrWidth,
        protWidth = 0,
        rmeSupport = config.rmeSupport,
        instPrivPresent = config.instPrivPresent,
        pasWidth = config.pasWidth,
        loopWidth = config.loopWidth,
        tracePresent = false,
        respWidth = 3,
        useBusy = false,
        mpamWidth = config.mpamWidth,
        mecIdWidth = config.mecIdWidth,
        ctagWidth = config.ctagWidth,
        super(
          prefix: 'LR',
          main: false,
        ) {
    setPorts([
      Logic.port('${prefix}ADDR', addrWidth),
      Logic.port('${prefix}CTAG', ctagWidth),
      Logic.port('${prefix}ATTR', 4),
      Logic.port('${prefix}HWATTR', 4),
      if (mpamWidth > 0) Logic.port('${prefix}MPAM', mpamWidth),
      if (mecIdWidth > 0) Logic.port('${prefix}MECID', mecIdWidth),
      Logic.port('${prefix}SIZE', 6),
    ], [
      PairDirection.fromConsumer,
    ]);
    makeResponsePorts();
    makeProtPorts();
    if (userMixInEnable) {
      makeUserPorts();
    }
    if (idMixInEnable) {
      makeIdPorts();
    }
    if (debugMixInEnable) {
      makeDebugPorts();
    }
  }

  /// Copy Constructor.
  @override
  LtiLrChannelInterface clone() => LtiLrChannelInterface(
        config: LtiLrChannelConfig(
          userWidth: userWidth,
          idWidth: idWidth,
          loopWidth: loopWidth,
          addrWidth: addrWidth,
          rmeSupport: rmeSupport,
          instPrivPresent: instPrivPresent,
          pasWidth: pasWidth,
          mecIdWidth: mecIdWidth,
          mpamWidth: mpamWidth,
          ctagWidth: ctagWidth,
        ),
        vcCount: vcCount,
        userMixInEnable: userMixInEnable,
        idMixInEnable: idMixInEnable,
        debugMixInEnable: debugMixInEnable,
      );
}

/// A config object for constructing an LTI LC channel.
class LtiLcChannelConfig {
  /// The width of the user-defined signal in bits.
  final int userWidth;

  /// The width of the tag.
  final int tagWidth;

  /// Constructor.
  LtiLcChannelConfig({
    this.userWidth = 0,
    this.tagWidth = 0,
  });

  /// Creates a copy of this config.
  LtiLcChannelConfig clone() => LtiLcChannelConfig(
        userWidth: userWidth,
        tagWidth: tagWidth,
      );
}

/// Basis for all possible LC channels.
class LtiLcChannelInterface extends LtiTransportInterface with Axi5UserSignals {
  /// Enable User signal mixin
  final bool userMixInEnable;

  @override
  final int userWidth;

  /// Tag width.
  final int tagWidth;

  /// CTAG.
  ///
  /// Width is equal to [tagWidth].
  Logic get ctag => port('${prefix}CTAG');

  /// Constructor.
  LtiLcChannelInterface({
    required LtiLcChannelConfig config,
    this.userMixInEnable = false,
  })  : userWidth = config.userWidth,
        tagWidth = config.tagWidth,
        super(
          prefix: 'LC',
          main: true,
          vcCount: 1,
        ) {
    setPorts([
      Logic.port('${prefix}CTAG', tagWidth),
    ], [
      PairDirection.fromProvider,
    ]);
    if (userMixInEnable) {
      makeUserPorts();
    }
  }

  /// Copy Constructor.
  @override
  LtiLcChannelInterface clone() => LtiLcChannelInterface(
        config: LtiLcChannelConfig(
          userWidth: userWidth,
          tagWidth: tagWidth,
        ),
        userMixInEnable: userMixInEnable,
      );
}

/// A config object for constructing an LTI LT channel.
class LtiLtChannelConfig {
  /// The width of the user-defined signal in bits.
  final int userWidth;

  /// The width of the tag.
  final int tagWidth;

  /// Constructor.
  LtiLtChannelConfig({
    this.userWidth = 0,
    this.tagWidth = 0,
  });

  /// Creates a copy of this config.
  LtiLtChannelConfig clone() => LtiLtChannelConfig(
        userWidth: userWidth,
        tagWidth: tagWidth,
      );
}

/// Basis for all possible LT channels.
class LtiLtChannelInterface extends LtiTransportInterface with Axi5UserSignals {
  /// Enable User signal mixin
  final bool userMixInEnable;

  @override
  final int userWidth;

  /// Tag width.
  final int tagWidth;

  /// CTAG.
  ///
  /// Width is equal to [tagWidth].
  Logic get ctag => port('${prefix}CTAG');

  /// Constructor.
  LtiLtChannelInterface({
    required LtiLcChannelConfig config,
    this.userMixInEnable = false,
  })  : userWidth = config.userWidth,
        tagWidth = config.tagWidth,
        super(
          prefix: 'LT',
          main: false,
          vcCount: 1,
        ) {
    setPorts([
      Logic.port('${prefix}CTAG', tagWidth),
    ], [
      PairDirection.fromConsumer,
    ]);
    if (userMixInEnable) {
      makeUserPorts();
    }
  }

  /// Copy Constructor.
  @override
  LtiLtChannelInterface clone() => LtiLtChannelInterface(
        config: LtiLcChannelConfig(
          userWidth: userWidth,
          tagWidth: tagWidth,
        ),
        userMixInEnable: userMixInEnable,
      );
}

/// LTI Management signals.
class LtiManagementInterface extends PairInterface {
  /// Open request.
  Logic get openReq => port('LMOPENREQ');

  /// Open ack.
  Logic get openAck => port('LMOPENACK');

  /// Active.
  Logic get active => port('LMACTIVE');

  /// Close request.
  Logic get askClose => port('LMASKCLOSE');

  /// Construct a new instance of an Axi5 interface.
  ///
  /// TODO: directionality right??
  LtiManagementInterface() {
    setPorts([
      Logic.port('LMOPENREQ'),
      Logic.port('LMOPENACK'),
      Logic.port('LMACTIVE'),
      Logic.port('LMASKCLOSE'),
    ], [
      PairDirection.sharedInputs,
    ]);
  }

  /// Constructs a new [LtiManagementInterface] with identical parameters.
  @override
  LtiManagementInterface clone() => LtiManagementInterface();
}

/// Grouping of all channels.
class LtiCluster extends PairInterface {
  /// LA channel.
  late final LtiLaChannelInterface la;

  /// LR channel.
  late final LtiLrChannelInterface lr;

  /// LC channel.
  late final LtiLcChannelInterface lc;

  /// LT channel.
  late final LtiLtChannelInterface? lt;

  /// Constructor.
  LtiCluster({required this.la, required this.lr, required this.lc, this.lt}) {
    addSubInterface('LA', la);
    addSubInterface('LR', lr);
    addSubInterface('LC', lc);
    if (lt != null) {
      addSubInterface('LT', lt!);
    }
  }

  /// Copy constructor.
  @override
  LtiCluster clone() => LtiCluster(
        la: la.clone(),
        lr: lr.clone(),
        lc: lc.clone(),
        lt: lt?.clone(),
      );
}

/// Helper to enumerate the encodings of the LRRESP signal.
enum LtiRespField {
  /// The translation was successful.
  success(0x0),

  /// The translation was successful but the transaction type must be
  /// downgraded. The meaning of this for each transaction type is described in
  /// B5.2.2 Downgrade types.
  downgrade1(0x1),

  /// The translation was successful but the transaction type must be
  /// downgraded. The meaning of this for each transaction type is described in
  /// B5.2.2 Downgrade types.
  downgrade2(0x2),

  /// The translation was not successful and the transaction must be terminated.
  /// The Manager should indicate to the upstream device that the transaction
  /// was not successful.
  faultAbort(0x4),

  /// The translation was not successful and the transaction must be terminated.
  /// If possible, the LTI Manager should indicate to the Requester that the
  /// transaction was successful, by returning 0 if the data was a read, and
  /// ignoring the transaction if it was a write. Cache maintenance and prefetch
  /// effects of the transaction are ignored.
  terminateRazwi(0x5),

  /// The translation was not successful but it might be resolved by issuing a
  /// PRI request. The Manager should issue a PRI request, and if the response
  /// from that indicates success, retry the LTI request. For more information,
  /// see B1.4.4 PRI flow.
  faultPri(0x6);

  /// Underlying value.
  final int value;

  const LtiRespField(this.value);
}
