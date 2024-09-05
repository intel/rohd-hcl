// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// main.dart
// Main entry point
//
// 2023 December

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confapp/app.dart';
import 'package:confapp/hcl_bloc_observer.dart';
// ignore: implementation_imports
import 'package:rohd_hcl/src/component_config/components/component_registry.dart';

void main() {
  /// Initializing the [BlocObserver] created and calling runApp
  Bloc.observer = const HCLBlocObserver();

  runApp(HCLApp(
    components: componentRegistry,
  ));
}
