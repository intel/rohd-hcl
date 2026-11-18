// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// signature_analyzer.dart
// Registered multiple-input signature analysis hardware.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/binary_math/recurrence/binary_linear_recurrence.dart';
import 'package:rohd_hcl/src/binary_math/recurrence/signature_analyzer_descriptor.dart';

/// Accumulates input words into a multiple-input signature register.
///
/// On each enabled clock edge, the input word is accumulated according to
/// [descriptor]. Reset and the optional clear input both restore
/// [initialSignature], with reset taking priority over clear and clear taking
/// priority over accumulation.
/// {@category Binary Math}
class SignatureAnalyzer extends Module {
  /// The signature recurrence implemented by this module.
  final SignatureAnalyzerDescriptor descriptor;

  /// The signature loaded by reset and clear.
  final BigInt initialSignature;

  /// Whether reset is asynchronous.
  final bool asyncReset;

  /// The current accumulated signature.
  Logic get signature => output('signature');

  /// The combinational signature including the current input word.
  Logic get nextSignature => output('next_signature');

  /// Creates a registered multiple-input signature analyzer.
  SignatureAnalyzer({
    required Logic clk,
    required Logic reset,
    required Logic dataIn,
    required this.descriptor,
    Logic? enable,
    Logic? clear,
    BigInt? initialSignature,
    this.asyncReset = false,
    int radix = 2,
    super.name = 'signature_analyzer',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  })  : initialSignature = initialSignature ?? BigInt.zero,
        super(
          definitionName: definitionName ??
              'SignatureAnalyzer_${descriptor.configurationSignature}_'
                  'R${radix}_'
                  'V${(initialSignature ?? BigInt.zero).toRadixString(16)}_'
                  'A${asyncReset ? 1 : 0}_E${enable == null ? 0 : 1}_'
                  'C${clear == null ? 0 : 1}',
        ) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    dataIn = addInput('data_in', dataIn, width: descriptor.inputWidth);
    if (enable != null) {
      enable = addInput('enable', enable);
    }
    if (clear != null) {
      clear = addInput('clear', clear);
    }

    final recurrence = BinaryLinearRecurrence(
      clk: clk,
      reset: reset,
      dataIn: dataIn,
      descriptor: descriptor.recurrence,
      enable: enable,
      load: clear,
      loadState: clear == null
          ? null
          : Const(this.initialSignature, width: descriptor.signatureWidth),
      initialState: this.initialSignature,
      asyncReset: asyncReset,
      radix: radix,
      name: 'signature_recurrence',
    );
    addOutput('signature', width: descriptor.signatureWidth) <=
        recurrence.state;
    addOutput('next_signature', width: descriptor.signatureWidth) <=
        recurrence.nextState;
  }
}
