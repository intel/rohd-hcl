// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// theme_cubit.dart
// Theme mode state management for the configuration app.
//
// 2026 April 22
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:bloc/bloc.dart';
import 'package:material_ui/material_ui.dart';

/// Controls the application's light and dark theme selection.
class ThemeCubit extends Cubit<ThemeMode> {
  /// Creates a theme controller initially using the light theme.
  ThemeCubit() : super(ThemeMode.light);

  /// Switches between the light and dark themes.
  void toggleTheme() {
    emit(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  /// Whether the dark theme is currently selected.
  bool get isDark => state == ThemeMode.dark;
}
