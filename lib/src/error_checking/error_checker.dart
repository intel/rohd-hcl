import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';

abstract class ErrorCheckingTransmitter extends Module {
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
  late final Logic data;

  /// Creates a transmitter for [data].
  ErrorCheckingTransmitter(Logic data,
      {required int codeWidth, required super.name, super.definitionName}) {
    this.data = addInput('data', data, width: data.width);

    addOutput('code', width: codeWidth);
    addOutput('transmission', width: codeWidth + data.width) <=
        [code, this.data].swizzle();

    code <= calculateCode();
  }
}

abstract class ErrorCheckingReceiver extends Module {
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
  Logic get originalData => output('original_data');

  /// The [originalData] with any possible corrections applied.
  ///
  /// If [uncorrectableError], then this data is unreliable.  If this does not
  /// [supportsErrorCorrection], then this will be `null` and the port won't
  /// exist.
  late final Logic? correctedData =
      supportsErrorCorrection ? output('corrected_data') : null;

  /// Implementation to calculate corrected data, if supported.
  ///
  /// Returns null if not [supportsErrorCorrection].
  @protected
  Logic? calculateCorrectedData();

  /// The input port bus provied to this receiver.
  ///
  /// Should only be used by implementations of receivers internally.
  @protected
  late final Logic transmission;

  /// Whether or not data correction is supported.
  final bool supportsErrorCorrection;

  /// Creates a receiver for [transmission].
  ErrorCheckingReceiver(Logic transmission,
      {required int codeWidth,
      required this.supportsErrorCorrection,
      required super.name,
      super.definitionName})
      : assert(codeWidth > 0, 'Must provide non-empty code.') {
    this.transmission =
        addInput('transmission', transmission, width: transmission.width);

    addOutput('code', width: codeWidth) <=
        this.transmission.slice(-1, -codeWidth);
    addOutput('original_data', width: transmission.width - codeWidth) <=
        this.transmission.slice(-1 - codeWidth, 0);

    if (supportsErrorCorrection) {
      addOutput('corrected_data', width: originalData.width);
    }

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
