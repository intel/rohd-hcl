// Copyright (C) 2023-2024 Intel Corporation
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
  Configurator selectedComponent;

  final List<Configurator> components;

  ComponentCubit(this.components)
      : selectedComponent = components.first,
        super(components.first);

  void setSelectedComponent(Configurator selectedComponent) {
    this.selectedComponent = selectedComponent;
    emit(selectedComponent);
  }
}
