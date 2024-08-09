// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// system_verilog_cubit.dart
// Implementation of a cubit for generating verilog
//
// 2023 December

import 'package:bloc/bloc.dart';

enum GenerationState { initial, loading, done }

class SystemVerilogCubitState {
  final String systemVerilog;
  final GenerationState generationState;
  final String name;

  const SystemVerilogCubitState(
      {required this.systemVerilog,
      required this.generationState,
      required this.name});
  const SystemVerilogCubitState.loading()
      : this(
            systemVerilog: 'Loading...',
            generationState: GenerationState.loading,
            name: 'loading');
  const SystemVerilogCubitState.done(String systemVerilog, String name)
      : this(
            systemVerilog: systemVerilog,
            generationState: GenerationState.done,
            name: name);
  const SystemVerilogCubitState.initial()
      : this(
            systemVerilog: 'Click "Generate RTL"!',
            generationState: GenerationState.initial,
            name: 'init');
}

/// Controls the generated SystemVerilog to display
class SystemVerilogCubit extends Cubit<SystemVerilogCubitState> {
  SystemVerilogCubit() : super(const SystemVerilogCubitState.loading()) {
    initializeData();
  }

  void initializeData() async {
    emit(const SystemVerilogCubitState.initial());
  }

  void setLoading() {
    emit(const SystemVerilogCubitState.loading());
  }

  void setRTL(String rtl, String name) {
    emit(SystemVerilogCubitState.done(rtl, name));
  }
}
