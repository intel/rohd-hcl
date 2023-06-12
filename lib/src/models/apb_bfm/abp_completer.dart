// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_completer.dart
// A completer model for APB.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A model for the completer side of an [ApbInterface].
class ApbCompleter extends Component {
  /// The interface to drive.
  final ApbInterface intf;

  /// The index that this is listening to on the [intf].
  final int selectIndex;

  /// A function which returns the data for the requested address.
  final LogicValue Function(LogicValue addr) dataProvider;

  //TODO: why not use a memory storage?

  /// Creates a new model [ApbCompleter].
  ApbCompleter(
      {required this.intf,
      required this.dataProvider,
      required Component parent,
      this.selectIndex = 0,
      String name = 'apbCompleter'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    // intf.

    // wait for reset to complete
    await intf.resetN.nextPosedge;
  }
}
