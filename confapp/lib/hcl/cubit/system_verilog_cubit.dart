// Copyright (C) 2023 Intel Corporation
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
  final String moduleName;

  const SystemVerilogCubitState(
      {required this.systemVerilog,
      required this.generationState,
      required this.name,
      required this.moduleName});
  const SystemVerilogCubitState.loading()
      : this(
            systemVerilog: 'Loading...',
            generationState: GenerationState.loading,
            name: 'loading',
            moduleName: '');
  const SystemVerilogCubitState.done(
      String systemVerilog, String name, String moduleName)
      : this(
            systemVerilog: systemVerilog,
            generationState: GenerationState.done,
            name: name,
            moduleName: moduleName);
  const SystemVerilogCubitState.initial()
      : this(
            systemVerilog: 'Click "Generate RTL"!',
            generationState: GenerationState.initial,
            name: 'init',
            moduleName: '');
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

  void setRTL(String rtl, String name, String moduleName) {
    emit(SystemVerilogCubitState.done(rtl, name, moduleName));
  }
}
