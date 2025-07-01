import 'package:rohd/rohd.dart';

abstract class HandshakeInterface extends PairInterface {}

class ValidInterface extends HandshakeInterface {
  late final Logic valid;
}

class FixedLatencyInterface extends HandshakeInterface {
  final int latency;
  final ValidInterface start;
  final ValidInterface end;
}

// adds a configurable FIFO at the end and maps to ready/valid at the ends
class FixedLatencyBuffer {}
