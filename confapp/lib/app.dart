// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// app.dart
// Main app
//
// 2023 December

import 'package:confapp/hcl/hcl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// The ROHD-HCL Configuration App root widget.
class HCLApp extends MaterialApp {
  /// Creates the app with the selectable component [components].
  HCLApp({required List<Configurator> components, super.key})
      : super(
            home: HCLPage(
          components: components,
        ));
}
