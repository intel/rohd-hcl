// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// system_verilog_cubit.dart
// Implementation of a cubit for generating verilog
//
// 2023 December

import 'package:bloc/bloc.dart';

/// The state of SystemVerilog and SystemC generation.
enum GenerationState {
  /// No generation has been requested.
  initial,

  /// Generation is in progress.
  loading,

  /// Generation completed successfully.
  done,
}

/// The generated SystemVerilog, SystemC, and their display metadata.
class SystemVerilogCubitState {
  /// The generated SystemVerilog source.
  final String systemVerilog;

  /// The generated SystemC source.
  final String systemC;

  /// The current generation state.
  final GenerationState generationState;

  /// The display name of the generated component.
  final String name;

  /// The generated module definition name.
  final String moduleName;

  /// Creates a generated-source display state.
  const SystemVerilogCubitState({
    required this.systemVerilog,
    required this.systemC,
    required this.generationState,
    required this.name,
    required this.moduleName,
  });

  /// Creates a state indicating that generation is in progress.
  const SystemVerilogCubitState.loading()
      : this(
            systemVerilog: 'Loading...',
            systemC: 'Loading...',
            generationState: GenerationState.loading,
            name: 'loading',
            moduleName: '');

  /// Creates a state containing completed generated output.
  const SystemVerilogCubitState.done(
      String systemVerilog, String systemC, String name, String moduleName)
      : this(
            systemVerilog: systemVerilog,
            systemC: systemC,
            generationState: GenerationState.done,
            name: name,
            moduleName: moduleName);

  /// Creates the initial state shown before generation.
  const SystemVerilogCubitState.initial()
      : this(
            systemVerilog: 'Click "Generate RTL"!',
            systemC: 'Click "Generate" to see the generated SystemC',
            generationState: GenerationState.initial,
            name: 'init',
            moduleName: '');
}

/// Controls the generated SystemVerilog and SystemC displayed by the app.
class SystemVerilogCubit extends Cubit<SystemVerilogCubitState> {
  /// Creates a controller initialized with placeholder content.
  SystemVerilogCubit() : super(const SystemVerilogCubitState.loading()) {
    initializeData();
  }

  /// Displays the initial generation prompt.
  void initializeData() {
    emit(const SystemVerilogCubitState.initial());
  }

  /// Displays the loading state.
  void setLoading() {
    emit(const SystemVerilogCubitState.loading());
  }

  /// Displays generated [rtl] and [systemC] with component metadata.
  void setRTL(
    String rtl,
    String systemC,
    String name,
    String moduleName,
  ) {
    emit(SystemVerilogCubitState.done(rtl, systemC, name, moduleName));
  }
}
