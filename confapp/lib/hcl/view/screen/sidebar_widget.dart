// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sidebar_widget.dart
// The sidebar widget
//
// 2023 December

import 'package:confapp/hcl/cubit/component_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// The primary accent color.
const primaryColor = Color.fromARGB(255, 160, 153, 240);

/// The sidebar canvas color.
const canvasColor = Color(0xFF2E2E48);

/// The scaffold background color.
const scaffoldBackgroundColor = Color(0xFF464667);

/// The selected sidebar item color.
const accentCanvasColor = Color(0xFF3E3E61);

/// The common white foreground color.
const white = Colors.white;

/// The sidebar action color.
final actionColor = const Color(0xFF5F5FA7).withValues(alpha: 0.6);

/// A divider matching the sidebar foreground palette.
final divider = Divider(color: white.withValues(alpha: 0.3), height: 1);

/// Displays the available configurable components.
class ComponentsSidebar extends StatefulWidget {
  /// Creates a component sidebar with the given [width].
  const ComponentsSidebar({required this.width, super.key});

  /// The width of the sidebar.
  final double width;

  @override
  State<ComponentsSidebar> createState() => _ComponentsSidebarState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('width', width));
  }
}

class _ComponentsSidebarState extends State<ComponentsSidebar> {
  @override
  Widget build(BuildContext context) {
    final comCubit = context.read<ComponentCubit>();
    return BlocBuilder<ComponentCubit, Configurator>(
      builder: (context, selectedComponent) => Container(
        width: widget.width,
        color: canvasColor,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Text(
                'Components',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final component in comCubit.components)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _ComponentTile(
                  component: component,
                  selected: component == selectedComponent,
                  onTap: () => comCubit.setSelectedComponent(component),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComponentTile extends StatelessWidget {
  const _ComponentTile({
    required this.component,
    required this.selected,
    required this.onTap,
  });

  final Configurator component;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Material(
          color: selected ? accentCanvasColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Text(
                component.name,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.72),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Configurator>('component', component))
      ..add(DiagnosticsProperty<bool>('selected', selected))
      ..add(ObjectFlagProperty<VoidCallback>.has('onTap', onTap));
  }
}
