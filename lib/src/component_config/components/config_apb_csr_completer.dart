// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_apb_csr_completer.dart
// Configurator for the documented APB CSR completer.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [ApbCsrCompleter].
class ApbCsrCompleterConfigurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.interfaces;

  @override
  String get subcategory => 'amba-endpoints';

  /// Width of APB and CSR addresses.
  final IntConfigKnob addressWidthKnob = IntConfigKnob(value: 16);

  /// Width of APB and CSR data.
  final ChoiceConfigKnob<int> dataWidthKnob = ChoiceConfigKnob(
    [8, 16, 32],
    value: 32,
  );

  /// Number of cycles before the completer responds.
  final IntConfigKnob responseLatencyKnob = IntConfigKnob(value: 0);

  /// Whether to include the APB slave-error port.
  final ToggleConfigKnob includeSlvErrKnob = ToggleConfigKnob(value: false);

  /// Width of optional APB request-user data.
  final IntConfigKnob userRequestWidthKnob = IntConfigKnob(value: 0);

  /// Width of optional APB read/write user data.
  final IntConfigKnob userDataWidthKnob = IntConfigKnob(value: 0);

  /// Width of optional APB response-user data.
  final IntConfigKnob userResponseWidthKnob = IntConfigKnob(value: 0);

  /// Whether to include the APB wake-up port.
  final ToggleConfigKnob includeWakeupKnob = ToggleConfigKnob(value: false);

  /// Number of APB select signals.
  final IntConfigKnob selectCountKnob = IntConfigKnob(value: 1);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Address Width': addressWidthKnob,
    'Data Width': dataWidthKnob,
    'Response Latency': responseLatencyKnob,
    'Include Slave Error': includeSlvErrKnob,
    'User Request Width': userRequestWidthKnob,
    'User Data Width': userDataWidthKnob,
    'User Response Width': userResponseWidthKnob,
    'Include Wakeup': includeWakeupKnob,
    'Select Count': selectCountKnob,
  });

  @override
  Module createModule() {
    final apb = ApbInterface(
        addrWidth: addressWidthKnob.value,
        dataWidth: dataWidthKnob.value,
        userReqWidth: userRequestWidthKnob.value,
        userDataWidth: userDataWidthKnob.value,
        userRespWidth: userResponseWidthKnob.value,
        includeSlvErr: includeSlvErrKnob.value,
        includeWakeup: includeWakeupKnob.value,
        numSelects: selectCountKnob.value);
    final readPort =
        DataPortInterface(dataWidthKnob.value, addressWidthKnob.value);
    final writePort =
        DataPortInterface(dataWidthKnob.value, addressWidthKnob.value);

    return ApbCsrCompleter(
      apb: apb,
      csrRd: readPort,
      csrWr: writePort,
      responseLatency: responseLatencyKnob.value,
    );
  }

  @override
  String get name => 'APB CSR Completer';
}
