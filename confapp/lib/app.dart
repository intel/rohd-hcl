// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// app.dart
// Main app
//
// 2023 December

import 'package:flutter/material.dart';
import 'package:confapp/hcl/hcl.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

class HCLApp extends MaterialApp {
  HCLApp({super.key, required List<Configurator> components})
      : super(
            home: HCLPage(
          components: components,
        ));
}
