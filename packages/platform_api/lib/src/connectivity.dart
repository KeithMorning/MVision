/// Network connectivity status.
enum ConnectivityStatus {
  /// Connected to the internet.
  online,

  /// Not connected to the internet.
  offline,

  /// Connection status unknown.
  unknown,
}

/// Abstract interface for connectivity monitoring.
abstract interface class ConnectivityMonitor {
  /// Get current connectivity status.
  Future<ConnectivityStatus> getStatus();

  /// Stream of connectivity changes.
  Stream<ConnectivityStatus> get onStatusChanged;

  /// Check if currently online.
  Future<bool> get isOnline async =>
      await getStatus() == ConnectivityStatus.online;
}
