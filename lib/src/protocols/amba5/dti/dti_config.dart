import 'package:rohd/rohd.dart';

/// Config object for DTI message interfaces.
abstract class DtiMessageInterfaceConfig {
  /// Depth of the associated queue to buffer messages of this type.
  ///
  /// This is required regardless of whether the message is Tx or Rx.
  final int fifoDepth;

  /// Is this message type exempt from being blocked
  /// by the connection state of the module.
  ///
  /// This is only applicable to Tx messages (ignored for Rx).
  final bool connectedExempt;

  /// Is this message type credited at the protocol level.
  ///
  /// This is only applicable to Tx messages (ignored for Rx).
  final bool isCredited;

  /// The implied max # of credits for this message type.
  ///
  /// This is only applicable to Tx messages (ignored for Rx).
  final int creditCountWidth;

  /// A mapping function based on raw bits to determine
  /// if this message maps to the given message type.
  ///
  /// This is only applicable to Rx messages (ignored for Rx).
  final Logic Function(Logic msg)? mapToQueue;

  /// Constructor.
  DtiMessageInterfaceConfig({
    required this.fifoDepth,
    this.connectedExempt = false,
    this.isCredited = false,
    this.creditCountWidth = 0,
    this.mapToQueue,
  });
}

/// Config object for Tx side DTI message interfaces.
class DtiTxMessageInterfaceConfig extends DtiMessageInterfaceConfig {
  /// Constructor.
  DtiTxMessageInterfaceConfig({
    required super.fifoDepth,
    super.connectedExempt,
    super.isCredited,
    super.creditCountWidth = 0,
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
