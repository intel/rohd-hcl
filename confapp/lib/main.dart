// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// main.dart
// Main entry point
//
// 2023 December

import 'package:confapp/app.dart';
import 'package:confapp/hcl_bloc_observer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// The component registry is intentionally not part of the package's public API.
// ignore: implementation_imports
import 'package:rohd_hcl/src/component_config/components/component_registry.dart';

void main() {
  /// Initializing the [BlocObserver] created and calling runApp
  Bloc.observer = const HCLBlocObserver();

  runApp(HCLApp(
    components: componentRegistry,
  ));
}
