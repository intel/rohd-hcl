// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// hcl_page.dart
// Main page for the app
//
// 2023 December

import 'package:confapp/hcl/cubit/component_cubit.dart';
import 'package:confapp/hcl/cubit/system_verilog_cubit.dart';
import 'package:confapp/hcl/cubit/theme_cubit.dart';
import 'package:confapp/hcl/view/hcl_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Provides the state controllers needed by the configuration application.
class HCLPage extends StatelessWidget {
  /// The components available to configure.
  final List<Configurator> components;

  /// Creates the configuration page for [components].
  const HCLPage({required this.components, super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider(
            // Look pretty ungly using static, not sure how to improve this
            create: (context) => ComponentCubit(components),
          ),
          BlocProvider(
            create: (context) => SystemVerilogCubit(),
          ),
          BlocProvider(
            create: (context) => ThemeCubit(),
          ),
        ],
        child: const HCLView(),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<Configurator>('components', components));
  }
}
