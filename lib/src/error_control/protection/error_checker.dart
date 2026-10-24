// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// error_checker.dart
// Abstract definitions for error checking transmitters and receivers.
//
// 2024 January 18

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A transmitter for data which includes a [code] for checking and possibly
/// correcting data at the receiving end.
abstract class ErrorCheckingTransmitter<T extends Logic> extends Module {
  /// The code that in addition to original data that enables error detection.
  late final Logic code = output('code');

  /// Generates the code to be provided by the transmitter, to be implemented by
  /// implementations.
  @protected
  Logic calculateCode();

  /// The full bus to transmit including the original data and the [code].
  Logic get transmission => output('transmission');

  /// The input port data provied to this transmitter.
  ///
  /// Should only be used by implementations of transmitters internally.
  @protected
  late final T data;

  /// Creates a transmitter for [data].
  ErrorCheckingTransmitter(T data,
      {required int codeWidth,
      required super.name,
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? 'ErrorCheckingTransmitter_W${data.width}') {
    this.data = addTypedInput('data', data);

    addOutput('code', width: codeWidth);
    addOutput('transmission', width: codeWidth + data.width) <=
        [code, this.data].swizzle();

    code <= calculateCode();
  }
}

/// A receiver for data which includes a [code] for checking and possibly
/// correcting.
abstract class ErrorCheckingReceiver<T extends Logic> extends Module {
  /// Whether or not there was an error (correctable or uncorrectable).
  Logic get error => output('error');

  /// Whether there was a correctable error.
  late final Logic correctableError = output('correctable_error');

  /// Implementation to calculate whether something is a [correctableError].
  @protected
  Logic calculateCorrectableError();

  /// Whether there was an uncorrectable error.
  late final Logic uncorrectableError = output('uncorrectable_error');

  /// Implementation to calculate whether something is an [uncorrectableError].
  @protected
  Logic calculateUncorrectableError();

  /// The code included in the transmitted bus which is used to check for and
  /// handle errors.
  Logic get code => output('code');

  /// The original data before any correction.
  late final T originalData;

  /// The [originalData] with any possible corrections applied.
  ///
  /// If [uncorrectableError], then this data is unreliable.  If this does not
  /// [supportsErrorCorrection], then this will be `null` and the port won't
  /// exist.
  late final T? correctedData;

  /// Raw received payload bits, before enum or other schema constraints.
  ///
  /// Error detection and correction operate on these bits, not on potentially
  /// normalized [originalData].
  @protected
  late final Logic rawData;

  /// Implementation to calculate corrected data, if supported.
  ///
  /// Returns null if not [supportsErrorCorrection].
  @protected
  T? calculateCorrectedData();

  /// The input port bus provied to this receiver.
  ///
  /// Should only be used by implementations of receivers internally.
  @protected
  late final Logic transmission;

  /// Whether or not data correction is supported.
  final bool supportsErrorCorrection;

  /// Creates a receiver for [transmission].
  ///
  /// [dataSchema] supplies the payload layout, not a driver. Specialized [T]
  /// requires a schema matching the payload width. Without a schema, [T] must
  /// be [Logic], preserving the width-based scalar API.
  ErrorCheckingReceiver(Logic transmission,
      {required int codeWidth,
      required this.supportsErrorCorrection,
      required super.name,
      T? dataSchema,
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'ErrorCheckingReceiver_W${transmission.width}') {
    if (codeWidth <= 0) {
      throw RohdHclException('Must provide non-empty code.');
    }
    final dataWidth = transmission.width - codeWidth;
    if (dataWidth <= 0) {
      throw ArgumentError('Transmission must contain a non-empty payload.');
    }
    if (dataSchema == null && T != Logic) {
      throw ArgumentError('A specialized payload type requires dataSchema.');
    }
    if (dataSchema != null && dataSchema.width != dataWidth) {
      throw ArgumentError('dataSchema width must match the received payload.');
    }
    final schema = dataSchema ?? Logic(width: dataWidth) as T;

    this.transmission =
        addInput('transmission', transmission, width: transmission.width);

    addOutput('code', width: codeWidth) <=
        this.transmission.slice(-1, -codeWidth);
    rawData = this.transmission.slice(-1 - codeWidth, 0);
    // Keep schema constraints off the raw slice used for error calculations:
    // directly connected signals share their wire's value constraints.
    originalData = addTypedOutput('original_data', schema.cloneTyped)
      ..gets(this.transmission.slice(-1 - codeWidth, 0));
    correctedData = supportsErrorCorrection
        ? addTypedOutput('corrected_data', schema.cloneTyped)
        : null;

    addOutput('correctable_error');
    addOutput('uncorrectable_error');
    addOutput('error');

    correctableError <= calculateCorrectableError();
    uncorrectableError <= calculateUncorrectableError();
    error <= correctableError | uncorrectableError;

    if (supportsErrorCorrection) {
      correctedData! <= calculateCorrectedData()!;
    }
  }
}
