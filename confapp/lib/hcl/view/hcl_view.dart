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
class MainPage extends StatefulWidget {
  /// Creates the main page with the displayed [title].
  const MainPage({required this.title, super.key});

  /// The page title.
  final String title;

  @override
  State<MainPage> createState() => _MainPageState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('title', title));
  }
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  static const double _sidebarWidth = 240;
  static const double _triggerWidth = 18;

  /// Whether the component sidebar is pinned into the layout.
  bool _sidebarPinned = true;

  /// Drives the hover slide of the unpinned sidebar (0 = hidden, 1 = shown).
  late final AnimationController _slideController;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slide = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _pinSidebar() => setState(() => _sidebarPinned = true);

  void _unpinSidebar() {
    setState(() => _sidebarPinned = false);
    // The panel stays visible under the pointer until the mouse leaves it,
    // or slides away right away if the pointer is already elsewhere.
    _slideController.reverse();
  }

  void _showSidebar() => _slideController.forward();

  void _hideSidebar() {
    if (!_sidebarPinned) {
      _slideController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sidebar = ComponentsSidebar(
      width: _sidebarWidth,
      pinned: _sidebarPinned,
      onTogglePinned: _sidebarPinned ? _unpinSidebar : _pinSidebar,
    );

    if (_sidebarPinned) {
      return Scaffold(
        body: Row(
          children: [
            sidebar,
            const Expanded(child: SVGenerator()),
          ],
        ),
      );
    }

    // Unpinned: the content fills the page, a thin strip on the left edge
    // reveals the sidebar on hover, and the sidebar slides out over the
    // content until the pointer leaves it.
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: SVGenerator()),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _triggerWidth,
            child: MouseRegion(
              onEnter: (_) => _showSidebar(),
              opaque: false,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _sidebarWidth,
            child: SlideTransition(
              position: _slide,
              child: MouseRegion(
                onExit: (_) => _hideSidebar(),
                child: Material(
                  elevation: 8,
                  child: sidebar,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
