// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_linear_recurrence.dart
// Registered linear recurrences over GF(2).
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_linear_transform.dart';
import 'package:rohd_hcl/src/binary_math/recurrence/binary_linear_recurrence_descriptor.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Registered hardware for a [BinaryLinearRecurrenceDescriptor].
///
/// [state] exposes the current registered state. [nextState] exposes the
/// combinational recurrence result before load or enable control is applied.
/// Reset has priority over load, and load has priority over recurrence
/// advancement.
/// {@category Binary Math}
class BinaryLinearRecurrence extends Module {
  /// The recurrence implemented by this module.
  final BinaryLinearRecurrenceDescriptor descriptor;

  /// The packed state loaded when reset is asserted.
  final BigInt initialState;

  /// Whether reset is asynchronous.
  final bool asyncReset;

  /// The current registered state.
  Logic get state => output('state');

  /// The combinational next state for the current state and input.
  Logic get nextState => output('next_state');

  /// Creates registered binary recurrence hardware.
  ///
  /// [dataIn] is required exactly when [descriptor] has a non-zero input width.
  /// [load] and [loadState] must either both be provided or both be omitted.
  /// Without [enable], the recurrence advances on every active clock edge.
  BinaryLinearRecurrence({
    required Logic clk,
    required this.descriptor,
    Logic? dataIn,
    Logic? reset,
    Logic? enable,
    Logic? load,
    Logic? loadState,
    BigInt? initialState,
    this.asyncReset = false,
    int radix = 2,
    super.name = 'binary_linear_recurrence',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  })  : initialState = initialState ?? BigInt.zero,
        super(
          definitionName: definitionName ??
              'BinaryLinearRecurrence_S${descriptor.stateWidth}_'
                  'I${descriptor.inputWidth}_R${radix}_'
                  'D${descriptor.configurationSignature}_'
                  'V${(initialState ?? BigInt.zero).toRadixString(16)}_'
                  'A${asyncReset ? 1 : 0}_'
                  'E${enable == null ? 0 : 1}_'
                  'L${load == null ? 0 : 1}',
        ) {
    _validateConfiguration(dataIn, reset, load, loadState, radix);

    clk = addInput('clk', clk);
    if (reset != null) {
      reset = addInput('reset', reset);
    }
    if (enable != null) {
      enable = addInput('enable', enable);
    }
    if (load != null) {
      load = addInput('load', load);
      loadState =
          addInput('load_state', loadState!, width: descriptor.stateWidth);
    }
    if (dataIn != null) {
      dataIn = addInput('data_in', dataIn, width: descriptor.inputWidth);
    }

    final state = addOutput('state', width: descriptor.stateWidth);
    final nextState = addOutput('next_state', width: descriptor.stateWidth);
    final stateTransform = BinaryLinearTransform(
      state,
      matrix: descriptor.stateMatrix,
      affineOffset: descriptor.offset,
      radix: radix,
    );

    if (descriptor.inputMatrix case final inputMatrix?) {
      final inputTransform = BinaryLinearTransform(
        dataIn!,
        matrix: inputMatrix,
        radix: radix,
      );
      nextState <= stateTransform.result ^ inputTransform.result;
    } else {
      nextState <= stateTransform.result;
    }

    final valueToRegister =
        load == null ? nextState : mux(load, loadState!, nextState);
    final registerEnable =
        enable == null || load == null ? enable : enable | load;
    state <=
        flop(
          clk,
          valueToRegister,
          en: registerEnable,
          reset: reset,
          resetValue: Const(this.initialState, width: descriptor.stateWidth),
          asyncReset: asyncReset,
        );
  }

  void _validateConfiguration(
    Logic? dataIn,
    Logic? reset,
    Logic? load,
    Logic? loadState,
    int radix,
  ) {
    if ((descriptor.inputWidth == 0) != (dataIn == null)) {
      throw RohdHclException(descriptor.inputWidth == 0
          ? 'Autonomous binary recurrence must not have a data input.'
          : 'Binary recurrence requires a ${descriptor.inputWidth}-bit '
              'data input.');
    }
    if (dataIn != null && dataIn.width != descriptor.inputWidth) {
      throw PortWidthMismatchException(dataIn, descriptor.inputWidth);
    }
    if ((load == null) != (loadState == null)) {
      throw RohdHclException(
          'Binary recurrence load and loadState must be provided together.');
    }
    if (loadState != null && loadState.width != descriptor.stateWidth) {
      throw PortWidthMismatchException(loadState, descriptor.stateWidth);
    }
    if (initialState.isNegative ||
        initialState >= (BigInt.one << descriptor.stateWidth)) {
      throw RohdHclException('Initial state $initialState does not fit in '
          '${descriptor.stateWidth} state bits.');
    }
    if (reset == null && initialState != BigInt.zero) {
      throw RohdHclException(
          'A non-zero initial state requires a reset signal.');
    }
    if (reset == null && asyncReset) {
      throw RohdHclException('Asynchronous reset requires a reset signal.');
    }
    if (radix < 2) {
      throw RohdHclException('Reduction radix must be at least 2.');
    }
  }
}
