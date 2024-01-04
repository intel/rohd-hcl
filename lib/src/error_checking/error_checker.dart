import 'package:rohd/rohd.dart';

abstract class ErrorCheckingTransmitter extends Module {
  Logic get code;
  Logic get bus;

  ErrorCheckingTransmitter(Logic data);
}

abstract class ErrorCheckingReceiver extends Module {
  Logic get error;
  Logic get correctableError;
  Logic get uncorrectableError;
  Logic get code;
  Logic get originalData;
  Logic get correctedData;

  ErrorCheckingReceiver(Logic bus);
}
