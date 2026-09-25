// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// hcl_view.dart
// Main view for the app
//
// 2023 December

import 'package:confapp/hcl/cubit/theme_cubit.dart';
import 'package:confapp/hcl/view/screen/content_widget.dart';
import 'package:confapp/hcl/view/screen/sidebar_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// The app view that hosts the component sidebar and generated-source panel.
class HCLView extends StatelessWidget {
  /// Creates the configuration app view.
  const HCLView({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ROHD-HCL',
          themeMode: themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF082E8A),
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF082E8A),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: const MainPage(title: 'ROHD-HCL'),
        ),
      );
}

/// The main application page containing the sidebar and content panel.
class MainPage extends StatelessWidget {
  /// Creates the main page with the displayed [title].
  const MainPage({required this.title, super.key});

  /// The page title.
  final String title;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('title', title));
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      body: const Row(
        children: [
          ComponentsSidebar(width: 240),
          Expanded(child: SVGenerator()),
        ],
      ),
    );
  }
}
