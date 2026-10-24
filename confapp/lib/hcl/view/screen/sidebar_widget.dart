// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sidebar_widget.dart
// The sidebar widget
//
// 2023 December

import 'package:confapp/hcl/cubit/component_cubit.dart';
import 'package:confapp/hcl/view/screen/dock_lock_icon.dart';
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
  ///
  /// When [onTogglePinned] is provided, a lock button is shown in the header
  /// reflecting [pinned].
  const ComponentsSidebar({
    required this.width,
    this.pinned = true,
    this.onTogglePinned,
    super.key,
  });

  /// The width of the sidebar.
  final double width;

  /// Whether the sidebar is pinned open (shown in the layout).
  final bool pinned;

  /// Called when the user presses the lock button in the header.
  final VoidCallback? onTogglePinned;

  @override
  State<ComponentsSidebar> createState() => _ComponentsSidebarState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('width', width))
      ..add(FlagProperty('pinned', value: pinned, ifTrue: 'pinned'))
      ..add(ObjectFlagProperty<VoidCallback>.has(
        'onTogglePinned',
        onTogglePinned,
      ));
  }
}

class _ComponentsSidebarState extends State<ComponentsSidebar> {
  @override
  Widget build(BuildContext context) {
    final comCubit = context.read<ComponentCubit>();
    final componentsByCategory =
        <ComponentCategory, Map<String, List<Configurator>>>{
      for (final category in ComponentCategory.values) category: {},
    };
    for (final component in comCubit.components) {
      (componentsByCategory[component.category]![component.subcategory] ??= [])
          .add(component);
    }

    return BlocBuilder<ComponentCubit, Configurator>(
      builder: (context, selectedComponent) => Container(
        width: widget.width,
        color: canvasColor,
        child: ListTileTheme(
          minVerticalPadding: 0,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(8, 4, 8, 6),
                      child: Text(
                        'Components',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (widget.onTogglePinned != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      color: Colors.white,
                      tooltip: widget.pinned
                          ? 'Unpin components menu'
                          : 'Pin components menu',
                      icon: DockLockIcon(
                        locked: widget.pinned,
                        color: Colors.white,
                      ),
                      onPressed: widget.onTogglePinned,
                    ),
                ],
              ),
              for (final category in ComponentCategory.values)
                if (componentsByCategory[category]!.isNotEmpty)
                  ExpansionTile(
                    key: PageStorageKey<String>(
                      'component-category-${category.id}',
                    ),
                    maintainState: true,
                    minTileHeight: 36,
                    dense: true,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                    iconColor: white.withValues(alpha: 0.82),
                    collapsedIconColor: white.withValues(alpha: 0.82),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      category.label,
                      style: TextStyle(
                        color: white.withValues(alpha: 0.82),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      for (final subcategory
                          in componentsByCategory[category]!.keys.toList()
                            ..sort())
                        ExpansionTile(
                          key: PageStorageKey<String>(
                            'component-group-${category.id}-$subcategory',
                          ),
                          maintainState: true,
                          minTileHeight: 32,
                          dense: true,
                          tilePadding:
                              const EdgeInsets.only(left: 16, right: 8),
                          childrenPadding: const EdgeInsets.only(left: 24),
                          iconColor: white.withValues(alpha: 0.72),
                          collapsedIconColor: white.withValues(alpha: 0.72),
                          shape: const Border(),
                          collapsedShape: const Border(),
                          title: Text(
                            subcategory
                                .split('-')
                                .map((word) => word.isEmpty
                                    ? word
                                    : '${word[0].toUpperCase()}'
                                        '${word.substring(1)}')
                                .join(' '),
                            style: TextStyle(
                              color: white.withValues(alpha: 0.72),
                              fontSize: 12,
                            ),
                          ),
                          children: [
                            for (final component in componentsByCategory[
                                category]![subcategory]!)
                              _ComponentTile(
                                key: ObjectKey(component),
                                component: component,
                                selected: component == selectedComponent,
                                onTap: () =>
                                    comCubit.setSelectedComponent(component),
                              ),
                          ],
                        ),
                    ],
                  ),
            ],
          ),
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
    super.key,
  });

  final Configurator component;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? accentCanvasColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
