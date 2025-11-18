/// Capture the connection state.
enum DtiConnectionState {
  /// Unconnected to ATU
  unconnected,

  /// Sent connection request, waiting for ack
  pendingConn,

  /// Sent disconnection request, waiting for ack
  pendingDisconn,

  /// Connected to ATU
  connected,
}
