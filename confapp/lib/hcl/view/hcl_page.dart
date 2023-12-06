// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// hcl_page.dart
// Main page for the app
//
// 2023 December

import 'package:confapp/hcl/cubit/system_verilog_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confapp/hcl/cubit/component_cubit.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'hcl_view.dart';

class HCLPage extends StatelessWidget {
  final List<Configurator> components;

  /// {@macro counter_page}
  const HCLPage({super.key, required this.components});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          // Look pretty ungly using static, not sure how to improve this
          create: (BuildContext context) => ComponentCubit(components),
        ),
        BlocProvider(
          create: (BuildContext context) => SystemVerilogCubit(),
        ),
      ],
      child: const HCLView(),
    );
  }
}
