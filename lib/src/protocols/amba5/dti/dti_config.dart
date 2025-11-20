import 'package:rohd/rohd.dart';

/// Config object for DTI message interfaces.
abstract class DtiMessageInterfaceConfig {
  /// Depth of the associated queue to buffer messages of this type.
  ///
  /// This is required regardless of whether the message is Tx or Rx.
  final int fifoDepth;

  /// Is this message type credited at the protocol level.
  ///
  /// This is only applicable to Tx messages (ignored for Rx).
  final bool isCredited;

  /// A mapping function based on raw bits to determine
  /// if this message maps to the given message type.
  ///
  /// This is only applicable to Rx messages (ignored for Rx).
  final Logic Function(Logic msg)? mapToQueue;

  /// Constructor.
  DtiMessageInterfaceConfig({
    required this.fifoDepth,
    this.isCredited = false,
    this.mapToQueue,
  });
}

/// Config object for Tx side DTI message interfaces.
class DtiTxMessageInterfaceConfig extends DtiMessageInterfaceConfig {
  /// Constructor.
  DtiTxMessageInterfaceConfig({
    required super.fifoDepth,
    super.isCredited = false,
  });
}

/// Config object for Rx side DTI message interfaces.
class DtiRxMessageInterfaceConfig extends DtiMessageInterfaceConfig {
  /// Constructor.
  DtiRxMessageInterfaceConfig({
    required super.fifoDepth,
    required super.mapToQueue,
  });
}
