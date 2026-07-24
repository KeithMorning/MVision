import 'dart:async';
import 'dart:collection';

/// An operation queued for when network becomes available.
class QueuedOperation {
  final String id;
  final QueuedOperationType type;
  final String sourceId;
  final String path;
  final DateTime queuedAt;
  final Map<String, dynamic>? data;

  const QueuedOperation({
    required this.id,
    required this.type,
    required this.sourceId,
    required this.path,
    required this.queuedAt,
    this.data,
  });
}

/// Type of queued operation.
enum QueuedOperationType {
  upload,
  download,
  delete,
  move,
}

/// Offline operation queue.
///
/// Queues sync operations when network is unavailable and
/// replays them when connectivity is restored.
class OfflineQueue {
  final Queue<QueuedOperation> _queue = Queue();
  final _controller = StreamController<int>.broadcast();

  /// Stream of queue length changes.
  Stream<int> get onLengthChanged => _controller.stream;

  /// Current queue length.
  int get length => _queue.length;

  /// Whether the queue is empty.
  bool get isEmpty => _queue.isEmpty;

  /// Add an operation to the queue.
  void enqueue(QueuedOperation operation) {
    _queue.add(operation);
    _controller.add(_queue.length);
  }

  /// Remove and return the next operation.
  QueuedOperation? dequeue() {
    final operation = _queue.isEmpty ? null : _queue.removeFirst();
    _controller.add(_queue.length);
    return operation;
  }

  /// Peek at the next operation without removing it.
  QueuedOperation? peek() {
    return _queue.isEmpty ? null : _queue.first;
  }

  /// Clear all operations.
  void clear() {
    _queue.clear();
    _controller.add(0);
  }

  /// Get all operations in order.
  List<QueuedOperation> get operations => _queue.toList();

  /// Dispose the queue.
  void dispose() {
    _controller.close();
  }
}
