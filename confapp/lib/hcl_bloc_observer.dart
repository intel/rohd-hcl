// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// hcl_bloc_observer.dart
// BlocObserver for the app
//
// 2023 December

import 'package:bloc/bloc.dart';

/// [BlocObserver] observe all state changes in the application.
class HCLBlocObserver extends BlocObserver {
  const HCLBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
  }
}
