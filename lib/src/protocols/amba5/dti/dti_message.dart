import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Downstream message protocol encodings.
enum DtiDownstreamMsgType {
  /// Connection and disconnection.
  condisReq(0x0),

  /// Translation request.
  transReq(0x2),

  /// Invalidation ack.
  invAck(0x4),

  /// Synchronization ack.
  syncAck(0x5),

  /// Register write ack.
  regWAck(0x6),

  /// Register read data.
  regRData(0x7);

  /// Underlying value.
  final int value;

  const DtiDownstreamMsgType(this.value);
}

/// Downstream message protocol encodings.
enum DtiUpstreamMsgType {
  /// Connection and disconnection.
  condisAck(0x0),

  /// Translation fault.
  transFault(0x1),

  /// Translation response.
  transResp(0x2),

  /// Translation extended response.
  transRespEx(0x3),

  /// Invalidation request.
  invReq(0x4),

  /// Synchronization request.
  syncReq(0x5),

  /// Register write.
  regWr(0x6),

  /// Register read.
  regRd(0x7);

  /// Underlying value.
  final int value;

  const DtiUpstreamMsgType(this.value);
}

/// Translation request.
class DtiTbuTransReq extends LogicStructure {
  /// Width of msgType field
  static const int msgTypeWidth = 4;

  /// Width of qos field
  static const int qosWidth = 4;

  /// Width of translationId1 field
  static const int translationId1Width = 8;

  /// Width of protocol field
  static const int protocolWidth = 1;

  /// Width of priv field
  static const int privWidth = 1;

  /// Width of inst field
  static const int instWidth = 1;

  /// Width of perm1 field
  static const int perm1Width = 1;

  /// Width of secSid1 field
  static const int secSid1Width = 1;

  /// Width of ssv field
  static const int ssvWidth = 1;

  /// Width of flow1 field
  static const int flow1Width = 1;

  /// Width of perm2 field
  static const int perm2Width = 1;

  /// Width of pas1 field
  static const int pas1Width = 2;

  /// Width of secSid2 field
  static const int secSid2Width = 1;

  /// Width of ident field
  static const int identWidth = 1;

  /// Width of translationId2 field
  static const int translationId2Width = 4;

  /// Width of sid field
  static const int sidWidth = 24;

  /// Width of pasunknown field
  static const int pasunknownWidth = 1;

  /// Width of pas2 field
  static const int pas2Width = 1;

  /// Width of reqex field
  static const int reqexWidth = 1;

  /// Width of rsvd field
  static const int rsvdWidth = 2;

  /// Width of mmuv field
  static const int mmuvWidth = 1;

  /// Width of pm field
  static const int pmWidth = 1;

  /// Width of flow2 field
  static const int flow2Width = 1;

  /// Width of impDef field
  static const int impDefWidth = 1;

  /// Width of ssid field
  static const int ssidWidth = 20;

  /// Width of addr field
  static const int addrWidth = 64;

  /// Width of full translationId
  static const int translationIdWidth =
      translationId1Width + translationId2Width;

  /// Width of full perm
  static const int permWidth = perm1Width + perm2Width;

  /// Width of full secSid
  static const int secSidWidth = secSid1Width + secSid2Width;

  /// Width of full flow
  static const int flowWidth = flow1Width + flow2Width;

  /// Width of full pas
  static const int pasWidth = pas1Width + pas2Width;

  /// Total width of DtiTbuTransReq
  static const int totalWidth = msgTypeWidth +
      qosWidth +
      translationIdWidth +
      protocolWidth +
      privWidth +
      instWidth +
      permWidth +
      secSidWidth +
      ssvWidth +
      flowWidth +
      pasWidth +
      identWidth +
      sidWidth +
      pasunknownWidth +
      reqexWidth +
      rsvdWidth +
      mmuvWidth +
      pmWidth +
      impDefWidth +
      ssidWidth +
      addrWidth;

  /// msgType
  final Logic msgType;

  /// qos
  final Logic qos;

  /// translationId1
  final Logic translationId1;

  /// protocol
  final Logic protocol;

  /// priv
  final Logic priv;

  /// inst
  final Logic inst;

  /// perm1
  final Logic perm1;

  /// secSid1
  final Logic secSid1;

  /// ssv
  final Logic ssv;

  /// flow1
  final Logic flow1;

  /// perm2
  final Logic perm2;

  /// pas1
  final Logic pas1;

  /// secSid2
  final Logic secSid2;

  /// ident
  final Logic ident;

  /// translationId2
  final Logic translationId2;

  /// sid
  final Logic sid;

  /// pasunknown
  final Logic pasunknown;

  /// pas2
  final Logic pas2;

  /// reqex
  final Logic reqex;

  /// rsvd
  final Logic rsvd;

  /// mmuv
  final Logic mmuv;

  /// pm
  final Logic pm;

  /// flow2
  final Logic flow2;

  /// impDef
  final Logic impDef;

  /// ssid
  final Logic ssid;

  /// addr
  // TODO(mkorbel1): why is this addr 64 bits if bottom 12 bits are always 0?
  final Logic addr;

  /// full translation ID
  Logic get translationId => [translationId2, translationId1].swizzle();

  /// perm
  Logic get perm => [perm2, perm1].swizzle();

  /// secSid
  Logic get secSid => [secSid2, secSid1].swizzle();

  /// flow
  Logic get flow => [flow2, flow1].swizzle();

  /// pas
  Logic get pas => [pas2, pas1].swizzle();

  /// Base constructor.
  DtiTbuTransReq._({
    required this.msgType,
    required this.qos,
    required this.translationId1,
    required this.protocol,
    required this.priv,
    required this.inst,
    required this.perm1,
    required this.secSid1,
    required this.ssv,
    required this.flow1,
    required this.perm2,
    required this.pas1,
    required this.secSid2,
    required this.ident,
    required this.translationId2,
    required this.sid,
    required this.pasunknown,
    required this.pas2,
    required this.reqex,
    required this.mmuv,
    required this.pm,
    required this.flow2,
    required this.impDef,
    required this.ssid,
    required this.addr,
    required this.rsvd,
    super.name = 'dtiTbuTransReq',
  }) : super([
          msgType,
          qos,
          translationId1,
          protocol,
          priv,
          inst,
          perm1,
          secSid1,
          ssv,
          flow1,
          perm2,
          pas1,
          secSid2,
          ident,
          translationId2,
          sid,
          pasunknown,
          pas2,
          reqex,
          rsvd,
          mmuv,
          pm,
          flow2,
          impDef,
          ssid,
          addr,
        ]);

  /// Factory constructor.
  factory DtiTbuTransReq({String? name}) => DtiTbuTransReq._(
        msgType: Logic(name: '${name}_msgType', width: msgTypeWidth),
        qos: Logic(name: '${name}_qos', width: qosWidth),
        translationId1: Logic(
          name: '${name}_translationId1',
          width: translationId1Width,
        ),
        protocol: Logic(name: '${name}_protocol', width: protocolWidth),
        priv: Logic(name: '${name}_priv', width: privWidth),
        inst: Logic(name: '${name}_inst', width: instWidth),
        perm1: Logic(name: '${name}_perm1', width: perm1Width),
        secSid1: Logic(name: '${name}_secSid1', width: secSid1Width),
        ssv: Logic(name: '${name}_ssv', width: ssvWidth),
        flow1: Logic(name: '${name}_flow1', width: flow1Width),
        perm2: Logic(name: '${name}_perm2', width: perm2Width),
        pas1: Logic(name: '${name}_pas1', width: pas1Width),
        secSid2: Logic(name: '${name}_secSid2', width: secSid2Width),
        ident: Logic(name: '${name}_ident', width: identWidth),
        translationId2: Logic(
          name: '${name}_translationId2',
          width: translationId2Width,
        ),
        sid: Logic(name: '${name}_sid', width: sidWidth),
        pasunknown: Logic(name: '${name}_pasunknown', width: pasunknownWidth),
        pas2: Logic(name: '${name}_pas2', width: pas2Width),
        reqex: Logic(name: '${name}_reqex', width: reqexWidth),
        rsvd: Logic(name: '${name}_rsvd', width: rsvdWidth),
        mmuv: Logic(name: '${name}_mmuv', width: mmuvWidth),
        pm: Logic(name: '${name}_pm', width: pmWidth),
        flow2: Logic(name: '${name}_flow2', width: flow2Width),
        impDef: Logic(name: '${name}_impDef', width: impDefWidth),
        ssid: Logic(name: '${name}_ssid', width: ssidWidth),
        addr: Logic(name: '${name}_addr', width: addrWidth),
        name: name,
      );

  /// Copy constructor.
  @override
  DtiTbuTransReq clone({String? name}) => DtiTbuTransReq._(
        msgType: msgType.clone(),
        qos: qos.clone(),
        translationId1: translationId1.clone(),
        protocol: protocol.clone(),
        priv: priv.clone(),
        inst: inst.clone(),
        perm1: perm1.clone(),
        secSid1: secSid1.clone(),
        ssv: ssv.clone(),
        flow1: flow1.clone(),
        perm2: perm2.clone(),
        pas1: pas1.clone(),
        secSid2: secSid2.clone(),
        ident: ident.clone(),
        translationId2: translationId2.clone(),
        sid: sid.clone(),
        pasunknown: pasunknown.clone(),
        pas2: pas2.clone(),
        reqex: reqex.clone(),
        rsvd: rsvd.clone(),
        mmuv: mmuv.clone(),
        pm: pm.clone(),
        flow2: flow2.clone(),
        impDef: impDef.clone(),
        ssid: ssid.clone(),
        addr: addr.clone(),
        name: name ?? this.name,
      );

  /// Generator from an AwChannel packet.
  void fromAxiAwPacket({
    required Axi5AwChannelPacket packet,
    required int translationId,
  }) {
    msgType.put(DtiDownstreamMsgType.transReq.value);
    qos.put(packet.request.qos ?? 0);
    translationId1.put(translationId & 0xff);
    protocol.put(0); // must be 0 for DTI-TBU
    priv.put((packet.prot.prot ?? 0) & 0x1); // prot[0]
    inst.put(((packet.prot.prot ?? 0) >>> 2) & 0x1); // prot[2]
    perm1.put(0x0); // write permission, no matter what LSB=0
    secSid1.put((packet.mmu?.mmuSecSid ?? 0) & 0x1);
    ssv.put(packet.mmu?.mmuSsidV ?? 0);
    flow1.put((packet.mmu?.mmuFlow ?? 0) & 0x1);
    perm2.put(
      (packet.atomic?.atOp ?? 0x0) == 0x0 ? 0x0 : 0x1,
    ); // write permission, possibly atomic write/read
    pas1.put(0x0);
    secSid2.put((packet.mmu?.mmuSecSid ?? 0) >>> 1);
    ident.put(0x0);
    translationId2.put(translationId >>> 8);
    sid.put(packet.mmu?.mmuSid ?? 0);
    pasunknown.put(0x0);
    pas2.put(0x0);
    reqex.put(0x1);
    rsvd.put(0);
    mmuv.put(packet.mmu?.mmuValid ?? 0);
    pm.put(0x0);
    flow2.put((packet.mmu?.mmuFlow ?? 0) >>> 1);
    impDef.put(0x0);
    ssid.put(packet.mmu?.mmuSsid ?? 0);
    addr.put(packet.request.addr);
  }

  // TODO(kimmeljo): these fromAxi do not properly handle priv, inst, etc. and need to be remapped (hardware too!)

  /// Generator from an ArChannel packet.
  void fromAxiArPacket({
    required Axi5ArChannelPacket packet,
    required int translationId,
  }) {
    msgType.put(DtiDownstreamMsgType.transReq.value);
    qos.put(packet.request.qos ?? 0);
    translationId1.put(translationId & 0xff);
    protocol.put(0); // must be 0 for DTI-TBU
    priv.put((packet.prot.prot ?? 0) & 0x1); // prot[0]
    inst.put(((packet.prot.prot ?? 0) >>> 2) & 0x1); // prot[2]
    perm1.put(0x1); // read permission
    secSid1.put((packet.mmu?.mmuSecSid ?? 0) & 0x1);
    ssv.put(packet.mmu?.mmuSsidV ?? 0);
    flow1.put((packet.mmu?.mmuFlow ?? 0) & 0x1);
    perm2.put(0x0); // read permission
    pas1.put(0x0);
    secSid2.put((packet.mmu?.mmuSecSid ?? 0) >>> 1);
    ident.put(0x0);
    translationId2.put(translationId >>> 8);
    sid.put(packet.mmu?.mmuSid ?? 0);
    pasunknown.put(0x0);
    pas2.put(0x0);
    reqex.put(0x1);
    rsvd.put(0);
    mmuv.put(packet.mmu?.mmuValid ?? 0);
    pm.put(0x0);
    flow2.put((packet.mmu?.mmuFlow ?? 0) >>> 1);
    impDef.put(0x0);
    ssid.put(packet.mmu?.mmuSsid ?? 0);
    addr.put(packet.request.addr);
  }

  /// Generator from an LtiLaChannel packet.
  void fromLtiPacket({
    required LtiLaChannelPacket packet,
    required int translationId,
  }) {
    // derive PERM from LATRANS
    var mPerm = 0x1; // read
    if (packet.trans == 2) {
      mPerm = 0x0; // write
    } else if (packet.trans == 3) {
      mPerm = 0x2; // atomic write/read
    }

    msgType.put(DtiDownstreamMsgType.transReq.value);
    qos.put(0);
    translationId1.put(translationId & 0xff);
    protocol.put(0); // must be 0 for DTI-TBU
    priv.put(packet.prot?.priv ?? 0);
    inst.put(packet.prot?.inst ?? 0);
    perm1.put(mPerm & 0x1);
    secSid1.put((packet.mmu?.mmuSecSid ?? 0) & 0x1);
    ssv.put(packet.mmu?.mmuSsidV ?? 0);
    flow1.put((packet.mmu?.mmuFlow ?? 0) & 0x1);
    perm2.put(mPerm >>> 1);
    pas1.put((packet.prot?.pas ?? 0) & 0x3);
    secSid2.put((packet.mmu?.mmuSecSid ?? 0) >>> 1);
    ident.put(packet.ident ?? 0);
    translationId2.put(translationId >>> 8);
    sid.put(packet.mmu?.mmuSid ?? 0);
    pasunknown.put(packet.mmu?.mmuPasUnknown ?? 0);
    pas2.put((packet.prot?.pas ?? 0) >>> 2);
    reqex.put(1);
    rsvd.put(0);
    mmuv.put(packet.mmu?.mmuValid ?? 0);
    pm.put(packet.mmu?.mmuPm ?? 0);
    flow2.put((packet.mmu?.mmuFlow ?? 0) >>> 1);
    impDef.put(0);
    ssid.put(packet.mmu?.mmuSsid ?? 0);
    addr.put(packet.addr);
  }

  /// Helper to zero init all fields
  void zeroInit() {
    msgType.put(DtiDownstreamMsgType.transReq.value);
    qos.put(0);
    translationId1.put(0);
    protocol.put(0);
    priv.put(0);
    inst.put(0);
    perm1.put(0);
    secSid1.put(0);
    ssv.put(0);
    flow1.put(0);
    perm2.put(0);
    pas1.put(0);
    secSid2.put(0);
    ident.put(0);
    translationId2.put(0);
    sid.put(0);
    pasunknown.put(0);
    pas2.put(0);
    reqex.put(0);
    rsvd.put(0);
    mmuv.put(0);
    pm.put(0);
    flow2.put(0);
    impDef.put(0);
    ssid.put(0);
    addr.put(0);
  }
}

abstract class DtiTbuTransRespBase extends LogicStructure {
  /// Width of msgType field
  static const int msgTypeWidth = 4;

  /// Width of translationId1 field
  static const int translationId1Width = 8;

  /// Width of translationId2 field
  static const int translationId2Width = 4;

  /// Width of full translationId
  static const int translationIdWidth =
      translationId1Width + translationId2Width;

  /// msgType
  Logic get msgType;

  /// translationId1
  Logic get translationId1;

  /// translationId2
  Logic get translationId2;

  /// full translation ID
  Logic get translationId => [translationId2, translationId1].swizzle();

  /// Base constructor.
  DtiTbuTransRespBase(super.elements, {super.name = 'dtiTbuTransRespBase'});
}

/// Successful Translation response.
class DtiTbuTransResp extends DtiTbuTransRespBase {
  /// Width of msgType field
  static const int msgTypeWidth = 4;

  /// Width of translationId1 field
  static const int translationId1Width = 8;

  /// Width of cont field
  static const int contWidth = 4;

  /// Width of doNotCache field
  static const int doNotCacheWidth = 1;

  /// Width of bypass field
  static const int bypassWidth = 1;

  /// Width of strwOrBpType field
  static const int strwOrBpTypeWidth = 2;

  /// Width of dre field
  static const int dreWidth = 1;

  /// Width of dcp field
  static const int dcpWidth = 1;

  /// Width of privCfg field
  static const int privCfgWidth = 2;

  /// Width of instCfg field
  static const int instCfgWidth = 2;

  /// Width of aset field
  static const int asetWidth = 1;

  /// Width of combMt field
  static const int combMtWidth = 1;

  /// Width of allocCfg field
  static const int allocCfgWidth = 4;

  /// Width of vmid field
  static const int vmidWidth = 16;

  /// Width of asidOrAttrOvrd field
  static const int asidOrAttrOvrdWidth = 16;

  /// Width of allowUr field
  static const int allowUrWidth = 1;

  /// Width of allowUw field
  static const int allowUwWidth = 1;

  /// Width of allowUx field
  static const int allowUxWidth = 1;

  /// Width of allowPr field
  static const int allowPrWidth = 1;

  /// Width of allowPw field
  static const int allowPwWidth = 1;

  /// Width of allowPxOrNsx field
  static const int allowPxOrNsxWidth = 1;

  /// Width of pas1 field
  static const int pas1Width = 1;

  /// Width of tbi field
  static const int tbiWidth = 1;

  /// Width of global field
  static const int globalWidth = 1;

  /// Width of mpamns field
  static const int mpamnsWidth = 1;

  /// Width of combSh field
  static const int combShWidth = 1;

  /// Width of combAlloc field
  static const int combAllocWidth = 1;

  /// Width of translationId2 field
  static const int translationId2Width = 4;

  /// Width of transRng field
  static const int transRngWidth = 4;

  /// Width of invalRng field
  static const int invalRngWidth = 4;

  /// Width of pas2 field
  static const int pas2Width = 1;

  /// Width of mpamNse field
  static const int mpamNseWidth = 1;

  /// Width of pas3 field
  static const int pas3Width = 1;

  /// Width of partId1 field
  static const int partId1Width = 1;

  /// Width of hwAttr field
  static const int hwAttrWidth = 4;

  /// Width of attr field
  static const int attrWidth = 8;

  /// Width of sh field
  static const int shWidth = 2;

  /// Width of pmg field
  static const int pmgWidth = 1;

  /// Width of partId2 field
  static const int partId2Width = 1;

  /// Width of addr field
  static const int addrWidth = 52;

  /// Width of partId3 field
  static const int partId3Width = 4;

  /// Width of partId4 field
  static const int partId4Width = 4;

  /// Width of impDef field
  static const int impDefWidth = 4;

  /// Width of full translationId
  static const int translationIdWidth =
      translationId1Width + translationId2Width;

  /// Width of full pas
  static const int pasWidth = pas1Width + pas2Width + pas3Width;

  /// Width of full partId
  static const int partIdWidth =
      partId1Width + partId2Width + partId3Width + partId4Width;

  /// Total width of DtiTbuTransResp
  static const int totalWidth = msgTypeWidth +
      translationIdWidth +
      contWidth +
      doNotCacheWidth +
      bypassWidth +
      strwOrBpTypeWidth +
      dreWidth +
      dcpWidth +
      privCfgWidth +
      instCfgWidth +
      asetWidth +
      combMtWidth +
      allocCfgWidth +
      vmidWidth +
      asidOrAttrOvrdWidth +
      allowUrWidth +
      allowUwWidth +
      allowUxWidth +
      allowPrWidth +
      allowPwWidth +
      allowPxOrNsxWidth +
      pasWidth +
      tbiWidth +
      globalWidth +
      mpamnsWidth +
      combShWidth +
      combAllocWidth +
      transRngWidth +
      invalRngWidth +
      mpamNseWidth +
      partIdWidth +
      hwAttrWidth +
      attrWidth +
      shWidth +
      pmgWidth +
      addrWidth +
      impDefWidth;

  /// msgType
  final Logic msgType;

  /// translationId1
  final Logic translationId1;

  /// cont
  final Logic cont;

  /// doNotCache
  final Logic doNotCache;

  /// bypass
  final Logic bypass;

  /// strwOrBpType
  final Logic strwOrBpType;

  /// dre
  final Logic dre;

  /// dcp
  final Logic dcp;

  /// privCfg
  final Logic privCfg;

  /// instCfg
  final Logic instCfg;

  /// aset
  final Logic aset;

  /// combMt
  final Logic combMt;

  /// allocCfg
  final Logic allocCfg;

  /// vmid
  final Logic vmid;

  /// asidOrAttrOvrd
  final Logic asidOrAttrOvrd;

  /// allowUr
  final Logic allowUr;

  /// allowUw
  final Logic allowUw;

  /// allowUx
  final Logic allowUx;

  /// allowPr
  final Logic allowPr;

  /// allowPw
  final Logic allowPw;

  /// allowPxOrNsx
  final Logic allowPxOrNsx;

  /// pas1
  final Logic pas1;

  /// tbi
  final Logic tbi;

  /// global
  final Logic global;

  /// mpamns
  final Logic mpamns;

  /// combSh
  final Logic combSh;

  /// combAlloc
  final Logic combAlloc;

  /// translationId2
  final Logic translationId2;

  /// transRng
  final Logic transRng;

  /// invalRng
  final Logic invalRng;

  /// pas2
  final Logic pas2;

  /// mpamNse
  final Logic mpamNse;

  /// pas3
  final Logic pas3;

  /// partId1
  final Logic partId1;

  /// hwAttr
  final Logic hwAttr;

  /// attr
  final Logic attr;

  /// sh
  final Logic sh;

  /// pmg
  final Logic pmg;

  /// partId2
  final Logic partId2;

  /// The translated address bits [51:12] (NOT the full address), corresponds to
  /// `oa` in the DTI spec.  This is like the page address, for 4KB pages.
  final Logic oa;

  /// partId3
  final Logic partId3;

  /// partId4
  final Logic partId4;

  /// impDef
  final Logic impDef;

  /// NC_ALLOC aliased within cont
  Logic get ncAlloc => cont[3];

  /// full translation ID
  Logic get translationId => [translationId2, translationId1].swizzle();

  /// full pas
  Logic get pas => [pas3, pas2, pas1].swizzle();

  /// full partId
  Logic get partId => [partId1, partId2, partId3, partId4].swizzle();

  /// Base constructor.
  DtiTbuTransResp({
    required this.msgType,
    required this.translationId1,
    required this.cont,
    required this.doNotCache,
    required this.bypass,
    required this.strwOrBpType,
    required this.dre,
    required this.dcp,
    required this.privCfg,
    required this.instCfg,
    required this.aset,
    required this.combMt,
    required this.allocCfg,
    required this.vmid,
    required this.asidOrAttrOvrd,
    required this.allowUr,
    required this.allowUw,
    required this.allowUx,
    required this.allowPr,
    required this.allowPw,
    required this.allowPxOrNsx,
    required this.pas1,
    required this.tbi,
    required this.global,
    required this.mpamns,
    required this.combSh,
    required this.combAlloc,
    required this.translationId2,
    required this.transRng,
    required this.invalRng,
    required this.pas2,
    required this.mpamNse,
    required this.pas3,
    required this.partId1,
    required this.hwAttr,
    required this.attr,
    required this.sh,
    required this.pmg,
    required this.partId2,
    required this.oa,
    required this.partId3,
    required this.partId4,
    required this.impDef,
    List<Logic> extended = const [],
    super.name = 'dtiTbuTransResp',
  }) : super([
          msgType,
          translationId1,
          cont,
          doNotCache,
          bypass,
          strwOrBpType,
          dre,
          dcp,
          privCfg,
          instCfg,
          aset,
          combMt,
          allocCfg,
          vmid,
          asidOrAttrOvrd,
          allowUr,
          allowUw,
          allowUx,
          allowPr,
          allowPw,
          allowPxOrNsx,
          pas1,
          tbi,
          global,
          mpamns,
          combSh,
          combAlloc,
          translationId2,
          transRng,
          invalRng,
          pas2,
          mpamNse,
          pas3,
          partId1,
          hwAttr,
          attr,
          sh,
          pmg,
          partId2,
          oa,
          partId3,
          partId4,
          impDef,
          ...extended,
        ]);

  /// Factory constructor.
  factory DtiTbuTransResp.empty([
    String name = 'trans_resp',
  ]) =>
      DtiTbuTransResp(
        msgType: Logic(name: '${name}_msgType', width: msgTypeWidth),
        translationId1: Logic(
          name: '${name}_translationId1',
          width: translationId1Width,
        ),
        cont: Logic(name: '${name}_cont', width: contWidth),
        doNotCache: Logic(name: '${name}_doNotCache', width: doNotCacheWidth),
        bypass: Logic(name: '${name}_bypass', width: bypassWidth),
        strwOrBpType:
            Logic(name: '${name}_strwOrBpType', width: strwOrBpTypeWidth),
        dre: Logic(name: '${name}_dre', width: dreWidth),
        dcp: Logic(name: '${name}_dcp', width: dcpWidth),
        privCfg: Logic(name: '${name}_privCfg', width: privCfgWidth),
        instCfg: Logic(name: '${name}_instCfg', width: instCfgWidth),
        aset: Logic(name: '${name}_aset', width: asetWidth),
        combMt: Logic(name: '${name}_combMt', width: combMtWidth),
        allocCfg: Logic(name: '${name}_allocCfg', width: allocCfgWidth),
        vmid: Logic(name: '${name}_vmid', width: vmidWidth),
        asidOrAttrOvrd: Logic(
          name: '${name}_asidOrAttrOvrd',
          width: asidOrAttrOvrdWidth,
        ),
        allowUr: Logic(name: '${name}_allowUr', width: allowUrWidth),
        allowUw: Logic(name: '${name}_allowUw', width: allowUwWidth),
        allowUx: Logic(name: '${name}_allowUx', width: allowUxWidth),
        allowPr: Logic(name: '${name}_allowPr', width: allowPrWidth),
        allowPw: Logic(name: '${name}_allowPw', width: allowPwWidth),
        allowPxOrNsx:
            Logic(name: '${name}_allowPxOrNsx', width: allowPxOrNsxWidth),
        pas1: Logic(name: '${name}_pas1', width: pas1Width),
        tbi: Logic(name: '${name}_tbi', width: tbiWidth),
        global: Logic(name: '${name}_global', width: globalWidth),
        mpamns: Logic(name: '${name}_mpamns', width: mpamnsWidth),
        combSh: Logic(name: '${name}_combSh', width: combShWidth),
        combAlloc: Logic(name: '${name}_combAlloc', width: combAllocWidth),
        translationId2: Logic(
          name: '${name}_translationId2',
          width: translationId2Width,
        ),
        transRng: Logic(name: '${name}_transRng', width: transRngWidth),
        invalRng: Logic(name: '${name}_invalRng', width: invalRngWidth),
        pas2: Logic(name: '${name}_pas2', width: pas2Width),
        mpamNse: Logic(name: '${name}_mpamNse', width: mpamNseWidth),
        pas3: Logic(name: '${name}_pas3', width: pas3Width),
        partId1: Logic(name: '${name}_partId1', width: partId1Width),
        hwAttr: Logic(name: '${name}_hwAttr', width: hwAttrWidth),
        attr: Logic(name: '${name}_attr', width: attrWidth),
        sh: Logic(name: '${name}_sh', width: shWidth),
        pmg: Logic(name: '${name}_pmg', width: pmgWidth),
        partId2: Logic(name: '${name}_partId2', width: partId2Width),
        oa: Logic(name: '${name}_addr', width: addrWidth),
        partId3: Logic(name: '${name}_partId3', width: partId3Width),
        partId4: Logic(name: '${name}_partId4', width: partId4Width),
        impDef: Logic(name: '${name}_impDef', width: impDefWidth),
        name: name,
      );

  /// Copy constructor.
  @override
  DtiTbuTransResp clone({String? name}) => DtiTbuTransResp(
        msgType: msgType.clone(),
        translationId1: translationId1.clone(),
        cont: cont.clone(),
        doNotCache: doNotCache.clone(),
        bypass: bypass.clone(),
        strwOrBpType: strwOrBpType.clone(),
        dre: dre.clone(),
        dcp: dcp.clone(),
        privCfg: privCfg.clone(),
        instCfg: instCfg.clone(),
        aset: aset.clone(),
        combMt: combMt.clone(),
        allocCfg: allocCfg.clone(),
        vmid: vmid.clone(),
        asidOrAttrOvrd: asidOrAttrOvrd.clone(),
        allowUr: allowUr.clone(),
        allowUw: allowUw.clone(),
        allowUx: allowUx.clone(),
        allowPr: allowPr.clone(),
        allowPw: allowPw.clone(),
        allowPxOrNsx: allowPxOrNsx.clone(),
        pas1: pas1.clone(),
        tbi: tbi.clone(),
        global: global.clone(),
        mpamns: mpamns.clone(),
        combSh: combSh.clone(),
        combAlloc: combAlloc.clone(),
        translationId2: translationId2.clone(),
        transRng: transRng.clone(),
        invalRng: invalRng.clone(),
        pas2: pas2.clone(),
        mpamNse: mpamNse.clone(),
        pas3: pas3.clone(),
        partId1: partId1.clone(),
        hwAttr: hwAttr.clone(),
        attr: attr.clone(),
        sh: sh.clone(),
        pmg: pmg.clone(),
        partId2: partId2.clone(),
        oa: oa.clone(),
        partId3: partId3.clone(),
        partId4: partId4.clone(),
        impDef: impDef.clone(),
        name: name ?? this.name,
      );

  /// Helper to zero init all fields
  void zeroInit() {
    msgType.put(DtiUpstreamMsgType.transResp.value);
    translationId1.put(0);
    cont.put(0);
    doNotCache.put(0);
    bypass.put(0);
    strwOrBpType.put(0);
    dre.put(0);
    dcp.put(0);
    privCfg.put(0);
    instCfg.put(0);
    aset.put(0);
    combMt.put(0);
    allocCfg.put(0);
    vmid.put(0);
    asidOrAttrOvrd.put(0);
    allowUr.put(0);
    allowUw.put(0);
    allowUx.put(0);
    allowPr.put(0);
    allowPw.put(0);
    allowPxOrNsx.put(0);
    pas1.put(0);
    tbi.put(0);
    global.put(0);
    mpamns.put(0);
    combSh.put(0);
    combAlloc.put(0);
    translationId2.put(0);
    transRng.put(0);
    invalRng.put(0);
    pas2.put(0);
    mpamNse.put(0);
    pas3.put(0);
    partId1.put(0);
    hwAttr.put(0);
    attr.put(0);
    sh.put(0);
    pmg.put(0);
    partId2.put(0);
    oa.put(0);
    partId3.put(0);
    partId4.put(0);
    impDef.put(0);
  }
}

/// Extended Successful Translation Response.
class DtiTbuTransRespEx extends DtiTbuTransResp {
  /// Width of mecId field
  static const int mecIdWidth = 16;

  /// Width of partId field
  static const int partId5Width = 2;

  /// Width of rsvd field
  static const int rsvdWidth = 14;

  /// Total width of DtiTbuTransRespEx
  static const int totalWidth =
      DtiTbuTransResp.totalWidth + mecIdWidth + partId5Width + rsvdWidth;

  /// mecId
  final Logic mecId;

  /// partId5
  final Logic partId5;

  /// rsvd
  final Logic rsvd;

  /// Base constructor.
  DtiTbuTransRespEx._({
    required super.msgType,
    required super.translationId1,
    required super.cont,
    required super.doNotCache,
    required super.bypass,
    required super.strwOrBpType,
    required super.dre,
    required super.dcp,
    required super.privCfg,
    required super.instCfg,
    required super.aset,
    required super.combMt,
    required super.allocCfg,
    required super.vmid,
    required super.asidOrAttrOvrd,
    required super.allowUr,
    required super.allowUw,
    required super.allowUx,
    required super.allowPr,
    required super.allowPw,
    required super.allowPxOrNsx,
    required super.pas1,
    required super.tbi,
    required super.global,
    required super.mpamns,
    required super.combSh,
    required super.combAlloc,
    required super.translationId2,
    required super.transRng,
    required super.invalRng,
    required super.pas2,
    required super.mpamNse,
    required super.pas3,
    required super.partId1,
    required super.hwAttr,
    required super.attr,
    required super.sh,
    required super.pmg,
    required super.partId2,
    required super.oa,
    required super.partId3,
    required super.partId4,
    required super.impDef,
    required this.mecId,
    required this.partId5,
    required this.rsvd,
    super.name = 'dtiTbuTransRespEx',
  }) : super(extended: [mecId, partId5, rsvd]);

  /// Factory constructor.
  factory DtiTbuTransRespEx([
    String name = 'trans_resp_ex',
  ]) =>
      DtiTbuTransRespEx._(
        msgType: Logic(
          name: '${name}_msgType',
          width: DtiTbuTransResp.msgTypeWidth,
        ),
        translationId1: Logic(
          name: '${name}_translationId1',
          width: DtiTbuTransResp.translationId1Width,
        ),
        cont: Logic(name: '${name}_cont', width: DtiTbuTransResp.contWidth),
        doNotCache: Logic(
          name: '${name}_doNotCache',
          width: DtiTbuTransResp.doNotCacheWidth,
        ),
        bypass:
            Logic(name: '${name}_bypass', width: DtiTbuTransResp.bypassWidth),
        strwOrBpType: Logic(
          name: '${name}_strwOrBpType',
          width: DtiTbuTransResp.strwOrBpTypeWidth,
        ),
        dre: Logic(name: '${name}_dre', width: DtiTbuTransResp.dreWidth),
        dcp: Logic(name: '${name}_dcp', width: DtiTbuTransResp.dcpWidth),
        privCfg: Logic(
          name: '${name}_privCfg',
          width: DtiTbuTransResp.privCfgWidth,
        ),
        instCfg: Logic(
          name: '${name}_instCfg',
          width: DtiTbuTransResp.instCfgWidth,
        ),
        aset: Logic(name: '${name}_aset', width: DtiTbuTransResp.asetWidth),
        combMt:
            Logic(name: '${name}_combMt', width: DtiTbuTransResp.combMtWidth),
        allocCfg: Logic(
          name: '${name}_allocCfg',
          width: DtiTbuTransResp.allocCfgWidth,
        ),
        vmid: Logic(name: '${name}_vmid', width: DtiTbuTransResp.vmidWidth),
        asidOrAttrOvrd: Logic(
          name: '${name}_asidOrAttrOvrd',
          width: DtiTbuTransResp.asidOrAttrOvrdWidth,
        ),
        allowUr: Logic(
          name: '${name}_allowUr',
          width: DtiTbuTransResp.allowUrWidth,
        ),
        allowUw: Logic(
          name: '${name}_allowUw',
          width: DtiTbuTransResp.allowUwWidth,
        ),
        allowUx: Logic(
          name: '${name}_allowUx',
          width: DtiTbuTransResp.allowUxWidth,
        ),
        allowPr: Logic(
          name: '${name}_allowPr',
          width: DtiTbuTransResp.allowPrWidth,
        ),
        allowPw: Logic(
          name: '${name}_allowPw',
          width: DtiTbuTransResp.allowPwWidth,
        ),
        allowPxOrNsx: Logic(
          name: '${name}_allowPxOrNsx',
          width: DtiTbuTransResp.allowPxOrNsxWidth,
        ),
        pas1: Logic(name: '${name}_pas1', width: DtiTbuTransResp.pas1Width),
        tbi: Logic(name: '${name}_tbi', width: DtiTbuTransResp.tbiWidth),
        global:
            Logic(name: '${name}_global', width: DtiTbuTransResp.globalWidth),
        mpamns:
            Logic(name: '${name}_mpamns', width: DtiTbuTransResp.mpamnsWidth),
        combSh:
            Logic(name: '${name}_combSh', width: DtiTbuTransResp.combShWidth),
        combAlloc: Logic(
          name: '${name}_combAlloc',
          width: DtiTbuTransResp.combAllocWidth,
        ),
        translationId2: Logic(
          name: '${name}_translationId2',
          width: DtiTbuTransResp.translationId2Width,
        ),
        transRng: Logic(
          name: '${name}_transRng',
          width: DtiTbuTransResp.transRngWidth,
        ),
        invalRng: Logic(
          name: '${name}_invalRng',
          width: DtiTbuTransResp.invalRngWidth,
        ),
        pas2: Logic(name: '${name}_pas2', width: DtiTbuTransResp.pas2Width),
        mpamNse: Logic(
          name: '${name}_mpamNse',
          width: DtiTbuTransResp.mpamNseWidth,
        ),
        pas3: Logic(name: '${name}_pas3', width: DtiTbuTransResp.pas3Width),
        partId1: Logic(
          name: '${name}_partId1',
          width: DtiTbuTransResp.partId1Width,
        ),
        hwAttr:
            Logic(name: '${name}_hwAttr', width: DtiTbuTransResp.hwAttrWidth),
        attr: Logic(name: '${name}_attr', width: DtiTbuTransResp.attrWidth),
        sh: Logic(name: '${name}_sh', width: DtiTbuTransResp.shWidth),
        pmg: Logic(name: '${name}_pmg', width: DtiTbuTransResp.pmgWidth),
        partId2: Logic(
          name: '${name}_partId2',
          width: DtiTbuTransResp.partId2Width,
        ),
        oa: Logic(name: '${name}_addr', width: DtiTbuTransResp.addrWidth),
        partId3: Logic(
          name: '${name}_partId3',
          width: DtiTbuTransResp.partId3Width,
        ),
        partId4: Logic(
          name: '${name}_partId4',
          width: DtiTbuTransResp.partId4Width,
        ),
        impDef:
            Logic(name: '${name}_impDef', width: DtiTbuTransResp.impDefWidth),
        mecId: Logic(name: '${name}_mecId', width: mecIdWidth),
        partId5: Logic(name: '${name}_partId5', width: partId5Width),
        rsvd: Logic(name: '${name}_rsvd', width: rsvdWidth),
        name: name,
      );

  /// Copy constructor.
  @override
  DtiTbuTransRespEx clone({String? name}) => DtiTbuTransRespEx._(
        msgType: msgType.clone(),
        translationId1: translationId1.clone(),
        cont: cont.clone(),
        doNotCache: doNotCache.clone(),
        bypass: bypass.clone(),
        strwOrBpType: strwOrBpType.clone(),
        dre: dre.clone(),
        dcp: dcp.clone(),
        privCfg: privCfg.clone(),
        instCfg: instCfg.clone(),
        aset: aset.clone(),
        combMt: combMt.clone(),
        allocCfg: allocCfg.clone(),
        vmid: vmid.clone(),
        asidOrAttrOvrd: asidOrAttrOvrd.clone(),
        allowUr: allowUr.clone(),
        allowUw: allowUw.clone(),
        allowUx: allowUx.clone(),
        allowPr: allowPr.clone(),
        allowPw: allowPw.clone(),
        allowPxOrNsx: allowPxOrNsx.clone(),
        pas1: pas1.clone(),
        tbi: tbi.clone(),
        global: global.clone(),
        mpamns: mpamns.clone(),
        combSh: combSh.clone(),
        combAlloc: combAlloc.clone(),
        translationId2: translationId2.clone(),
        transRng: transRng.clone(),
        invalRng: invalRng.clone(),
        pas2: pas2.clone(),
        mpamNse: mpamNse.clone(),
        pas3: pas3.clone(),
        partId1: partId1.clone(),
        hwAttr: hwAttr.clone(),
        attr: attr.clone(),
        sh: sh.clone(),
        pmg: pmg.clone(),
        partId2: partId2.clone(),
        oa: oa.clone(),
        partId3: partId3.clone(),
        partId4: partId4.clone(),
        impDef: impDef.clone(),
        mecId: mecId.clone(),
        partId5: partId5.clone(),
        rsvd: rsvd.clone(),
        name: name ?? this.name,
      );

  /// Helper to zero init all fields
  @override
  void zeroInit() {
    msgType.put(DtiUpstreamMsgType.transRespEx.value);
    translationId1.put(0);
    cont.put(0);
    doNotCache.put(0);
    bypass.put(0);
    strwOrBpType.put(0);
    dre.put(0);
    dcp.put(0);
    privCfg.put(0);
    instCfg.put(0);
    aset.put(0);
    combMt.put(0);
    allocCfg.put(0);
    vmid.put(0);
    asidOrAttrOvrd.put(0);
    allowUr.put(0);
    allowUw.put(0);
    allowUx.put(0);
    allowPr.put(0);
    allowPw.put(0);
    allowPxOrNsx.put(0);
    pas1.put(0);
    tbi.put(0);
    global.put(0);
    mpamns.put(0);
    combSh.put(0);
    combAlloc.put(0);
    translationId2.put(0);
    transRng.put(0);
    invalRng.put(0);
    pas2.put(0);
    mpamNse.put(0);
    pas3.put(0);
    partId1.put(0);
    hwAttr.put(0);
    attr.put(0);
    sh.put(0);
    pmg.put(0);
    partId2.put(0);
    oa.put(0);
    partId3.put(0);
    partId4.put(0);
    impDef.put(0);
    mecId.put(0);
    partId5.put(0);
    rsvd.put(0);
  }
}

/// Unsuccessful Translation Response.
class DtiTbuTransFault extends DtiTbuTransRespBase {
  /// Width of msgType field
  static const int msgTypeWidth = 4;

  /// Width of translationId1 field
  static const int translationId1Width = 8;

  /// Width of doNotCache field
  static const int doNotCacheWidth = 1;

  /// Width of cont field
  static const int contWidth = 4;

  /// Width of faultType field
  static const int faultTypeWidth = 3;

  /// Width of rsvd field
  static const int rsvdWidth = 8;

  /// Width of translationId2 field
  static const int translationId2Width = 4;

  /// Width of full translationId
  static const int translationIdWidth =
      translationId1Width + translationId2Width;

  /// Total width of DtiTbuTransFault
  static const int totalWidth = msgTypeWidth +
      translationIdWidth +
      doNotCacheWidth +
      contWidth +
      faultTypeWidth +
      rsvdWidth;

  /// msgType
  final Logic msgType;

  /// translationId1
  final Logic translationId1;

  /// doNotCache
  final Logic doNotCache;

  /// cont
  final Logic cont;

  /// faultType
  final Logic faultType;

  /// rsvd
  final Logic rsvd;

  /// translationId2
  final Logic translationId2;

  /// full translation ID
  Logic get translationId => [translationId2, translationId1].swizzle();

  /// Base constructor.
  DtiTbuTransFault._({
    required this.msgType,
    required this.translationId1,
    required this.doNotCache,
    required this.cont,
    required this.faultType,
    required this.rsvd,
    required this.translationId2,
    super.name = 'dtiTbuTransFault',
  }) : super([
          msgType,
          translationId1,
          doNotCache,
          cont,
          faultType,
          rsvd,
          translationId2,
        ]);

  /// Factory constructor.
  factory DtiTbuTransFault([String name = 'trans_fault']) => DtiTbuTransFault._(
        msgType: Logic(name: '${name}_msgType', width: msgTypeWidth),
        translationId1: Logic(
          name: '${name}_translationId1',
          width: translationId1Width,
        ),
        doNotCache: Logic(name: '${name}_doNotCache', width: doNotCacheWidth),
        cont: Logic(name: '${name}_cont', width: contWidth),
        faultType: Logic(name: '${name}_faultType', width: faultTypeWidth),
        rsvd: Logic(name: '${name}_rsvd', width: rsvdWidth),
        translationId2: Logic(
          name: '${name}_translationId2',
          width: translationId2Width,
        ),
        name: name,
      );

  /// Copy constructor.
  @override
  DtiTbuTransFault clone({String? name}) => DtiTbuTransFault._(
        msgType: msgType.clone(),
        translationId1: translationId1.clone(),
        doNotCache: doNotCache.clone(),
        cont: cont.clone(),
        faultType: faultType.clone(),
        rsvd: rsvd.clone(),
        translationId2: translationId2.clone(),
        name: name ?? this.name,
      );

  /// Helper for zero initialization
  void zeroInit() {
    msgType.put(DtiUpstreamMsgType.transFault.value);
    translationId1.put(0);
    doNotCache.put(0);
    cont.put(0);
    faultType.put(0);
    rsvd.put(0);
    translationId2.put(0);
  }
}

/// Invalidation request.
class DtiTbuInvReq extends LogicStructure {
  /// Width of msgType field
  static const int msgTypeWidth = 4;

  /// Width of operation1 field
  static const int operation1Width = 8;

  /// Width of ssid field
  static const int ssidWidth = 20;

  /// Width of sid field
  static const int sidWidth = 32;

  /// Width of range field
  static const int rangeWidth = 5;

  /// Width of incAset1 field
  static const int incAset1Width = 1;

  /// Width of operation2 field
  static const int operation2Width = 1;

  /// Width of scale field
  static const int scale1Width = 1;

  /// Width of rsvd field
  static const int rsvdWidth = 4;

  /// Width of address field
  static const int addressWidth = 64;

  /// Full operation width
  static const int operationWidth = operation1Width + operation2Width;

  /// Total width of DtiTbuInvReq
  static const int totalWidth = msgTypeWidth +
      operationWidth +
      ssidWidth +
      sidWidth +
      rangeWidth +
      incAset1Width +
      scale1Width +
      rsvdWidth +
      addressWidth;

  /// msgType
  final Logic msgType;

  /// operation1
  final Logic operation1;

  /// ssid
  final Logic ssid;

  /// sid
  final Logic sid;

  /// range
  final Logic range;

  /// incAset1
  final Logic incAset1;

  /// operation2
  final Logic operation2;

  /// scale1
  final Logic scale1;

  /// rsvd
  final Logic rsvd;

  /// address
  final Logic address;

  /// TTL aliased within SSID.
  Logic get ttl => ssid.getRange(0, 2);

  /// TG aliased within SSID.
  Logic get tg => ssid.getRange(2, 4);

  /// Size aliased within SSID.
  Logic get size => ssid.getRange(0, 4);

  /// Num aliased within SSID.
  Logic get num => ssid.getRange(4, 9);

  /// Scale partially aliased within SSID.
  Logic get scale => [scale1, ssid.getRange(9, 14)].swizzle();

  /// vmId aliased within SID.
  Logic get vmId => sid.getRange(0, 16);

  /// asId aliased within SID.
  Logic get asId => sid.getRange(16, 32);

  /// Full operation.
  Logic get operation => [operation2, operation1].swizzle();

  /// Base constructor.
  DtiTbuInvReq._({
    required this.msgType,
    required this.operation1,
    required this.ssid,
    required this.sid,
    required this.range,
    required this.incAset1,
    required this.operation2,
    required this.scale1,
    required this.rsvd,
    required this.address,
    super.name = 'dtiTbuInvReq',
  }) : super([
          msgType,
          operation1,
          ssid,
          sid,
          range,
          incAset1,
          operation2,
          scale1,
          rsvd,
          address,
        ]);

  /// Factory constructor.
  factory DtiTbuInvReq({String? name}) => DtiTbuInvReq._(
        msgType: Logic(name: '${name}_msgType', width: msgTypeWidth),
        operation1: Logic(name: '${name}_operation1', width: operation1Width),
        ssid: Logic(name: '${name}_ssid', width: ssidWidth),
        sid: Logic(name: '${name}_sid', width: sidWidth),
        range: Logic(name: '${name}_range', width: rangeWidth),
        incAset1: Logic(name: '${name}_incAset1', width: incAset1Width),
        operation2: Logic(name: '${name}_operation2', width: operation2Width),
        scale1: Logic(name: '${name}_scale1', width: scale1Width),
        rsvd: Logic(name: '${name}_rsvd', width: rsvdWidth),
        address: Logic(name: '${name}_address', width: addressWidth),
        name: name,
      );

  /// Copy constructor.
  @override
  DtiTbuInvReq clone({String? name}) => DtiTbuInvReq._(
        msgType: msgType.clone(),
        operation1: operation1.clone(),
        ssid: ssid.clone(),
        sid: sid.clone(),
        range: range.clone(),
        incAset1: incAset1.clone(),
        operation2: operation2.clone(),
        scale1: scale1.clone(),
        rsvd: rsvd.clone(),
        address: address.clone(),
        name: name ?? this.name,
      );

  /// Helper for zero initialization
  void zeroInit() {
    msgType.put(DtiUpstreamMsgType.invReq.value);
    operation1.put(0);
    ssid.put(0);
    sid.put(0);
    range.put(0);
    incAset1.put(0);
    operation2.put(0);
    scale1.put(0);
    rsvd.put(0);
    address.put(0);
  }
}

/// Invalidation request.
class DtiTbuInvAck extends LogicStructure {
  /// Width of msgType field
  static const int msgTypeWidth = 4;

  /// Width of rsvd field
  static const int rsvdWidth = 4;

  /// Total width of DtiTbuInvAck
  static const int totalWidth = msgTypeWidth + rsvdWidth;

  /// msgType
  final Logic msgType;

  /// rsvd
  final Logic rsvd;

  /// Base constructor.
  DtiTbuInvAck._({
    required this.msgType,
    required this.rsvd,
    super.name = 'dtiTbuInvAck',
  }) : super([msgType, rsvd]);

  /// Factory constructor.
  factory DtiTbuInvAck({String? name}) => DtiTbuInvAck._(
        msgType: Logic(name: '${name}_msgType', width: msgTypeWidth),
        rsvd: Logic(name: '${name}_rsvd', width: rsvdWidth),
        name: name,
      );

  /// Copy constructor.
  @override
  DtiTbuInvAck clone({String? name}) => DtiTbuInvAck._(
        msgType: msgType.clone(),
        rsvd: rsvd.clone(),
        name: name ?? this.name,
      );

  /// Helper for zero initialization
  void zeroInit() {
    msgType.put(DtiDownstreamMsgType.invAck.value);
    rsvd.put(0);
  }
}

/// Synchronization request.
class DtiTbuSyncReq extends LogicStructure {
  /// Width of msgType field
  static const int msgTypeWidth = 4;

  /// Width of rsvd field
  static const int rsvdWidth = 4;

  /// Total width of DtiTbuInvAck
  static const int totalWidth = msgTypeWidth + rsvdWidth;

  /// msgType
  final Logic msgType;

  /// rsvd
  final Logic rsvd;

  /// Base constructor.
  DtiTbuSyncReq._({
    required this.msgType,
    required this.rsvd,
    super.name = 'dtiTbuSyncReq',
  }) : super([msgType, rsvd]);

  /// Factory constructor.
  factory DtiTbuSyncReq({String? name}) => DtiTbuSyncReq._(
        msgType: Logic(name: '${name}_msgType', width: msgTypeWidth),
        rsvd: Logic(name: '${name}_rsvd', width: rsvdWidth),
        name: name,
      );

  /// Copy constructor.
  @override
  DtiTbuSyncReq clone({String? name}) => DtiTbuSyncReq._(
        msgType: msgType.clone(),
        rsvd: rsvd.clone(),
        name: name ?? this.name,
      );

  /// Helper for zero initialization
  void zeroInit() {
    msgType.put(DtiUpstreamMsgType.syncReq.value);
    rsvd.put(0);
  }
}

/// Synchronization acknowledgement.
class DtiTbuSyncAck extends LogicStructure {
  /// Width of msgType field
  static const int msgTypeWidth = 4;

  /// Width of rsvd field
  static const int rsvdWidth = 4;

  /// Total width of DtiTbuInvAck
  static const int totalWidth = msgTypeWidth + rsvdWidth;

  /// msgType
  final Logic msgType;

  /// rsvd
  final Logic rsvd;

  /// Base constructor.
  DtiTbuSyncAck._({
    required this.msgType,
    required this.rsvd,
    super.name = 'dtiTbuSyncAck',
  }) : super([msgType, rsvd]);

  /// Factory constructor.
  factory DtiTbuSyncAck({String? name}) => DtiTbuSyncAck._(
        msgType: Logic(name: '${name}_msgType', width: msgTypeWidth),
        rsvd: Logic(name: '${name}_rsvd', width: rsvdWidth),
        name: name,
      );

  /// Copy constructor.
  @override
  DtiTbuSyncAck clone({String? name}) => DtiTbuSyncAck._(
        msgType: msgType.clone(),
        rsvd: rsvd.clone(),
        name: name ?? this.name,
      );

  /// Helper for zero initialization
  void zeroInit() {
    msgType.put(DtiDownstreamMsgType.syncAck.value);
    rsvd.put(0);
  }
}

/// Connect/disconnect request.
class DtiTbuCondisReq extends LogicStructure {
  /// Width of msgType field
  static const int msgTypeWidth = 4;

  /// Width of state field
  static const int stateWidth = 1;

  /// Width of protocol field
  static const int protocolWidth = 1;

  /// Width of rsvd1 field
  static const int rsvd1Width = 1;

  /// Width of impDef field
  static const int impDefWidth = 1;

  /// Width of version field
  static const int versionWidth = 4;

  /// Width of tokTransReq1 field
  static const int tokTransReq1Width = 8;

  /// Width of tokInvGnt field
  static const int tokInvGntWidth = 4;

  /// Width of supReg field
  static const int supRegWidth = 1;

  /// Width of spd field
  static const int spdWidth = 1;

  /// Width of stages field
  static const int stagesWidth = 2;

  /// Width of tokTransReq2 field
  static const int tokTransReq2Width = 4;

  /// Full width of tokTransReq
  static const int tokTransReqWidth = tokTransReq1Width + tokTransReq2Width;

  /// Total width of DtiTbuCondisReq
  static const int totalWidth = msgTypeWidth +
      stateWidth +
      protocolWidth +
      rsvd1Width +
      impDefWidth +
      versionWidth +
      tokTransReqWidth +
      tokInvGntWidth +
      supRegWidth +
      spdWidth +
      stagesWidth;

  /// msgType
  final Logic msgType;

  /// state
  final Logic state;

  /// protocol
  final Logic protocol;

  /// rsvd1
  final Logic rsvd1;

  /// impDef
  final Logic impDef;

  /// version
  final Logic version;

  /// tokTransReq1
  final Logic tokTransReq1;

  /// tokInvGnt
  final Logic tokInvGnt;

  /// supReg
  final Logic supReg;

  /// spd
  final Logic spd;

  /// stages
  final Logic stages;

  /// tokTransReq2
  final Logic tokTransReq2;

  /// Full tokTransReq
  Logic get tokTransReq => [tokTransReq2, tokTransReq1].swizzle();

  /// Base constructor.
  DtiTbuCondisReq._({
    required this.msgType,
    required this.state,
    required this.protocol,
    required this.rsvd1,
    required this.impDef,
    required this.version,
    required this.tokTransReq1,
    required this.tokInvGnt,
    required this.supReg,
    required this.spd,
    required this.stages,
    required this.tokTransReq2,
    super.name = 'dtiTbuCondisReq',
  }) : super([
          msgType,
          state,
          protocol,
          rsvd1,
          impDef,
          version,
          tokTransReq1,
          tokInvGnt,
          supReg,
          spd,
          stages,
          tokTransReq2,
        ]);

  /// Factory constructor.
  factory DtiTbuCondisReq({String? name}) => DtiTbuCondisReq._(
        msgType: Logic(name: '${name}_msgType', width: msgTypeWidth),
        state: Logic(name: '${name}_state', width: stateWidth),
        protocol: Logic(name: '${name}_protocol', width: protocolWidth),
        rsvd1: Logic(name: '${name}_rsvd1', width: rsvd1Width),
        impDef: Logic(name: '${name}_impDef', width: impDefWidth),
        version: Logic(name: '${name}_version', width: versionWidth),
        tokTransReq1:
            Logic(name: '${name}_tokTransReq1', width: tokTransReq1Width),
        tokInvGnt: Logic(name: '${name}_tokInvGnt', width: tokInvGntWidth),
        supReg: Logic(name: '${name}_supReg', width: supRegWidth),
        spd: Logic(name: '${name}_spd', width: spdWidth),
        stages: Logic(name: '${name}_stages', width: stagesWidth),
        tokTransReq2:
            Logic(name: '${name}_tokTransReq2', width: tokTransReq2Width),
        name: name,
      );

  /// Copy constructor.
  @override
  DtiTbuCondisReq clone({String? name}) => DtiTbuCondisReq._(
        msgType: msgType.clone(),
        state: state.clone(),
        protocol: protocol.clone(),
        rsvd1: rsvd1.clone(),
        impDef: impDef.clone(),
        version: version.clone(),
        tokTransReq1: tokTransReq1.clone(),
        tokInvGnt: tokInvGnt.clone(),
        supReg: supReg.clone(),
        spd: spd.clone(),
        stages: stages.clone(),
        tokTransReq2: tokTransReq2.clone(),
        name: name ?? this.name,
      );

  /// Helper for zero initialization
  void zeroInit() {
    msgType.put(DtiDownstreamMsgType.condisReq.value);
    state.put(0);
    protocol.put(0);
    rsvd1.put(0);
    impDef.put(0);
    version.put(0);
    tokTransReq1.put(0);
    tokInvGnt.put(0);
    supReg.put(0);
    spd.put(0);
    stages.put(0);
    tokTransReq2.put(0);
  }
}

/// Connect/disconnect acknowledge.
class DtiTbuCondisAck extends LogicStructure {
  /// Width of msgType field
  static const int msgTypeWidth = 4;

  /// Width of state field
  static const int stateWidth = 1;

  /// Width of rsvd1 field
  static const int rsvd1Width = 2;

  /// Width of impDef field
  static const int impDefWidth = 1;

  /// Width of version field
  static const int versionWidth = 4;

  /// Width of tokTransGnt1 field
  static const int tokTransGnt1Width = 8;

  /// Width of noCacheInit field
  static const int noCacheInitWidth = 1;

  /// Width of oas field
  static const int oasWidth = 4;

  /// Width of spd field
  static const int rsvd2Width = 3;

  /// Width of tokTransGnt2 field
  static const int tokTransGnt2Width = 4;

  /// Full width of tokTransGnt
  static const int tokTransGntWidth = tokTransGnt1Width + tokTransGnt2Width;

  /// Total width of DtiTbuCondisAck
  static const int totalWidth = msgTypeWidth +
      stateWidth +
      rsvd1Width +
      impDefWidth +
      versionWidth +
      tokTransGntWidth +
      noCacheInitWidth +
      oasWidth +
      rsvd2Width;

  /// msgType
  final Logic msgType;

  /// state
  final Logic state;

  /// rsvd1
  final Logic rsvd1;

  /// impDef
  final Logic impDef;

  /// version
  final Logic version;

  /// tokTransGnt1
  final Logic tokTransGnt1;

  /// noCacheInit
  final Logic noCacheInit;

  /// oas
  final Logic oas;

  /// rsvd2
  final Logic rsvd2;

  /// tokTransGnt2
  final Logic tokTransGnt2;

  /// Full tokTransGnt
  Logic get tokTransGnt => [tokTransGnt2, tokTransGnt1].swizzle();

  /// Base constructor.
  DtiTbuCondisAck._({
    required this.msgType,
    required this.state,
    required this.rsvd1,
    required this.impDef,
    required this.version,
    required this.tokTransGnt1,
    required this.noCacheInit,
    required this.oas,
    required this.tokTransGnt2,
    required this.rsvd2,
    super.name = 'dtiTbuCondisAck',
  }) : super([
          msgType,
          state,
          rsvd1,
          impDef,
          version,
          tokTransGnt1,
          noCacheInit,
          oas,
          tokTransGnt2,
          rsvd2,
        ]);

  /// Factory constructor.
  factory DtiTbuCondisAck({String? name}) => DtiTbuCondisAck._(
        msgType: Logic(name: '${name}_msgType', width: msgTypeWidth),
        state: Logic(name: '${name}_state', width: stateWidth),
        rsvd1: Logic(name: '${name}_rsvd1', width: rsvd1Width),
        impDef: Logic(name: '${name}_impDef', width: impDefWidth),
        version: Logic(name: '${name}_version', width: versionWidth),
        tokTransGnt1:
            Logic(name: '${name}_tokTransGnt1', width: tokTransGnt1Width),
        noCacheInit:
            Logic(name: '${name}_noCacheInit', width: noCacheInitWidth),
        oas: Logic(name: '${name}_oas', width: oasWidth),
        tokTransGnt2:
            Logic(name: '${name}_tokTransGnt2', width: tokTransGnt2Width),
        rsvd2: Logic(name: '${name}_rsvd2', width: rsvd2Width),
        name: name,
      );

  /// Copy constructor.
  @override
  DtiTbuCondisAck clone({String? name}) => DtiTbuCondisAck._(
        msgType: msgType.clone(),
        state: state.clone(),
        rsvd1: rsvd1.clone(),
        impDef: impDef.clone(),
        version: version.clone(),
        tokTransGnt1: tokTransGnt1.clone(),
        noCacheInit: noCacheInit.clone(),
        oas: oas.clone(),
        tokTransGnt2: tokTransGnt2.clone(),
        rsvd2: rsvd2.clone(),
        name: name ?? this.name,
      );

  /// Helper for zero initialization
  void zeroInit() {
    msgType.put(DtiUpstreamMsgType.condisAck.value);
    state.put(0);
    rsvd1.put(0);
    impDef.put(0);
    version.put(0);
    tokTransGnt1.put(0);
    noCacheInit.put(0);
    oas.put(0);
    tokTransGnt2.put(0);
    rsvd2.put(0);
  }
}
