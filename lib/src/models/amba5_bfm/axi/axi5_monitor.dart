// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_monitor.dart
// Monitors that watch the AXI5 interfaces.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A monitor for [Axi5ArChannelInterface]s.
class Axi5ArChannelMonitor extends Monitor<Axi5ArChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 Read Interface.
  final Axi5ArChannelInterface ar;

  /// Creates a new [Axi5ArChannelMonitor] on [ar].
  Axi5ArChannelMonitor(
      {required this.sys,
      required this.ar,
      required Component parent,
      String name = 'axi5RequestChannelMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sys.resetN.nextPosedge;

    // TODO: handle credited!!

    sys.clk.posedge.listen((event) {
      if (ar.valid.previousValue!.isValid &&
          ar.ready!.previousValue!.isValid &&
          ar.valid.previousValue!.toBool() &&
          ar.ready!.previousValue!.toBool()) {
        add(Axi5ArChannelPacket(
          request: Axi5RequestSignalsStruct(
            addr: ar.addr.previousValue!.toInt(),
            len: ar.len?.previousValue!.toInt(),
            size: ar.size?.previousValue!.toInt(),
            burst: ar.burst?.previousValue!.toInt(),
            qos: ar.qos?.previousValue!.toInt(),
          ),
          prot: Axi5ProtSignalsStruct(
            prot: ar.prot?.previousValue!.toInt(),
            nse: ar.nse?.previousValue!.toBool(),
            priv: ar.priv?.previousValue!.toBool(),
            inst: ar.inst?.previousValue!.toBool(),
            pas: ar.pas?.previousValue!.toInt(),
          ),
          memAttr: Axi5MemoryAttributeSignalsStruct(
            cache: ar.cache?.previousValue!.toInt(),
            region: ar.region?.previousValue!.toInt(),
            mecId: ar.mecId?.previousValue!.toInt(),
          ),
          user: ar.user != null
              ? Axi5UserSignalsStruct(user: ar.user?.previousValue!.toInt())
              : null,
          id: ar.id != null
              ? Axi5IdSignalsStruct(
                  id: ar.id?.previousValue!.toInt(),
                  idUnq: ar.idUnq?.previousValue!.toBool())
              : null,
          debug: Axi5DebugSignalsStruct(
              trace: ar.trace?.previousValue!.toBool(),
              loop: ar.loop?.previousValue!.toInt()),
          mmu: ar.mmuValid != null
              ? Axi5MmuSignalsStruct(
                  mmuValid: ar.mmuValid?.previousValue!.toBool(),
                  mmuSecSid: ar.mmuSecSid?.previousValue!.toInt(),
                  mmuSid: ar.mmuSid?.previousValue!.toInt(),
                  mmuSsidV: ar.mmuSsidV?.previousValue!.toBool(),
                  mmuSsid: ar.mmuSsid?.previousValue!.toInt(),
                  mmuAtSt: ar.mmuAtSt?.previousValue!.toBool(),
                  mmuFlow: ar.mmuFlow?.previousValue!.toInt(),
                  mmuPasUnknown: ar.mmuPasUnknown?.previousValue!.toBool(),
                  mmuPm: ar.mmuPm?.previousValue!.toBool(),
                )
              : null,
          qual: ar.nsaId != null
              ? Axi5QualifierSignalsStruct(
                  nsaId: ar.nsaId?.previousValue!.toInt(),
                  pbha: ar.pbha?.previousValue!.toInt(),
                  subSysId: ar.subSysId?.previousValue!.toInt(),
                  actV: ar.actV?.previousValue!.toBool(),
                  act: ar.act?.previousValue!.toInt(),
                )
              : null,
          atomic: ar.lock != null
              ? Axi5AtomicSignalsStruct(
                  lock: ar.lock?.previousValue!.toBool(),
                  atOp: ar.atOp?.previousValue!.toInt(),
                )
              : null,
          tag: ar.mpam != null
              ? Axi5MemPartTagSignalsStruct(
                  mpam: ar.mpam?.previousValue!.toInt(),
                  tagOp: ar.tagOp?.previousValue!.toInt(),
                )
              : null,
          chunk: ar.chunkEn != null
              ? Axi5ChunkSignalsStruct(
                  chunkEn: ar.chunkEn?.previousValue!.toBool(),
                  chunkV: ar.chunkV?.previousValue!.toBool(),
                  chunkNum: ar.chunkNum?.previousValue!.toInt(),
                  chunkStrb: ar.chunkStrb?.previousValue!.toInt(),
                )
              : null,
          opcode: ar.snoop != null
              ? Axi5OpcodeSignalsStruct(snoop: ar.snoop?.previousValue!.toInt())
              : null,
        ));
      }
    });
  }
}

/// A monitor for [Axi5AwChannelInterface]s.
class Axi5AwChannelMonitor extends Monitor<Axi5AwChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 Write Address Interface.
  final Axi5AwChannelInterface aw;

  /// Creates a new [Axi5AwChannelMonitor] on [aw].
  Axi5AwChannelMonitor(
      {required this.sys,
      required this.aw,
      required Component parent,
      String name = 'axi5AwChannelMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sys.resetN.nextPosedge;

    // TODO: handle credited!!

    sys.clk.posedge.listen((event) {
      if (aw.valid.previousValue!.isValid &&
          aw.ready!.previousValue!.isValid &&
          aw.valid.previousValue!.toBool() &&
          aw.ready!.previousValue!.toBool()) {
        add(Axi5AwChannelPacket(
          request: Axi5RequestSignalsStruct(
            addr: aw.addr.previousValue!.toInt(),
            len: aw.len?.previousValue!.toInt(),
            size: aw.size?.previousValue!.toInt(),
            burst: aw.burst?.previousValue!.toInt(),
            qos: aw.qos?.previousValue!.toInt(),
          ),
          prot: Axi5ProtSignalsStruct(
            prot: aw.prot?.previousValue!.toInt(),
            nse: aw.nse?.previousValue!.toBool(),
            priv: aw.priv?.previousValue!.toBool(),
            inst: aw.inst?.previousValue!.toBool(),
            pas: aw.pas?.previousValue!.toInt(),
          ),
          memAttr: Axi5MemoryAttributeSignalsStruct(
            cache: aw.cache?.previousValue!.toInt(),
            region: aw.region?.previousValue!.toInt(),
            mecId: aw.mecId?.previousValue!.toInt(),
          ),
          user: aw.user != null
              ? Axi5UserSignalsStruct(user: aw.user?.previousValue!.toInt())
              : null,
          id: aw.id != null
              ? Axi5IdSignalsStruct(
                  id: aw.id?.previousValue!.toInt(),
                  idUnq: aw.idUnq?.previousValue!.toBool())
              : null,
          debug: Axi5DebugSignalsStruct(
              trace: aw.trace?.previousValue!.toBool(),
              loop: aw.loop?.previousValue!.toInt()),
          mmu: aw.mmuValid != null
              ? Axi5MmuSignalsStruct(
                  mmuValid: aw.mmuValid?.previousValue!.toBool(),
                  mmuSecSid: aw.mmuSecSid?.previousValue!.toInt(),
                  mmuSid: aw.mmuSid?.previousValue!.toInt(),
                  mmuSsidV: aw.mmuSsidV?.previousValue!.toBool(),
                  mmuSsid: aw.mmuSsid?.previousValue!.toInt(),
                  mmuAtSt: aw.mmuAtSt?.previousValue!.toBool(),
                  mmuFlow: aw.mmuFlow?.previousValue!.toInt(),
                  mmuPasUnknown: aw.mmuPasUnknown?.previousValue!.toBool(),
                  mmuPm: aw.mmuPm?.previousValue!.toBool(),
                )
              : null,
          qual: aw.nsaId != null
              ? Axi5QualifierSignalsStruct(
                  nsaId: aw.nsaId?.previousValue!.toInt(),
                  pbha: aw.pbha?.previousValue!.toInt(),
                  subSysId: aw.subSysId?.previousValue!.toInt(),
                  actV: aw.actV?.previousValue!.toBool(),
                  act: aw.act?.previousValue!.toInt(),
                )
              : null,
          atomic: aw.lock != null
              ? Axi5AtomicSignalsStruct(
                  lock: aw.lock?.previousValue!.toBool(),
                  atOp: aw.atOp?.previousValue!.toInt(),
                )
              : null,
          tag: aw.mpam != null
              ? Axi5MemPartTagSignalsStruct(
                  mpam: aw.mpam?.previousValue!.toInt(),
                  tagOp: aw.tagOp?.previousValue!.toInt(),
                )
              : null,
          stash: aw.domain != null
              ? Axi5StashSignalsStruct(
                  domain: aw.domain?.previousValue!.toInt(),
                  stashNid: aw.stashNid?.previousValue!.toInt(),
                  stashNidEn: aw.stashNidEn?.previousValue!.toBool(),
                  stashLPid: aw.stashLPid?.previousValue!.toInt(),
                  stashLPidEn: aw.stashLPidEn?.previousValue!.toBool(),
                  cmo: aw.cmo?.previousValue!.toInt(),
                )
              : null,
          opcode: aw.snoop != null
              ? Axi5OpcodeSignalsStruct(snoop: aw.snoop?.previousValue!.toInt())
              : null,
        ));
      }
    });
  }
}

/// A monitor for [Axi5RChannelInterface]s.
class Axi5RChannelMonitor extends Monitor<Axi5RChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 Read Data Interface.
  final Axi5RChannelInterface r;

  // to cache beats of data
  final List<LogicValue> _dataBuffer = [];
  final List<LogicValue> _poisonBuffer = [];

  /// Creates a new [Axi5RChannelMonitor] on [r].
  Axi5RChannelMonitor(
      {required this.sys,
      required this.r,
      required Component parent,
      String name = 'axi5RChannelMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sys.resetN.nextPosedge;

    // on reset, clear all buffers
    sys.resetN.negedge.listen((event) {
      _dataBuffer.clear();
      _poisonBuffer.clear();
    });

    // TODO: handle credited!!

    sys.clk.posedge.listen((event) {
      if (r.valid.previousValue!.isValid &&
          r.ready!.previousValue!.isValid &&
          r.valid.previousValue!.toBool() &&
          r.ready!.previousValue!.toBool()) {
        _dataBuffer.add(r.data.value);
        if (r.poison != null) {
          _poisonBuffer.add(r.poison!.value);
        }

        // capture if the last beat in the transfer
        final lastChk1 = r.last == null;
        final lastChk2 = !lastChk1 &&
            (r.last!.previousValue!.isValid && r.last!.previousValue!.toBool());
        if (lastChk1 || lastChk2) {
          final dataPkts = <Axi5DataSignalsStruct>[];
          for (var i = 0; i < _dataBuffer.length; i++) {
            dataPkts.add(Axi5DataSignalsStruct(
              data: _dataBuffer[i].toBigInt(),
              last: i == _dataBuffer.length - 1,
              poison:
                  i < _poisonBuffer.length ? _poisonBuffer[i].toInt() : null,
            ));
          }
          add(Axi5RChannelPacket(
            data: dataPkts,
            id: r.id != null
                ? Axi5IdSignalsStruct(
                    id: r.id?.previousValue!.toInt(),
                    idUnq: r.idUnq?.previousValue!.toBool())
                : null,
            tag: r.tag != null
                ? Axi5MemRespDataTagSignalsStruct(
                    tag: r.tag?.previousValue!.toInt(),
                    tagUpdate: r.tagUpdate?.previousValue!.toInt(),
                    tagMatch: r.tagMatch?.previousValue!.toInt(),
                    comp: r.comp?.previousValue!.toBool(),
                    persist: r.persist?.previousValue!.toBool(),
                  )
                : null,
            debug: Axi5DebugSignalsStruct(
                trace: r.trace?.previousValue!.toBool(),
                loop: r.loop?.previousValue!.toInt()),
            response: r.resp != null || r.busy != null
                ? Axi5ResponseSignalsStruct(
                    resp: r.resp?.previousValue!.toInt(),
                    busy: r.busy?.previousValue!.toBool())
                : null,
            chunk: r.chunkEn != null
                ? Axi5ChunkSignalsStruct(
                    chunkEn: r.chunkEn?.previousValue!.toBool(),
                    chunkV: r.chunkV?.previousValue!.toBool(),
                    chunkNum: r.chunkNum?.previousValue!.toInt(),
                    chunkStrb: r.chunkStrb?.previousValue!.toInt(),
                  )
                : null,
            user: r.user != null
                ? Axi5UserSignalsStruct(user: r.user?.previousValue!.toInt())
                : null,
          ));
          _dataBuffer.clear();
          _poisonBuffer.clear();
        }
      }
    });
  }
}

/// A monitor for [Axi5WChannelInterface]s.
class Axi5WChannelMonitor extends Monitor<Axi5WChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 Write Data Interface.
  final Axi5WChannelInterface w;

  // to cache beats of data
  final List<LogicValue> _dataBuffer = [];
  final List<LogicValue> _strbBuffer = [];
  final List<LogicValue> _poisonBuffer = [];

  /// Creates a new [Axi5WChannelMonitor] on [w].
  Axi5WChannelMonitor(
      {required this.sys,
      required this.w,
      required Component parent,
      String name = 'axi5WChannelMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    // on reset, clear all buffers
    sys.resetN.negedge.listen((event) {
      _dataBuffer.clear();
      _strbBuffer.clear();
      _poisonBuffer.clear();
    });

    await sys.resetN.nextPosedge;

    // TODO: handle credited!!

    sys.clk.posedge.listen((event) {
      if (w.valid.previousValue!.isValid &&
          w.ready!.previousValue!.isValid &&
          w.valid.previousValue!.toBool() &&
          w.ready!.previousValue!.toBool()) {
        _dataBuffer.add(w.data.value);
        if (w.strb != null) {
          _strbBuffer.add(w.strb!.value);
        }
        if (w.poison != null) {
          _poisonBuffer.add(w.poison!.value);
        }

        // capture if the last beat in the transfer
        final lastChk1 = w.last == null;
        final lastChk2 = !lastChk1 &&
            (w.last!.previousValue!.isValid && w.last!.previousValue!.toBool());
        if (lastChk1 || lastChk2) {
          final dataPkts = <Axi5DataSignalsStruct>[];
          for (var i = 0; i < _dataBuffer.length; i++) {
            dataPkts.add(Axi5DataSignalsStruct(
              data: _dataBuffer[i].toBigInt(),
              last: i == _dataBuffer.length - 1,
              strb: i < _strbBuffer.length ? _strbBuffer[i].toInt() : null,
              poison:
                  i < _poisonBuffer.length ? _poisonBuffer[i].toInt() : null,
            ));
          }

          add(Axi5WChannelPacket(
            data: dataPkts,
            tag: w.tag != null
                ? Axi5MemRespDataTagSignalsStruct(
                    tag: w.tag?.previousValue!.toInt(),
                    tagUpdate: w.tagUpdate?.previousValue!.toInt(),
                    tagMatch: w.tagMatch?.previousValue!.toInt(),
                    comp: w.comp?.previousValue!.toBool(),
                    persist: w.persist?.previousValue!.toBool(),
                  )
                : null,
            debug: Axi5DebugSignalsStruct(
                trace: w.trace?.previousValue!.toBool(),
                loop: w.loop?.previousValue!.toInt()),
            user: w.user != null
                ? Axi5UserSignalsStruct(user: w.user?.previousValue!.toInt())
                : null,
          ));
          _dataBuffer.clear();
          _strbBuffer.clear();
          _poisonBuffer.clear();
        }
      }
    });
  }
}

/// A monitor for [Axi5BChannelInterface]s.
class Axi5BChannelMonitor extends Monitor<Axi5BChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 Write Response Interface.
  final Axi5BChannelInterface b;

  /// Creates a new [Axi5BChannelMonitor] on [b].
  Axi5BChannelMonitor(
      {required this.sys,
      required this.b,
      required Component parent,
      String name = 'axi5BChannelMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sys.resetN.nextPosedge;

    // TODO: handle credited!!

    sys.clk.posedge.listen((event) {
      if (b.valid.previousValue!.isValid &&
          b.ready!.previousValue!.isValid &&
          b.valid.previousValue!.toBool() &&
          b.ready!.previousValue!.toBool()) {
        add(Axi5BChannelPacket(
          id: b.id != null
              ? Axi5IdSignalsStruct(
                  id: b.id?.previousValue!.toInt(),
                  idUnq: b.idUnq?.previousValue!.toBool())
              : null,
          tag: b.tag != null
              ? Axi5MemRespDataTagSignalsStruct(
                  tag: b.tag?.previousValue!.toInt(),
                  tagUpdate: b.tagUpdate?.previousValue!.toInt(),
                  tagMatch: b.tagMatch?.previousValue!.toInt(),
                  comp: b.comp?.previousValue!.toBool(),
                  persist: b.persist?.previousValue!.toBool(),
                )
              : null,
          debug: Axi5DebugSignalsStruct(
              trace: b.trace?.previousValue!.toBool(),
              loop: b.loop?.previousValue!.toInt()),
          response: Axi5ResponseSignalsStruct(
              resp: b.resp?.previousValue!.toInt(),
              busy: b.busy?.previousValue!.toBool()),
          user: b.user != null
              ? Axi5UserSignalsStruct(user: b.user?.previousValue!.toInt())
              : null,
        ));
      }
    });
  }
}

/// A monitor for [Axi5AcChannelInterface]s.
class Axi5AcChannelMonitor extends Monitor<Axi5AcChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 AC Interface.
  final Axi5AcChannelInterface ac;

  /// Creates a new [Axi5AcChannelMonitor] on [ac].
  Axi5AcChannelMonitor(
      {required this.sys,
      required this.ac,
      required Component parent,
      String name = 'axi5AcChannelMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sys.resetN.nextPosedge;

    sys.clk.posedge.listen((event) {
      if (ac.valid.previousValue!.isValid &&
          ac.ready!.previousValue!.isValid &&
          ac.valid.previousValue!.toBool() &&
          ac.ready!.previousValue!.toBool()) {
        add(Axi5AcChannelPacket(
          addr: ac.addr?.previousValue!.toInt() ?? 0,
          vmidExt: ac.vmidExt?.previousValue!.toInt() ?? 0,
          debug: Axi5DebugSignalsStruct(
            trace: ac.trace?.previousValue!.toBool(),
            loop: ac.loop?.previousValue!.toInt(),
          ),
        ));
      }
    });
  }
}

/// A monitor for [Axi5CrChannelInterface]s.
class Axi5CrChannelMonitor extends Monitor<Axi5CrChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 CR Interface.
  final Axi5CrChannelInterface cr;

  /// Creates a new [Axi5CrChannelMonitor] on [cr].
  Axi5CrChannelMonitor(
      {required this.sys,
      required this.cr,
      required Component parent,
      String name = 'axi5CrChannelMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sys.resetN.nextPosedge;

    sys.clk.posedge.listen((event) {
      if (cr.valid.previousValue!.isValid &&
          cr.ready!.previousValue!.isValid &&
          cr.valid.previousValue!.toBool() &&
          cr.ready!.previousValue!.toBool()) {
        add(Axi5CrChannelPacket(
          debug: Axi5DebugSignalsStruct(
            trace: cr.trace?.previousValue!.toBool(),
            loop: cr.loop?.previousValue!.toInt(),
          ),
        ));
      }
    });
  }
}
