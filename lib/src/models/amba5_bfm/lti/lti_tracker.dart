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

/// Tracker for the LTI LA channel.
class LtiLaChannelTracker extends Tracker<LtiLaChannelPacket> {
  /// time
  static const timeField = 'time';

  /// addrField
  static const addrField = 'addrField';

  /// userField
  static const userField = 'userField';

  /// idField
  static const idField = 'idField';

  /// nseField
  static const nseField = 'nseField';

  /// privField
  static const privField = 'privField';

  /// instField
  static const instField = 'instField';

  /// pasField
  static const pasField = 'pasField';

  /// mmuValidField
  static const mmuValidField = 'mmuValidField';

  /// mmuSecSidField
  static const mmuSecSidField = 'mmuSecSidField';

  /// mmuSidField
  static const mmuSidField = 'mmuSidField';

  /// mmuSsidVField
  static const mmuSsidVField = 'mmuSsidVField';

  /// mmuSsidField
  static const mmuSsidField = 'mmuSsidField';

  /// mmuAtStField
  static const mmuAtStField = 'mmuAtStField';

  /// mmuFlowField
  static const mmuFlowField = 'mmuFlowField';

  /// mmuPasUnknownField
  static const mmuPasUnknownField = 'mmuPasUnknownField';

  /// mmuPmField
  static const mmuPmField = 'mmuPmField';

  /// loopField
  static const loopField = 'loopField';

  /// og
  static const ogField = 'og';

  /// tlBlock
  static const tlBlockField = 'tlBlock';

  /// ident
  static const identField = 'ident';

  /// ogV
  static const ogVField = 'ogV';

  /// trans
  static const transField = 'trans';

  /// attr
  static const attrField = 'attr';

  /// vc
  static const vcField = 'vc';

  /// Constructor.
  LtiLaChannelTracker({
    String name = 'LtiLaChannelTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int addrColumnWidth = 12,
    int userColumnWidth = 8,
    int idColumnWidth = 8,
    int nseColumnWidth = 6,
    int privColumnWidth = 6,
    int instColumnWidth = 6,
    int pasColumnWidth = 6,
    int mmuValidColumnWidth = 6,
    int mmuSecSidColumnWidth = 8,
    int mmuSidColumnWidth = 8,
    int mmuSsidVColumnWidth = 8,
    int mmuSsidColumnWidth = 8,
    int mmuAtStColumnWidth = 8,
    int mmuFlowColumnWidth = 8,
    int mmuPasUnknownColumnWidth = 8,
    int mmuPmColumnWidth = 8,
    int loopColumnWidth = 6,
    int ogColumnWidth = 8,
    int tlBlockColumnWidth = 8,
    int identColumnWidth = 8,
    int ogVColumnWidth = 1,
    int transColumnWidth = 8,
    int attrColumnWidth = 8,
    int vcColumnWidth = 4,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          if (addrColumnWidth > 0)
            TrackerField(addrField, columnWidth: addrColumnWidth),
          if (userColumnWidth > 0)
            TrackerField(userField, columnWidth: userColumnWidth),
          if (idColumnWidth > 0)
            TrackerField(idField, columnWidth: idColumnWidth),
          if (nseColumnWidth > 0)
            TrackerField(nseField, columnWidth: nseColumnWidth),
          if (privColumnWidth > 0)
            TrackerField(privField, columnWidth: privColumnWidth),
          if (instColumnWidth > 0)
            TrackerField(instField, columnWidth: instColumnWidth),
          if (pasColumnWidth > 0)
            TrackerField(pasField, columnWidth: pasColumnWidth),
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
          if (loopColumnWidth > 0)
            TrackerField(loopField, columnWidth: loopColumnWidth),
          if (ogColumnWidth > 0)
            TrackerField(ogField, columnWidth: ogColumnWidth),
          if (tlBlockColumnWidth > 0)
            TrackerField(tlBlockField, columnWidth: tlBlockColumnWidth),
          if (identColumnWidth > 0)
            TrackerField(identField, columnWidth: identColumnWidth),
          if (ogVColumnWidth > 0)
            TrackerField(ogVField, columnWidth: ogVColumnWidth),
          if (transColumnWidth > 0)
            TrackerField(transField, columnWidth: transColumnWidth),
          if (attrColumnWidth > 0)
            TrackerField(attrField, columnWidth: attrColumnWidth),
          if (vcColumnWidth > 0)
            TrackerField(vcField, columnWidth: vcColumnWidth),
        ]);
}

/// Tracker for the LTI LR channel.
class LtiLrChannelTracker extends Tracker<LtiLrChannelPacket> {
  /// time
  static const timeField = 'time';

  /// addr
  static const addrField = 'addr';

  /// trans
  static const transField = 'trans';

  /// attr
  static const attrField = 'attr';

  /// user
  static const userField = 'user';

  /// id
  static const idField = 'id';

  /// nse
  static const nseField = 'nse';

  /// priv
  static const privField = 'priv';

  /// inst
  static const instField = 'inst';

  /// pas
  static const pasField = 'pas';

  /// trace
  static const traceField = 'trace';

  /// loop
  static const loopField = 'loop';

  /// resp
  static const respField = 'resp';

  /// mecId
  static const mecIdField = 'mecId';

  /// mpam
  static const mpamField = 'mpam';

  /// ctag
  static const ctagField = 'ctag';

  /// hwAttr
  static const hwAttrField = 'hwAttr';

  /// size
  static const sizeField = 'size';

  /// vc
  static const vcField = 'vc';

  /// Constructor.
  LtiLrChannelTracker({
    String name = 'LtiLrChannelTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int addrColumnWidth = 12,
    int transColumnWidth = 8,
    int attrColumnWidth = 8,
    int userColumnWidth = 8,
    int idColumnWidth = 8,
    int nseColumnWidth = 6,
    int privColumnWidth = 6,
    int instColumnWidth = 6,
    int pasColumnWidth = 6,
    int traceColumnWidth = 6,
    int loopColumnWidth = 6,
    int respColumnWidth = 6,
    int mecIdColumnWidth = 8,
    int mpamColumnWidth = 8,
    int ctagColumnWidth = 8,
    int hwAttrColumnWidth = 8,
    int sizeColumnWidth = 8,
    int vcColumnWidth = 4,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          if (addrColumnWidth > 0)
            TrackerField(addrField, columnWidth: addrColumnWidth),
          if (transColumnWidth > 0)
            TrackerField(transField, columnWidth: transColumnWidth),
          if (attrColumnWidth > 0)
            TrackerField(attrField, columnWidth: attrColumnWidth),
          if (userColumnWidth > 0)
            TrackerField(userField, columnWidth: userColumnWidth),
          if (idColumnWidth > 0)
            TrackerField(idField, columnWidth: idColumnWidth),
          if (nseColumnWidth > 0)
            TrackerField(nseField, columnWidth: nseColumnWidth),
          if (privColumnWidth > 0)
            TrackerField(privField, columnWidth: privColumnWidth),
          if (instColumnWidth > 0)
            TrackerField(instField, columnWidth: instColumnWidth),
          if (pasColumnWidth > 0)
            TrackerField(pasField, columnWidth: pasColumnWidth),
          if (traceColumnWidth > 0)
            TrackerField(traceField, columnWidth: traceColumnWidth),
          if (loopColumnWidth > 0)
            TrackerField(loopField, columnWidth: loopColumnWidth),
          if (respColumnWidth > 0)
            TrackerField(respField, columnWidth: respColumnWidth),
          if (mecIdColumnWidth > 0)
            TrackerField(mecIdField, columnWidth: mecIdColumnWidth),
          if (mpamColumnWidth > 0)
            TrackerField(mpamField, columnWidth: mpamColumnWidth),
          if (ctagColumnWidth > 0)
            TrackerField(ctagField, columnWidth: ctagColumnWidth),
          if (hwAttrColumnWidth > 0)
            TrackerField(hwAttrField, columnWidth: hwAttrColumnWidth),
          if (sizeColumnWidth > 0)
            TrackerField(sizeField, columnWidth: sizeColumnWidth),
          if (vcColumnWidth > 0)
            TrackerField(vcField, columnWidth: vcColumnWidth),
        ]);
}

/// Tracker for the LTI LC channel.
class LtiLcChannelTracker extends Tracker<LtiLcChannelPacket> {
  /// time
  static const timeField = 'time';

  /// addr
  static const addrField = 'addr';

  /// user
  static const userField = 'user';

  /// tag
  static const tagField = 'tag';

  /// Constructor.
  LtiLcChannelTracker({
    String name = 'LtiLcChannelTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int addrColumnWidth = 12,
    int userColumnWidth = 8,
    int tagColumnWidth = 8,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          if (addrColumnWidth > 0)
            TrackerField(addrField, columnWidth: addrColumnWidth),
          if (userColumnWidth > 0)
            TrackerField(userField, columnWidth: userColumnWidth),
          if (tagColumnWidth > 0)
            TrackerField(tagField, columnWidth: tagColumnWidth),
        ]);
}

/// Tracker for the LTI LT channel.
class LtiLtChannelTracker extends Tracker<LtiLtChannelPacket> {
  /// time
  static const timeField = 'time';

  /// addr
  static const addrField = 'addr';

  /// user
  static const userField = 'user';

  /// tag
  static const tagField = 'tag';

  /// Constructor.
  LtiLtChannelTracker({
    String name = 'LtiLtChannelTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int addrColumnWidth = 12,
    int userColumnWidth = 8,
    int tagColumnWidth = 8,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          if (addrColumnWidth > 0)
            TrackerField(addrField, columnWidth: addrColumnWidth),
          if (userColumnWidth > 0)
            TrackerField(userField, columnWidth: userColumnWidth),
          if (tagColumnWidth > 0)
            TrackerField(tagField, columnWidth: tagColumnWidth),
        ]);
}
