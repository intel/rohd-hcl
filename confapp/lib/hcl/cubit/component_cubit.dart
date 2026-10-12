// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// component_cubit.dart
// Implementation of a cubit for Configurators
//
// 2023 December

import 'package:bloc/bloc.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Controls the selected component.
class ComponentCubit extends Cubit<Configurator> {
  /// The currently selected component configuration.
  Configurator selectedComponent;

  /// The available component configurations.
  final List<Configurator> components;

  /// Creates a controller for selecting from [components].
  ComponentCubit(List<Configurator> components)
      : this._(_sortedComponents(components));

  ComponentCubit._(this.components)
      : selectedComponent = components.first,
        super(components.first);

  static List<Configurator> _sortedComponents(
    List<Configurator> components,
  ) =>
      List<Configurator>.of(components)..sort(_compareComponents);

  static int _compareComponents(Configurator a, Configurator b) {
    final caseInsensitive =
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return caseInsensitive != 0 ? caseInsensitive : a.name.compareTo(b.name);
  }

  /// Selects and emits [selectedComponent].
  void setSelectedComponent(Configurator selectedComponent) {
    this.selectedComponent = selectedComponent;
    emit(selectedComponent);
  }
}
