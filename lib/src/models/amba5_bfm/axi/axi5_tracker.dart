// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_tracker.dart
// Monitors that watch the AXI5 interfaces.
//
// 2025 September
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A tracker for the AXI5 AW channel.
class Axi5AwChannelTracker extends Tracker<Axi5AwChannelPacket> {
  /// time
  static const timeField = 'time';

  /// id: Identification tag for transaction.
  static const idField = 'id';

  /// idUnq: Coherency barrier.
  static const idUnqField = 'idUnq';

  /// addr: The address of the first transfer in a transaction.
  static const addrField = 'addr';

  /// len: Length, the exact number of data transfers in a transaction.
  static const lenField = 'len';

  /// size: Size, the number of bytes in each data transfer in a transaction.
  static const sizeField = 'size';

  /// burst: Burst type, indicates how address changes between each transfer in a transaction.
  static const burstField = 'burst';

  /// qos: Quality of service identifier for a transaction.
  static const qosField = 'qos';

  /// prot: Protection attributes of a transaction.
  static const protField = 'prot';

  /// nse: Non-Secure Extension.
  static const nseField = 'nse';

  /// priv: Privileged versus unprivileged access.
  static const privField = 'priv';

  /// inst: Instruction versus data access.
  static const instField = 'inst';

  /// pas: Physical address space of transaction.
  static const pasField = 'pas';

  /// cache: Cache attributes.
  static const cacheField = 'cache';

  /// region: Region identifier.
  static const regionField = 'region';

  /// user: User extension.
  static const userField = 'user';

  /// domain: Domain for requests.
  static const domainField = 'domain';

  /// stashNid: Stash Node ID.
  static const stashNidField = 'stashNid';

  /// stashNidEn: Stash Node ID enable.
  static const stashNidEnField = 'stashNidEn';

  /// stashLPid: Stash Logical Processor ID.
  static const stashLPidField = 'stashLPid';

  /// stashLPidEn: Stash Logical Processor ID enable.
  static const stashLPidEnField = 'stashLPidEn';

  /// cmo: Cache maintenance operation.
  static const cmoField = 'cmo';

  /// opcode: Opcode for snoop requests.
  static const opcodeField = 'opcode';

  /// atomic: Atomic operation indicator.
  static const atomicField = 'atomic';

  /// tag: Tag identifier.
  static const tagField = 'tag';

  /// trace: Trace signal.
  static const traceField = 'trace';

  /// loop: Loopback signal.
  static const loopField = 'loop';

  /// mmuValid: MMU signal qualifier.
  static const mmuValidField = 'mmuValid';

  /// mmuSecSid: Secure stream ID.
  static const mmuSecSidField = 'mmuSecSid';

  /// mmuSid: Stream ID.
  static const mmuSidField = 'mmuSid';

  /// mmuSsidV: Substream ID valid.
  static const mmuSsidVField = 'mmuSsidV';

  /// mmuSsid: Substream ID.
  static const mmuSsidField = 'mmuSsid';

  /// mmuAtSt: Address translated indicator.
  static const mmuAtStField = 'mmuAtSt';

  /// mmuFlow: SMMU flow type.
  static const mmuFlowField = 'mmuFlow';

  /// mmuPasUnknown: Physical address space unknown.
  static const mmuPasUnknownField = 'mmuPasUnknown';

  /// mmuPm: Protected mode indicator.
  static const mmuPmField = 'mmuPm';

  /// nsaId: Non-secure access ID.
  static const nsaIdField = 'nsaId';

  /// pbha: Page based HW attributes.
  static const pbhaField = 'pbha';

  /// subSysId: Subsystem ID.
  static const subSysIdField = 'subSysId';

  /// actV: Arm Compression Technology valid.
  static const actVField = 'actV';

  /// act: Arm Compression Technology.
  static const actField = 'act';

  /// Constructor.
  Axi5AwChannelTracker({
    String name = 'Axi5AwChannelTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int idColumnWidth = 0,
    int idUnqColumnWidth = 0,
    int addrColumnWidth = 12,
    int lenColumnWidth = 12,
    int sizeColumnWidth = 0,
    int burstColumnWidth = 0,
    int qosColumnWidth = 0,
    int protColumnWidth = 4,
    int nseColumnWidth = 0,
    int privColumnWidth = 0,
    int instColumnWidth = 0,
    int pasColumnWidth = 0,
    int cacheColumnWidth = 0,
    int regionColumnWidth = 0,
    int userColumnWidth = 0,
    int domainColumnWidth = 0,
    int stashNidColumnWidth = 0,
    int stashNidEnColumnWidth = 0,
    int stashLPidColumnWidth = 0,
    int stashLPidEnColumnWidth = 0,
    int cmoColumnWidth = 0,
    int opcodeColumnWidth = 0,
    int atomicColumnWidth = 0,
    int tagColumnWidth = 0,
    int traceColumnWidth = 0,
    int loopColumnWidth = 0,
    int mmuValidColumnWidth = 0,
    int mmuSecSidColumnWidth = 0,
    int mmuSidColumnWidth = 0,
    int mmuSsidVColumnWidth = 0,
    int mmuSsidColumnWidth = 0,
    int mmuAtStColumnWidth = 0,
    int mmuFlowColumnWidth = 0,
    int mmuPasUnknownColumnWidth = 0,
    int mmuPmColumnWidth = 0,
    int nsaIdColumnWidth = 0,
    int pbhaColumnWidth = 0,
    int subSysIdColumnWidth = 0,
    int actVColumnWidth = 0,
    int actColumnWidth = 0,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          if (idColumnWidth > 0)
            TrackerField(idField, columnWidth: idColumnWidth),
          if (idUnqColumnWidth > 0)
            TrackerField(idUnqField, columnWidth: idUnqColumnWidth),
          TrackerField(addrField, columnWidth: addrColumnWidth),
          if (lenColumnWidth > 0)
            TrackerField(lenField, columnWidth: lenColumnWidth),
          if (sizeColumnWidth > 0)
            TrackerField(sizeField, columnWidth: sizeColumnWidth),
          if (burstColumnWidth > 0)
            TrackerField(burstField, columnWidth: burstColumnWidth),
          if (qosColumnWidth > 0)
            TrackerField(qosField, columnWidth: qosColumnWidth),
          TrackerField(protField, columnWidth: protColumnWidth),
          if (nseColumnWidth > 0)
            TrackerField(nseField, columnWidth: nseColumnWidth),
          if (privColumnWidth > 0)
            TrackerField(privField, columnWidth: privColumnWidth),
          if (instColumnWidth > 0)
            TrackerField(instField, columnWidth: instColumnWidth),
          if (pasColumnWidth > 0)
            TrackerField(pasField, columnWidth: pasColumnWidth),
          if (cacheColumnWidth > 0)
            TrackerField(cacheField, columnWidth: cacheColumnWidth),
          if (regionColumnWidth > 0)
            TrackerField(regionField, columnWidth: regionColumnWidth),
          if (userColumnWidth > 0)
            TrackerField(userField, columnWidth: userColumnWidth),
          if (domainColumnWidth > 0)
            TrackerField(domainField, columnWidth: domainColumnWidth),
          if (stashNidColumnWidth > 0)
            TrackerField(stashNidField, columnWidth: stashNidColumnWidth),
          if (stashNidEnColumnWidth > 0)
            TrackerField(stashNidEnField, columnWidth: stashNidEnColumnWidth),
          if (stashLPidColumnWidth > 0)
            TrackerField(stashLPidField, columnWidth: stashLPidColumnWidth),
          if (stashLPidEnColumnWidth > 0)
            TrackerField(stashLPidEnField, columnWidth: stashLPidEnColumnWidth),
          if (cmoColumnWidth > 0)
            TrackerField(cmoField, columnWidth: cmoColumnWidth),
          if (opcodeColumnWidth > 0)
            TrackerField(opcodeField, columnWidth: opcodeColumnWidth),
          if (atomicColumnWidth > 0)
            TrackerField(atomicField, columnWidth: atomicColumnWidth),
          if (tagColumnWidth > 0)
            TrackerField(tagField, columnWidth: tagColumnWidth),
          if (traceColumnWidth > 0)
            TrackerField(traceField, columnWidth: traceColumnWidth),
          if (loopColumnWidth > 0)
            TrackerField(loopField, columnWidth: loopColumnWidth),
          if (mmuValidColumnWidth > 0)
            TrackerField(mmuValidField, columnWidth: mmuValidColumnWidth),
          if (mmuSecSidColumnWidth > 0)
            TrackerField(mmuSecSidField, columnWidth: mmuSecSidColumnWidth),
          if (mmuSidColumnWidth > 0)
            TrackerField(mmuSidField, columnWidth: mmuSidColumnWidth),
          if (mmuSsidVColumnWidth > 0)
            TrackerField(mmuSsidVField, columnWidth: mmuSsidVColumnWidth),
          if (mmuSsidColumnWidth > 0)
            TrackerField(mmuSsidField, columnWidth: mmuSsidColumnWidth),
          if (mmuAtStColumnWidth > 0)
            TrackerField(mmuAtStField, columnWidth: mmuAtStColumnWidth),
          if (mmuFlowColumnWidth > 0)
            TrackerField(mmuFlowField, columnWidth: mmuFlowColumnWidth),
          if (mmuPasUnknownColumnWidth > 0)
            TrackerField(mmuPasUnknownField,
                columnWidth: mmuPasUnknownColumnWidth),
          if (mmuPmColumnWidth > 0)
            TrackerField(mmuPmField, columnWidth: mmuPmColumnWidth),
          if (nsaIdColumnWidth > 0)
            TrackerField(nsaIdField, columnWidth: nsaIdColumnWidth),
          if (pbhaColumnWidth > 0)
            TrackerField(pbhaField, columnWidth: pbhaColumnWidth),
          if (subSysIdColumnWidth > 0)
            TrackerField(subSysIdField, columnWidth: subSysIdColumnWidth),
          if (actVColumnWidth > 0)
            TrackerField(actVField, columnWidth: actVColumnWidth),
          if (actColumnWidth > 0)
            TrackerField(actField, columnWidth: actColumnWidth),
        ]);
}

/// A tracker for the AXI5 AR channel.
class Axi5ArChannelTracker extends Tracker<Axi5ArChannelPacket> {
  /// time
  static const timeField = 'time';

  /// idField
  static const idField = 'id';

  /// idUnqField
  static const idUnqField = 'idUnq';

  /// addrField
  static const addrField = 'addr';

  /// lenField
  static const lenField = 'len';

  /// sizeField
  static const sizeField = 'size';

  /// burstField
  static const burstField = 'burst';

  /// protField
  static const protField = 'prot';

  /// nseField
  static const nseField = 'nse';

  /// privField
  static const privField = 'priv';

  /// instField
  static const instField = 'inst';

  /// pasField
  static const pasField = 'pas';

  /// cacheField
  static const cacheField = 'cache';

  /// regionField
  static const regionField = 'region';

  /// mecIdField
  static const mecIdField = 'mecId';

  /// qosField
  static const qosField = 'qos';

  /// userField
  static const userField = 'user';

  /// domainField
  static const domainField = 'domain';

  /// opcodeField
  static const opcodeField = 'opcode';

  /// atomicField
  static const atomicField = 'atomic';

  /// tagField
  static const tagField = 'tag';

  /// tagUpdateField
  static const tagUpdateField = 'tagUpdate';

  /// tagMatchField
  static const tagMatchField = 'tagMatch';

  /// compField
  static const compField = 'comp';

  /// persistField
  static const persistField = 'persist';

  /// traceField
  static const traceField = 'trace';

  /// loopField
  static const loopField = 'loop';

  /// mmuValidField
  static const mmuValidField = 'mmuValid';

  /// qualField
  static const qualField = 'qual';

  /// chunkEnField
  static const chunkEnField = 'chunkEn';

  /// chunkVField
  static const chunkVField = 'chunkV';

  /// chunkNumField
  static const chunkNumField = 'chunkNum';

  /// chunkStrbField
  static const chunkStrbField = 'chunkStrb';

  /// Constructor.
  Axi5ArChannelTracker({
    String name = 'Axi5ArChannelTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int idColumnWidth = 0,
    int idUnqColumnWidth = 0,
    int addrColumnWidth = 12,
    int lenColumnWidth = 12,
    int sizeColumnWidth = 0,
    int burstColumnWidth = 0,
    int protColumnWidth = 4,
    int nseColumnWidth = 0,
    int privColumnWidth = 0,
    int instColumnWidth = 0,
    int pasColumnWidth = 0,
    int cacheColumnWidth = 0,
    int regionColumnWidth = 0,
    int mecIdColumnWidth = 0,
    int qosColumnWidth = 0,
    int userColumnWidth = 0,
    int domainColumnWidth = 0,
    int opcodeColumnWidth = 0,
    int atomicColumnWidth = 0,
    int tagColumnWidth = 0,
    int tagUpdateColumnWidth = 0,
    int tagMatchColumnWidth = 0,
    int compColumnWidth = 0,
    int persistColumnWidth = 0,
    int traceColumnWidth = 0,
    int loopColumnWidth = 0,
    int mmuValidColumnWidth = 0,
    int qualColumnWidth = 0,
    int chunkEnColumnWidth = 0,
    int chunkVColumnWidth = 0,
    int chunkNumColumnWidth = 0,
    int chunkStrbColumnWidth = 0,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          if (idColumnWidth > 0)
            TrackerField(idField, columnWidth: idColumnWidth),
          if (idUnqColumnWidth > 0)
            TrackerField(idUnqField, columnWidth: idUnqColumnWidth),
          if (addrColumnWidth > 0)
            TrackerField(addrField, columnWidth: addrColumnWidth),
          if (lenColumnWidth > 0)
            TrackerField(lenField, columnWidth: lenColumnWidth),
          if (sizeColumnWidth > 0)
            TrackerField(sizeField, columnWidth: sizeColumnWidth),
          if (burstColumnWidth > 0)
            TrackerField(burstField, columnWidth: burstColumnWidth),
          if (protColumnWidth > 0)
            TrackerField(protField, columnWidth: protColumnWidth),
          if (nseColumnWidth > 0)
            TrackerField(nseField, columnWidth: nseColumnWidth),
          if (privColumnWidth > 0)
            TrackerField(privField, columnWidth: privColumnWidth),
          if (instColumnWidth > 0)
            TrackerField(instField, columnWidth: instColumnWidth),
          if (pasColumnWidth > 0)
            TrackerField(pasField, columnWidth: pasColumnWidth),
          if (cacheColumnWidth > 0)
            TrackerField(cacheField, columnWidth: cacheColumnWidth),
          if (regionColumnWidth > 0)
            TrackerField(regionField, columnWidth: regionColumnWidth),
          if (mecIdColumnWidth > 0)
            TrackerField(mecIdField, columnWidth: mecIdColumnWidth),
          if (qosColumnWidth > 0)
            TrackerField(qosField, columnWidth: qosColumnWidth),
          if (userColumnWidth > 0)
            TrackerField(userField, columnWidth: userColumnWidth),
          if (domainColumnWidth > 0)
            TrackerField(domainField, columnWidth: domainColumnWidth),
          if (opcodeColumnWidth > 0)
            TrackerField(opcodeField, columnWidth: opcodeColumnWidth),
          if (atomicColumnWidth > 0)
            TrackerField(atomicField, columnWidth: atomicColumnWidth),
          if (tagColumnWidth > 0)
            TrackerField(tagField, columnWidth: tagColumnWidth),
          if (tagUpdateColumnWidth > 0)
            TrackerField(tagUpdateField, columnWidth: tagUpdateColumnWidth),
          if (tagMatchColumnWidth > 0)
            TrackerField(tagMatchField, columnWidth: tagMatchColumnWidth),
          if (compColumnWidth > 0)
            TrackerField(compField, columnWidth: compColumnWidth),
          if (persistColumnWidth > 0)
            TrackerField(persistField, columnWidth: persistColumnWidth),
          if (traceColumnWidth > 0)
            TrackerField(traceField, columnWidth: traceColumnWidth),
          if (loopColumnWidth > 0)
            TrackerField(loopField, columnWidth: loopColumnWidth),
          if (mmuValidColumnWidth > 0)
            TrackerField(mmuValidField, columnWidth: mmuValidColumnWidth),
          if (qualColumnWidth > 0)
            TrackerField(qualField, columnWidth: qualColumnWidth),
          if (chunkEnColumnWidth > 0)
            TrackerField(chunkEnField, columnWidth: chunkEnColumnWidth),
          if (chunkVColumnWidth > 0)
            TrackerField(chunkVField, columnWidth: chunkVColumnWidth),
          if (chunkNumColumnWidth > 0)
            TrackerField(chunkNumField, columnWidth: chunkNumColumnWidth),
          if (chunkStrbColumnWidth > 0)
            TrackerField(chunkStrbField, columnWidth: chunkStrbColumnWidth),
        ]);
}

/// A tracker for the AXI5 W channel.
class Axi5WChannelTracker extends Tracker<Axi5WChannelPacket> {
  /// time
  static const timeField = 'time';

  /// dataField
  static const dataField = 'data';

  /// lastField
  static const lastField = 'last';

  /// strbField
  static const strbField = 'strb';

  /// poisonField
  static const poisonField = 'poison';

  /// tagField
  static const tagField = 'tag';

  /// tagUpdateField
  static const tagUpdateField = 'tagUpdate';

  /// tagMatchField
  static const tagMatchField = 'tagMatch';

  /// compField
  static const compField = 'comp';

  /// persistField
  static const persistField = 'persist';

  /// traceField
  static const traceField = 'trace';

  /// loopField
  static const loopField = 'loop';

  /// userField
  static const userField = 'user';

  /// Constructor.
  Axi5WChannelTracker({
    String name = 'Axi5WChannelTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int dataColumnWidth = 64,
    int lastColumnWidth = 0,
    int strbColumnWidth = 0,
    int poisonColumnWidth = 0,
    int tagColumnWidth = 0,
    int tagUpdateColumnWidth = 0,
    int tagMatchColumnWidth = 0,
    int compColumnWidth = 0,
    int persistColumnWidth = 0,
    int traceColumnWidth = 0,
    int loopColumnWidth = 0,
    int userColumnWidth = 0,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          if (dataColumnWidth > 0)
            TrackerField(dataField, columnWidth: dataColumnWidth),
          if (lastColumnWidth > 0)
            TrackerField(lastField, columnWidth: lastColumnWidth),
          if (strbColumnWidth > 0)
            TrackerField(strbField, columnWidth: strbColumnWidth),
          if (poisonColumnWidth > 0)
            TrackerField(poisonField, columnWidth: poisonColumnWidth),
          if (tagColumnWidth > 0)
            TrackerField(tagField, columnWidth: tagColumnWidth),
          if (tagUpdateColumnWidth > 0)
            TrackerField(tagUpdateField, columnWidth: tagUpdateColumnWidth),
          if (tagMatchColumnWidth > 0)
            TrackerField(tagMatchField, columnWidth: tagMatchColumnWidth),
          if (compColumnWidth > 0)
            TrackerField(compField, columnWidth: compColumnWidth),
          if (persistColumnWidth > 0)
            TrackerField(persistField, columnWidth: persistColumnWidth),
          if (traceColumnWidth > 0)
            TrackerField(traceField, columnWidth: traceColumnWidth),
          if (loopColumnWidth > 0)
            TrackerField(loopField, columnWidth: loopColumnWidth),
          if (userColumnWidth > 0)
            TrackerField(userField, columnWidth: userColumnWidth),
        ]);
}

/// A tracker for the AXI5 R channel.
class Axi5RChannelTracker extends Tracker<Axi5RChannelPacket> {
  /// timeField
  static const timeField = 'time';

  /// userField
  static const userField = 'user';

  /// dataField
  static const dataField = 'data';

  /// lastField
  static const lastField = 'last';

  /// strbField
  static const strbField = 'strb';

  /// poisonField
  static const poisonField = 'poison';

  /// idField
  static const idField = 'id';

  /// idUnqField
  static const idUnqField = 'idUnq';

  /// tagField
  static const tagField = 'tag';

  /// tagUpdateField
  static const tagUpdateField = 'tagUpdate';

  /// tagMatchField
  static const tagMatchField = 'tagMatch';

  /// compField
  static const compField = 'comp';

  /// persistField
  static const persistField = 'persist';

  /// traceField
  static const traceField = 'trace';

  /// loopField
  static const loopField = 'loop';

  /// chunkEnField
  static const chunkEnField = 'chunkEn';

  /// chunkVField
  static const chunkVField = 'chunkV';

  /// chunkNumField
  static const chunkNumField = 'chunkNum';

  /// chunkStrbField
  static const chunkStrbField = 'chunkStrb';

  /// respField
  static const respField = 'resp';

  /// busyField
  static const busyField = 'busy';

  /// Constructor.
  Axi5RChannelTracker({
    String name = 'Axi5RChannelTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int userColumnWidth = 0,
    int dataColumnWidth = 64,
    int lastColumnWidth = 0,
    int strbColumnWidth = 0,
    int poisonColumnWidth = 0,
    int idColumnWidth = 0,
    int idUnqColumnWidth = 0,
    int tagColumnWidth = 0,
    int tagUpdateColumnWidth = 0,
    int tagMatchColumnWidth = 0,
    int compColumnWidth = 0,
    int persistColumnWidth = 0,
    int traceColumnWidth = 0,
    int loopColumnWidth = 0,
    int chunkEnColumnWidth = 0,
    int chunkVColumnWidth = 0,
    int chunkNumColumnWidth = 0,
    int chunkStrbColumnWidth = 0,
    int respColumnWidth = 0,
    int busyColumnWidth = 0,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          if (userColumnWidth > 0)
            TrackerField(userField, columnWidth: userColumnWidth),
          if (dataColumnWidth > 0)
            TrackerField(dataField, columnWidth: dataColumnWidth),
          if (lastColumnWidth > 0)
            TrackerField(lastField, columnWidth: lastColumnWidth),
          if (strbColumnWidth > 0)
            TrackerField(strbField, columnWidth: strbColumnWidth),
          if (poisonColumnWidth > 0)
            TrackerField(poisonField, columnWidth: poisonColumnWidth),
          if (idColumnWidth > 0)
            TrackerField(idField, columnWidth: idColumnWidth),
          if (idUnqColumnWidth > 0)
            TrackerField(idUnqField, columnWidth: idUnqColumnWidth),
          if (tagColumnWidth > 0)
            TrackerField(tagField, columnWidth: tagColumnWidth),
          if (tagUpdateColumnWidth > 0)
            TrackerField(tagUpdateField, columnWidth: tagUpdateColumnWidth),
          if (tagMatchColumnWidth > 0)
            TrackerField(tagMatchField, columnWidth: tagMatchColumnWidth),
          if (compColumnWidth > 0)
            TrackerField(compField, columnWidth: compColumnWidth),
          if (persistColumnWidth > 0)
            TrackerField(persistField, columnWidth: persistColumnWidth),
          if (traceColumnWidth > 0)
            TrackerField(traceField, columnWidth: traceColumnWidth),
          if (loopColumnWidth > 0)
            TrackerField(loopField, columnWidth: loopColumnWidth),
          if (chunkEnColumnWidth > 0)
            TrackerField(chunkEnField, columnWidth: chunkEnColumnWidth),
          if (chunkVColumnWidth > 0)
            TrackerField(chunkVField, columnWidth: chunkVColumnWidth),
          if (chunkNumColumnWidth > 0)
            TrackerField(chunkNumField, columnWidth: chunkNumColumnWidth),
          if (chunkStrbColumnWidth > 0)
            TrackerField(chunkStrbField, columnWidth: chunkStrbColumnWidth),
          if (respColumnWidth > 0)
            TrackerField(respField, columnWidth: respColumnWidth),
          if (busyColumnWidth > 0)
            TrackerField(busyField, columnWidth: busyColumnWidth),
        ]);
}

/// A tracker for the AXI5 B channel.
class Axi5BChannelTracker extends Tracker<Axi5BChannelPacket> {
  /// time
  static const timeField = 'time';

  /// user
  static const userField = 'user';

  /// id
  static const idField = 'id';

  /// idUnq
  static const idUnqField = 'idUnq';

  /// tag
  static const tagField = 'tag';

  /// tagUpdate
  static const tagUpdateField = 'tagUpdate';

  /// tagMatch
  static const tagMatchField = 'tagMatch';

  /// comp
  static const compField = 'comp';

  /// persist
  static const persistField = 'persist';

  /// trace
  static const traceField = 'trace';

  /// loop
  static const loopField = 'loop';

  /// resp
  static const respField = 'resp';

  /// busy
  static const busyField = 'busy';

  /// Constructor.
  Axi5BChannelTracker({
    String name = 'Axi5BChannelTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int userColumnWidth = 0,
    int idColumnWidth = 0,
    int idUnqColumnWidth = 0,
    int tagColumnWidth = 0,
    int tagUpdateColumnWidth = 0,
    int tagMatchColumnWidth = 0,
    int compColumnWidth = 0,
    int persistColumnWidth = 0,
    int traceColumnWidth = 0,
    int loopColumnWidth = 0,
    int respColumnWidth = 0,
    int busyColumnWidth = 0,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          if (userColumnWidth > 0)
            TrackerField(userField, columnWidth: userColumnWidth),
          if (idColumnWidth > 0)
            TrackerField(idField, columnWidth: idColumnWidth),
          if (idUnqColumnWidth > 0)
            TrackerField(idUnqField, columnWidth: idUnqColumnWidth),
          if (tagColumnWidth > 0)
            TrackerField(tagField, columnWidth: tagColumnWidth),
          if (tagUpdateColumnWidth > 0)
            TrackerField(tagUpdateField, columnWidth: tagUpdateColumnWidth),
          if (tagMatchColumnWidth > 0)
            TrackerField(tagMatchField, columnWidth: tagMatchColumnWidth),
          if (compColumnWidth > 0)
            TrackerField(compField, columnWidth: compColumnWidth),
          if (persistColumnWidth > 0)
            TrackerField(persistField, columnWidth: persistColumnWidth),
          if (traceColumnWidth > 0)
            TrackerField(traceField, columnWidth: traceColumnWidth),
          if (loopColumnWidth > 0)
            TrackerField(loopField, columnWidth: loopColumnWidth),
          if (respColumnWidth > 0)
            TrackerField(respField, columnWidth: respColumnWidth),
          if (busyColumnWidth > 0)
            TrackerField(busyField, columnWidth: busyColumnWidth),
        ]);
}

/// A tracker for the AXI5 AC channel.
class Axi5AcChannelTracker extends Tracker<Axi5AcChannelPacket> {
  /// trace
  static const traceField = 'trace';

  /// loop
  static const loopField = 'loop';

  /// time
  static const timeField = 'time';

  /// Constructor.
  Axi5AcChannelTracker({
    String name = 'Axi5AcChannelTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int traceColumnWidth = 0,
    int loopColumnWidth = 0,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          if (traceColumnWidth > 0)
            TrackerField(traceField, columnWidth: traceColumnWidth),
          if (loopColumnWidth > 0)
            TrackerField(loopField, columnWidth: loopColumnWidth),
        ]);
}

/// A tracker for the AXI5 CR channel.
class Axi5CrChannelTracker extends Tracker<Axi5CrChannelPacket> {
  /// time
  static const timeField = 'time';

  /// trace
  static const traceField = 'trace';

  /// loop
  static const loopField = 'loop';

  /// Constructor.
  Axi5CrChannelTracker({
    String name = 'Axi5CrChannelTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int traceColumnWidth = 0,
    int loopColumnWidth = 0,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          if (traceColumnWidth > 0)
            TrackerField(traceField, columnWidth: traceColumnWidth),
          if (loopColumnWidth > 0)
            TrackerField(loopField, columnWidth: loopColumnWidth),
        ]);
}
