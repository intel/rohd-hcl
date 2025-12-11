/// State of sending beats on the AXI-S interface.
enum AxiStreamBeatState {
  /// Not currently sending anything.
  idle,

  /// Currently sending beats.
  working,
}
