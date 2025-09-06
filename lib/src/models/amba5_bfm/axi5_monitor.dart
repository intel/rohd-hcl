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
class Axi5RequestChannelMonitor extends Monitor<Axi5ArChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 Read Interface.
  final Axi5ArChannelInterface ar;

  /// Creates a new [Axi5RequestChannelMonitor] on [ar].
  Axi5RequestChannelMonitor(
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
            addr: ar.addr.value.toInt(),
            len: ar.len?.value.toInt(),
            size: ar.size?.value.toInt(),
            burst: ar.burst?.value.toInt(),
            qos: ar.qos?.value.toInt(),
          ),
          prot: Axi5ProtSignalsStruct(
            prot: ar.prot?.value.toInt(),
            nse: ar.nse?.value.toBool(),
            priv: ar.priv?.value.toBool(),
            inst: ar.inst?.value.toBool(),
            pas: ar.pas?.value.toInt(),
          ),
          memAttr: Axi5MemoryAttributeSignalsStruct(
            cache: ar.cache?.value.toInt(),
            region: ar.region?.value.toInt(),
            mecId: ar.mecId?.value.toInt(),
          ),
          user: ar.user != null
              ? Axi5UserSignalsStruct(user: ar.user?.value.toInt())
              : null,
          id: ar.id != null
              ? Axi5IdSignalsStruct(
                  id: ar.id?.value.toInt(), idUnq: ar.idUnq?.value.toBool())
              : null,
          debug: Axi5DebugSignalsStruct(
              trace: ar.trace?.value.toBool(), loop: ar.loop?.value.toInt()),
          mmu: ar.mmuValid != null
              ? Axi5MmuSignalsStruct(
                  mmuValid: ar.mmuValid?.value.toBool(),
                  mmuSecSid: ar.mmuSecSid?.value.toInt(),
                  mmuSid: ar.mmuSid?.value.toInt(),
                  mmuSsidV: ar.mmuSsidV?.value.toBool(),
                  mmuSsid: ar.mmuSsid?.value.toInt(),
                  mmuAtSt: ar.mmuAtSt?.value.toBool(),
                  mmuFlow: ar.mmuFlow?.value.toInt(),
                  mmuPasUnknown: ar.mmuPasUnknown?.value.toBool(),
                  mmuPm: ar.mmuPm?.value.toBool(),
                )
              : null,
          qual: ar.nsaId != null
              ? Axi5QualifierSignalsStruct(
                  nsaId: ar.nsaId?.value.toInt(),
                  pbha: ar.pbha?.value.toInt(),
                  subSysId: ar.subSysId?.value.toInt(),
                  actV: ar.actV?.value.toBool(),
                  act: ar.act?.value.toInt(),
                )
              : null,
          atomic: ar.lock != null
              ? Axi5AtomicSignalsStruct(
                  lock: ar.lock?.value.toBool(),
                  atOp: ar.atOp?.value.toInt(),
                )
              : null,
          tag: ar.mpam != null
              ? Axi5MemPartTagSignalsStruct(
                  mpam: ar.mpam?.value.toInt(),
                  tagOp: ar.tagOp?.value.toInt(),
                )
              : null,
          chunk: ar.chunkEn != null
              ? Axi5ChunkSignalsStruct(
                  chunkEn: ar.chunkEn?.value.toBool(),
                  chunkV: ar.chunkV?.value.toBool(),
                  chunkNum: ar.chunkNum?.value.toInt(),
                  chunkStrb: ar.chunkStrb?.value.toInt(),
                )
              : null,
          opcode: ar.snoop != null
              ? Axi5OpcodeSignalsStruct(snoop: ar.snoop?.value.toInt())
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
            addr: aw.addr.value.toInt(),
            len: aw.len?.value.toInt(),
            size: aw.size?.value.toInt(),
            burst: aw.burst?.value.toInt(),
            qos: aw.qos?.value.toInt(),
          ),
          prot: Axi5ProtSignalsStruct(
            prot: aw.prot?.value.toInt(),
            nse: aw.nse?.value.toBool(),
            priv: aw.priv?.value.toBool(),
            inst: aw.inst?.value.toBool(),
            pas: aw.pas?.value.toInt(),
          ),
          memAttr: Axi5MemoryAttributeSignalsStruct(
            cache: aw.cache?.value.toInt(),
            region: aw.region?.value.toInt(),
            mecId: aw.mecId?.value.toInt(),
          ),
          user: aw.user != null
              ? Axi5UserSignalsStruct(user: aw.user?.value.toInt())
              : null,
          id: aw.id != null
              ? Axi5IdSignalsStruct(
                  id: aw.id?.value.toInt(), idUnq: aw.idUnq?.value.toBool())
              : null,
          debug: Axi5DebugSignalsStruct(
              trace: aw.trace?.value.toBool(), loop: aw.loop?.value.toInt()),
          mmu: aw.mmuValid != null
              ? Axi5MmuSignalsStruct(
                  mmuValid: aw.mmuValid?.value.toBool(),
                  mmuSecSid: aw.mmuSecSid?.value.toInt(),
                  mmuSid: aw.mmuSid?.value.toInt(),
                  mmuSsidV: aw.mmuSsidV?.value.toBool(),
                  mmuSsid: aw.mmuSsid?.value.toInt(),
                  mmuAtSt: aw.mmuAtSt?.value.toBool(),
                  mmuFlow: aw.mmuFlow?.value.toInt(),
                  mmuPasUnknown: aw.mmuPasUnknown?.value.toBool(),
                  mmuPm: aw.mmuPm?.value.toBool(),
                )
              : null,
          qual: aw.nsaId != null
              ? Axi5QualifierSignalsStruct(
                  nsaId: aw.nsaId?.value.toInt(),
                  pbha: aw.pbha?.value.toInt(),
                  subSysId: aw.subSysId?.value.toInt(),
                  actV: aw.actV?.value.toBool(),
                  act: aw.act?.value.toInt(),
                )
              : null,
          atomic: aw.lock != null
              ? Axi5AtomicSignalsStruct(
                  lock: aw.lock?.value.toBool(),
                  atOp: aw.atOp?.value.toInt(),
                )
              : null,
          tag: aw.mpam != null
              ? Axi5MemPartTagSignalsStruct(
                  mpam: aw.mpam?.value.toInt(),
                  tagOp: aw.tagOp?.value.toInt(),
                )
              : null,
          stash: aw.domain != null
              ? Axi5StashSignalsStruct(
                  domain: aw.domain?.value.toInt(),
                  stashNid: aw.stashNid?.value.toInt(),
                  stashNidEn: aw.stashNidEn?.value.toBool(),
                  stashLPid: aw.stashLPid?.value.toInt(),
                  stashLPidEn: aw.stashLPidEn?.value.toBool(),
                  cmo: aw.cmo?.value.toInt(),
                )
              : null,
          opcode: aw.snoop != null
              ? Axi5OpcodeSignalsStruct(snoop: aw.snoop?.value.toInt())
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
        final lastChk2 =
            !lastChk1 && (r.last!.value.isValid && r.last!.value.toBool());
        if (lastChk1 || lastChk2) {
          final dataPkts = <Axi5DataSignalsStruct>[];
          for (var i = 0; i < _dataBuffer.length; i++) {
            dataPkts.add(Axi5DataSignalsStruct(
              data: _dataBuffer[i].toInt(),
              last: i == dataPkts.length - 1,
              poison:
                  i < _poisonBuffer.length ? _poisonBuffer[i].toInt() : null,
            ));
          }
          add(Axi5RChannelPacket(
            data: dataPkts,
            id: r.id != null
                ? Axi5IdSignalsStruct(
                    id: r.id?.value.toInt(), idUnq: r.idUnq?.value.toBool())
                : null,
            tag: r.tag != null
                ? Axi5MemRespDataTagSignalsStruct(
                    tag: r.tag?.value.toInt(),
                    tagUpdate: r.tagUpdate?.value.toInt(),
                    tagMatch: r.tagMatch?.value.toInt(),
                    comp: r.comp?.value.toBool(),
                    persist: r.persist?.value.toBool(),
                  )
                : null,
            debug: Axi5DebugSignalsStruct(
                trace: r.trace?.value.toBool(), loop: r.loop?.value.toInt()),
            response: r.resp != null || r.busy != null
                ? Axi5ResponseSignalsStruct(
                    resp: r.resp?.value.toInt(), busy: r.busy?.value.toBool())
                : null,
            chunk: r.chunkEn != null
                ? Axi5ChunkSignalsStruct(
                    chunkEn: r.chunkEn?.value.toBool(),
                    chunkV: r.chunkV?.value.toBool(),
                    chunkNum: r.chunkNum?.value.toInt(),
                    chunkStrb: r.chunkStrb?.value.toInt(),
                  )
                : null,
            user: r.user != null
                ? Axi5UserSignalsStruct(user: r.user?.value.toInt())
                : null,
          ));
        }
      }
    });
  }
}

// TODO: handle multi data beats!!

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
        final lastChk2 =
            !lastChk1 && (w.last!.value.isValid && w.last!.value.toBool());
        if (lastChk1 || lastChk2) {
          final dataPkts = <Axi5DataSignalsStruct>[];
          for (var i = 0; i < _dataBuffer.length; i++) {
            dataPkts.add(Axi5DataSignalsStruct(
              data: _dataBuffer[i].toInt(),
              last: i == dataPkts.length - 1,
              strb: i < _strbBuffer.length ? _strbBuffer[i].toInt() : null,
              poison:
                  i < _poisonBuffer.length ? _poisonBuffer[i].toInt() : null,
            ));
          }

          add(Axi5WChannelPacket(
            data: dataPkts,
            tag: w.tag != null
                ? Axi5MemRespDataTagSignalsStruct(
                    tag: w.tag?.value.toInt(),
                    tagUpdate: w.tagUpdate?.value.toInt(),
                    tagMatch: w.tagMatch?.value.toInt(),
                    comp: w.comp?.value.toBool(),
                    persist: w.persist?.value.toBool(),
                  )
                : null,
            debug: Axi5DebugSignalsStruct(
                trace: w.trace?.value.toBool(), loop: w.loop?.value.toInt()),
            user: w.user != null
                ? Axi5UserSignalsStruct(user: w.user?.value.toInt())
                : null,
          ));
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
                  id: b.id?.value.toInt(), idUnq: b.idUnq?.value.toBool())
              : null,
          tag: b.tag != null
              ? Axi5MemRespDataTagSignalsStruct(
                  tag: b.tag?.value.toInt(),
                  tagUpdate: b.tagUpdate?.value.toInt(),
                  tagMatch: b.tagMatch?.value.toInt(),
                  comp: b.comp?.value.toBool(),
                  persist: b.persist?.value.toBool(),
                )
              : null,
          debug: Axi5DebugSignalsStruct(
              trace: b.trace?.value.toBool(), loop: b.loop?.value.toInt()),
          response: Axi5ResponseSignalsStruct(
              resp: b.resp?.value.toInt(), busy: b.busy?.value.toBool()),
          user: b.user != null
              ? Axi5UserSignalsStruct(user: b.user?.value.toInt())
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
          addr: ac.addr?.value.toInt() ?? 0,
          vmidExt: ac.vmidExt?.value.toInt() ?? 0,
          debug: Axi5DebugSignalsStruct(
            trace: ac.trace?.value.toBool(),
            loop: ac.loop?.value.toInt(),
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
            trace: cr.trace?.value.toBool(),
            loop: cr.loop?.value.toInt(),
          ),
        ));
      }
    });
  }
}
