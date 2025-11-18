/// Capture the connection state.
enum DtiConnectionState {
  /// Unconnected to ATU
  unconnected,

  /// Sent connection request, waiting for ack
  pending,

  /// Connected to ATU
  connected,
}
