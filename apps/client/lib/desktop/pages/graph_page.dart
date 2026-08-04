import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';

import '../../app/providers.dart';

/// Graph View page - visualizes document links as a force-directed graph.
///
/// Layout (v3, Obsidian-style):
/// - connected components cluster around their own gravity centers
/// - isolated notes (no links) orbit on the outermost ring
/// - node size scales with link count
/// - dragging a node keeps the simulation warm so neighbors follow live
///
/// Rebuild: the AppBar rescan action re-indexes the vault and reloads the
/// graph; the force simulation then unfolds the new structure (physics, not
/// a tween - see docs/design/interaction-principles.md #1).
///
/// Interactions (raw pointer events, no gesture arena):
/// - scroll wheel / trackpad pinch: zoom to cursor
/// - drag empty space: pan; drag a node: move it (live physics)
/// - hover: neighborhood focus with hysteresis (enter r+6, leave r+16)
///   and 280ms eased alpha transitions (no flicker)
/// - click: select; double-click: open the note
class GraphPage extends ConsumerStatefulWidget {
  const GraphPage({super.key});

  @override
  ConsumerState<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends ConsumerState<GraphPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _fadeController;
  late CurvedAnimation _fadeCurve;

  // Graph data
  List<GraphNode> _nodes = [];
  List<GraphEdge> _edges = [];
  Map<int, Set<int>> _neighbors = {};

  // View transform
  Offset _panOffset = Offset.zero;
  double _scale = 1.0;
  Size _viewSize = Size.zero;

  // Interaction state
  int? _selectedNodeIndex;
  int? _hoveredNodeIndex;
  int? _dragNodeIndex;
  bool _isPanning = false;
  Offset _lastPointerPos = Offset.zero;
  Offset _downPos = Offset.zero;
  int _downTimeMs = 0;
  int _lastTapMs = 0;
  Offset _lastTapPos = Offset.zero;
  Offset _lastDragDelta = Offset.zero;
  double _pinchStartScale = 1.0;

  // Simulation
  int _simulationTicks = 0;
  static const int _maxSimulationTicks = 300;

  /// Steady force input while dragging: neighbors follow live.
  static const double _warmCooling = 0.3;
  bool _didInitialFit = false;

  final _spawnRandom = math.Random(7);

  /// Hover wins over selection as the focused neighborhood.
  int? get _focusIndex => _hoveredNodeIndex ?? _selectedNodeIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60fps
    )..addListener(_simulationStep);

    // Eased fade for neighborhood dimming (kills hover flicker)
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() => setState(() {}));
    _fadeCurve = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _loadGraphData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fadeCurve.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _loadGraphData() {
    final db = ref.read(databaseProvider);
    final docs = db.getAllDocumentTitles();

    // Create nodes
    final random = math.Random(42);
    _nodes = docs.map((doc) {
      final id = doc['id'] as String;
      return GraphNode(
        id: id,
        title: doc['title'] as String,
        path: doc['path'] as String,
        linkCount: 0, // set from connection degree after edges are built
        modifiedAt: doc['modified_at'] as int? ?? 0,
        // Initialize with random positions in a circle
        x: (random.nextDouble() - 0.5) * 600,
        y: (random.nextDouble() - 0.5) * 400,
      );
    }).toList();

    // Create node ID to index map
    final nodeIndexMap = <String, int>{};
    for (int i = 0; i < _nodes.length; i++) {
      nodeIndexMap[_nodes[i].id] = i;
    }

    // Create edges from links table + neighbor index
    _edges = [];
    _neighbors = {for (int i = 0; i < _nodes.length; i++) i: {}};
    for (int i = 0; i < _nodes.length; i++) {
      final outgoing = db.getOutgoingLinks(_nodes[i].id);
      for (final link in outgoing) {
        final targetId = link['target_doc_id'] as String;
        final targetIndex = nodeIndexMap[targetId];
        if (targetIndex != null && targetIndex != i) {
          _edges.add(GraphEdge(source: i, target: targetIndex));
          _neighbors[i]!.add(targetIndex);
          _neighbors[targetIndex]!.add(i);
        }
      }
    }

    // Node size = connection degree (in + out). A hub note like index.md
    // mostly links *out*; sizing by backlinks alone would make it tiny.
    for (int i = 0; i < _nodes.length; i++) {
      _nodes[i].linkCount = _neighbors[i]!.length;
    }

    _computeComponentCenters();

    // Fresh layout: reset the sim and the fit flag so the new structure
    // unfolds via physics and re-fits to the view when it settles.
    _didInitialFit = false;

    // Start simulation
    _simulationTicks = 0;
    _animationController.repeat();

    setState(() {});
  }

  /// Union-find over edges: each connected component gets its own gravity
  /// center. The largest component sits at the origin, smaller components
  /// on a ring around it, isolated notes on the outermost ring.
  void _computeComponentCenters() {
    final n = _nodes.length;
    if (n == 0) return;

    final parent = List.generate(n, (i) => i);
    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    for (final e in _edges) {
      final ra = find(e.source), rb = find(e.target);
      if (ra != rb) parent[ra] = rb;
    }

    final comps = <int, List<int>>{};
    for (int i = 0; i < n; i++) {
      comps.putIfAbsent(find(i), () => []).add(i);
    }

    // Largest first
    final sorted = comps.values.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    // Main component at origin
    for (final i in sorted.first) {
      _nodes[i].cx = 0;
      _nodes[i].cy = 0;
    }

    // Other linked components on an inner ring
    final linked = sorted.where((c) => c.length > 1).skip(1).toList();
    final isolated = sorted.where((c) => c.length == 1).toList();

    final innerRadius = 160.0 + 40.0 * math.sqrt(linked.length + 1);
    for (int k = 0; k < linked.length; k++) {
      final angle = 2 * math.pi * k / linked.length;
      for (final i in linked[k]) {
        _nodes[i].cx = math.cos(angle) * innerRadius;
        _nodes[i].cy = math.sin(angle) * innerRadius;
      }
    }

    // Isolated notes on the outermost ring
    final outerRadius = math.max(innerRadius * 1.7, 320.0);
    for (int k = 0; k < isolated.length; k++) {
      final angle = 2 * math.pi * k / isolated.length;
      final i = isolated[k].first;
      _nodes[i].cx = math.cos(angle) * outerRadius;
      _nodes[i].cy = math.sin(angle) * outerRadius;
      // Start isolated nodes near their final orbit (less travel, less chaos)
      _nodes[i].x = _nodes[i].cx + (_spawnRandom.nextDouble() - 0.5) * 40;
      _nodes[i].y = _nodes[i].cy + (_spawnRandom.nextDouble() - 0.5) * 40;
    }
  }

  void _simulationStep() {
    if (_nodes.isEmpty) return;

    _simulationTicks++;
    final keepAlive = _dragNodeIndex != null;

    final double cooling;
    if (_simulationTicks > _maxSimulationTicks) {
      if (!keepAlive) {
        _animationController.stop();
        if (!_didInitialFit) {
          _didInitialFit = true;
          _fitToView();
        }
        return;
      }
      cooling = _warmCooling; // steady low temperature
    } else {
      final temperature = 1.0 - (_simulationTicks / _maxSimulationTicks);
      cooling = temperature * temperature;
    }

    _applyForces(cooling);
    setState(() {});
  }

  void _applyForces(double cooling) {
    const repulsionStrength = 5000.0;
    const attractionStrength = 0.02; // stiff springs -> visible overshoot
    const componentGravity = 0.01;

    /// Velocity decay (damping). Applied to velocity only; `cooling` scales
    /// the *force input*. Never multiply velocity by cooling — that kills
    /// momentum outright and makes motion feel dead (see
    /// docs/design/interaction-principles.md #1).
    const damping = 0.9;

    // Reset forces
    for (final node in _nodes) {
      node.fx = 0;
      node.fy = 0;
    }

    // Repulsion between all nodes (Coulomb's law)
    for (int i = 0; i < _nodes.length; i++) {
      for (int j = i + 1; j < _nodes.length; j++) {
        final dx = _nodes[j].x - _nodes[i].x;
        final dy = _nodes[j].y - _nodes[i].y;
        final distSq = dx * dx + dy * dy + 1;
        final dist = math.sqrt(distSq);
        final force = repulsionStrength / distSq;

        final fx = (dx / dist) * force;
        final fy = (dy / dist) * force;

        _nodes[i].fx -= fx;
        _nodes[i].fy -= fy;
        _nodes[j].fx += fx;
        _nodes[j].fy += fy;
      }
    }

    // Attraction along edges (Hooke's law)
    for (final edge in _edges) {
      final source = _nodes[edge.source];
      final target = _nodes[edge.target];

      final dx = target.x - source.x;
      final dy = target.y - source.y;
      final dist = math.sqrt(dx * dx + dy * dy) + 1;

      // Ideal edge length
      const idealLength = 100.0;
      final force = (dist - idealLength) * attractionStrength;

      final fx = (dx / dist) * force;
      final fy = (dy / dist) * force;

      source.fx += fx;
      source.fy += fy;
      target.fx -= fx;
      target.fy -= fy;
    }

    // Component gravity: pull each node towards its component center
    for (final node in _nodes) {
      node.fx -= (node.x - node.cx) * componentGravity;
      node.fy -= (node.y - node.cy) * componentGravity;
    }

    // Apply forces: cooling scales force input, damping decays velocity.
    // Underdamped springs -> nodes overshoot and oscillate before settling.
    for (final node in _nodes) {
      if (node.isDragging) continue;

      node.vx = (node.vx + node.fx * cooling) * damping;
      node.vy = (node.vy + node.fy * cooling) * damping;

      // Limit velocity
      final speed = math.sqrt(node.vx * node.vx + node.vy * node.vy);
      const maxSpeed = 10.0;
      if (speed > maxSpeed) {
        node.vx = (node.vx / speed) * maxSpeed;
        node.vy = (node.vy / speed) * maxSpeed;
      }

      node.x += node.vx;
      node.y += node.vy;
    }
  }

  void _restartSimulation() {
    _simulationTicks = 0;
    _animationController.repeat();
  }

  /// Reheat after a drag: springs pull the node back with overshoot.
  void _reheat() {
    _simulationTicks = (_maxSimulationTicks * 0.75).round();
    _animationController.repeat();
  }

  /// Resume the (stopped) simulation at warm temperature, e.g. on drag start.
  void _warmUpSimulation() {
    if (!_animationController.isAnimating) {
      _animationController.repeat();
    }
  }

  // ============================================================
  // Re-scan & rebuild
  // ============================================================

  /// Re-index the vault from disk, then rebuild the graph from the
  /// freshly-scanned database. The force simulation unfolds the new
  /// structure naturally (physics, not a tween) - see
  /// docs/design/interaction-principles.md #1.
  Future<void> _rescanAndRebuild() async {
    await scanVault(ref);
    if (!mounted) return;
    _loadGraphData();
  }

  // ============================================================
  // Coordinate helpers (single source of truth: _viewSize from LayoutBuilder)
  // ============================================================

  Offset get _canvasCenter =>
      Offset(_viewSize.width / 2, _viewSize.height / 2);

  Offset _toGraph(Offset localPosition) {
    final center = _canvasCenter;
    return Offset(
      (localPosition.dx - center.dx - _panOffset.dx) / _scale,
      (localPosition.dy - center.dy - _panOffset.dy) / _scale,
    );
  }

  /// Hit test with the *enter* radius (hysteresis: smaller than exit radius).
  int? _hitTest(Offset localPosition) {
    final point = _toGraph(localPosition);
    // Search topmost (later-drawn) nodes first
    for (int i = _nodes.length - 1; i >= 0; i--) {
      final node = _nodes[i];
      final radius = node.radius + 6; // enter slop
      final dx = point.dx - node.x;
      final dy = point.dy - node.y;
      if (dx * dx + dy * dy <= radius * radius) return i;
    }
    return null;
  }

  void _updateFocus() {
    if (_focusIndex != null) {
      _fadeController.forward();
    } else {
      _fadeController.reverse();
    }
  }

  // ============================================================
  // Raw pointer handlers (no gesture arena: drag/pan start instantly)
  // ============================================================

  void _onPointerDown(PointerDownEvent event) {
    _downPos = event.localPosition;
    _lastPointerPos = event.localPosition;
    _downTimeMs = event.timeStamp.inMilliseconds;

    final hit = _hitTest(event.localPosition);
    if (hit != null) {
      _dragNodeIndex = hit;
      _nodes[hit].isDragging = true;
      _warmUpSimulation(); // live physics while dragging
      setState(() => _hoveredNodeIndex = hit);
    } else {
      setState(() => _isPanning = true);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final delta = event.localPosition - _lastPointerPos;
    _lastPointerPos = event.localPosition;

    final drag = _dragNodeIndex;
    if (drag != null) {
      final node = _nodes[drag];
      node.x += delta.dx / _scale;
      node.y += delta.dy / _scale;
      node.vx = 0;
      node.vy = 0;
      _lastDragDelta = delta; // remember for fling on release
      setState(() {});
    } else if (_isPanning) {
      setState(() => _panOffset += delta);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final dist = (event.localPosition - _downPos).distance;
    final duration = event.timeStamp.inMilliseconds - _downTimeMs;
    final wasTap = dist < 8 && duration < 400;

    final drag = _dragNodeIndex;
    if (drag != null) {
      final node = _nodes[drag];
      node.isDragging = false;
      _dragNodeIndex = null;
      if (dist >= 8) {
        // Fling: hand the pointer's momentum to the node, then let the
        // springs pull it back with overshoot (never zero the velocity).
        node.vx = (_lastDragDelta.dx / _scale).clamp(-15.0, 15.0);
        node.vy = (_lastDragDelta.dy / _scale).clamp(-15.0, 15.0);
        _reheat();
      }
    }
    if (_isPanning) setState(() => _isPanning = false);

    if (wasTap) _handleTap(event.localPosition, event.timeStamp.inMilliseconds);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    final drag = _dragNodeIndex;
    if (drag != null) {
      _nodes[drag].isDragging = false;
      _dragNodeIndex = null;
    }
    if (_isPanning) setState(() => _isPanning = false);
  }

  void _handleTap(Offset position, int timeMs) {
    // Double-tap detection: two taps close in time and space
    if (timeMs - _lastTapMs < 350 &&
        (position - _lastTapPos).distance < 24) {
      _lastTapMs = 0;
      final hit = _hitTest(position);
      if (hit != null) {
        context.push('/reader/${_nodes[hit].id}');
      }
      return;
    }
    _lastTapMs = timeMs;
    _lastTapPos = position;

    setState(() => _selectedNodeIndex = _hitTest(position));
    _updateFocus();
  }

  void _onPointerHover(PointerHoverEvent event) {
    if (_dragNodeIndex != null || _isPanning) return;

    // Hysteresis: once hovered, the pointer must leave a *larger* radius
    // before the hover is cleared — no boundary oscillation, no flicker.
    final current = _hoveredNodeIndex;
    if (current != null) {
      final node = _nodes[current];
      final point = _toGraph(event.localPosition);
      final dx = point.dx - node.x;
      final dy = point.dy - node.y;
      final exitRadius = node.radius + 16;
      if (dx * dx + dy * dy <= exitRadius * exitRadius) return;
      // Pointer left the sticky zone: check whether it entered another node
      // directly (handoff without a dim/undim gap).
      final next = _hitTest(event.localPosition);
      if (next == current) return;
      setState(() => _hoveredNodeIndex = next);
      _updateFocus();
      return;
    }

    final hit = _hitTest(event.localPosition);
    if (hit != null) {
      setState(() => _hoveredNodeIndex = hit);
      _updateFocus();
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final zoomFactor = event.scrollDelta.dy < 0 ? 1.12 : 1 / 1.12;
      _zoomAt(event.localPosition, zoomFactor);
    }
  }

  // Trackpad pinch zoom (macOS / precision touchpads)
  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _pinchStartScale = _scale;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final center = _canvasCenter;
    final focalGraph = _toGraph(event.localPosition);
    final newScale = (_pinchStartScale * event.scale).clamp(0.2, 5.0);
    setState(() {
      _panOffset = Offset(
        event.localPosition.dx - center.dx - focalGraph.dx * newScale,
        event.localPosition.dy - center.dy - focalGraph.dy * newScale,
      ) + event.localPanDelta;
      _scale = newScale;
    });
  }

  void _zoomAt(Offset localPosition, double factor) {
    final center = _canvasCenter;
    final focalGraph = _toGraph(localPosition);
    final newScale = (_scale * factor).clamp(0.2, 5.0);
    setState(() {
      _panOffset = Offset(
        localPosition.dx - center.dx - focalGraph.dx * newScale,
        localPosition.dy - center.dy - focalGraph.dy * newScale,
      );
      _scale = newScale;
    });
  }

  void _zoomBy(double factor) {
    _zoomAt(_canvasCenter, factor);
  }

  void _fitToView() {
    if (_nodes.isEmpty || _viewSize == Size.zero) return;
    final size = _viewSize;

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final n in _nodes) {
      minX = math.min(minX, n.x);
      minY = math.min(minY, n.y);
      maxX = math.max(maxX, n.x);
      maxY = math.max(maxY, n.y);
    }
    const padding = 120.0;
    final graphW = (maxX - minX).abs() + padding * 2;
    final graphH = (maxY - minY).abs() + padding * 2;
    final fitScale =
        math.min(size.width / graphW, size.height / graphH).clamp(0.2, 2.0);

    final graphCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    setState(() {
      _scale = fitScale;
      _panOffset =
          Offset(-graphCenter.dx * fitScale, -graphCenter.dy * fitScale);
    });
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scanState = ref.watch(scanStateProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.hub_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text('关系图谱', style: theme.textTheme.titleMedium),
          ],
        ),
        actions: [
          // Stats
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Row(
              children: [
                Text(
                  '${_nodes.length} 节点',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '${_edges.length} 连接',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Re-scan vault & rebuild graph (physics unfolds the new structure)
          IconButton(
            icon: scanState.isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: scanState.isScanning ? '扫描中…' : '重新扫描知识库',
            onPressed: scanState.isScanning ? null : _rescanAndRebuild,
          ),
          // Restart simulation
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新布局',
            onPressed: _restartSimulation,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: _nodes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hub_outlined,
                    size: 64,
                    color: isDark
                        ? AppColors.textSecondaryDark.withValues(alpha: 0.3)
                        : AppColors.textSecondary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '暂无链接数据',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '在笔记中使用 [[wiki链接]] 来建立连接',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark.withValues(alpha: 0.7)
                          : AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Graph canvas
                LayoutBuilder(
                  builder: (context, constraints) {
                    _viewSize =
                        Size(constraints.maxWidth, constraints.maxHeight);
                    return MouseRegion(
                      cursor: _dragNodeIndex != null
                          ? SystemMouseCursors.grabbing
                          : _isPanning
                              ? SystemMouseCursors.move
                              : _hoveredNodeIndex != null
                                  ? SystemMouseCursors.click
                                  : SystemMouseCursors.basic,
                      child: Listener(
                        onPointerDown: _onPointerDown,
                        onPointerMove: _onPointerMove,
                        onPointerUp: _onPointerUp,
                        onPointerCancel: _onPointerCancel,
                        onPointerHover: _onPointerHover,
                        onPointerSignal: _onPointerSignal,
                        onPointerPanZoomStart: _onPanZoomStart,
                        onPointerPanZoomUpdate: _onPanZoomUpdate,
                        behavior: HitTestBehavior.opaque,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: GraphPainter(
                            nodes: _nodes,
                            edges: _edges,
                            neighbors: _neighbors,
                            panOffset: _panOffset,
                            scale: _scale,
                            selectedIndex: _selectedNodeIndex,
                            hoveredIndex: _hoveredNodeIndex,
                            focusAlpha: _fadeCurve.value,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Zoom controls (bottom right)
                Positioned(
                  right: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                  child: _ZoomControls(
                    isDark: isDark,
                    onZoomIn: () => _zoomBy(1.25),
                    onZoomOut: () => _zoomBy(1 / 1.25),
                    onFit: _fitToView,
                  ),
                ),
                // Selected node info
                if (_selectedNodeIndex != null)
                  Positioned(
                    left: AppSpacing.lg,
                    bottom: AppSpacing.lg,
                    child: _NodeInfoCard(
                      node: _nodes[_selectedNodeIndex!],
                      isDark: isDark,
                      onOpen: () {
                        final node = _nodes[_selectedNodeIndex!];
                        context.push('/reader/${node.id}');
                      },
                      onClose: () {
                        setState(() => _selectedNodeIndex = null);
                        _updateFocus();
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

/// A node in the graph representing a document.
class GraphNode {
  final String id;
  final String title;
  final String path;

  /// Connection degree (in + out links). Mutable: computed after edges are built.
  int linkCount;
  final int modifiedAt;

  double x;
  double y;
  double vx = 0;
  double vy = 0;
  double fx = 0;
  double fy = 0;

  /// Gravity center of this node's connected component.
  double cx = 0;
  double cy = 0;

  bool isDragging = false;

  GraphNode({
    required this.id,
    required this.title,
    required this.path,
    required this.linkCount,
    required this.modifiedAt,
    required this.x,
    required this.y,
  });

  /// Visual tier: 3 = hub (>=5 links), 2 = standard, 1 = leaf, 0 = isolated.
  int get tier =>
      linkCount >= 5 ? 3 : linkCount >= 2 ? 2 : linkCount == 1 ? 1 : 0;

  double get radius => switch (tier) {
        3 => 10.0 + math.min(linkCount - 5, 8) * 0.7,
        2 => 6.5 + (linkCount - 2) * 1.0,
        1 => 5.0,
        _ => 4.0,
      };
}

/// An edge in the graph representing a link between documents.
class GraphEdge {
  final int source;
  final int target;

  GraphEdge({required this.source, required this.target});
}

/// Custom painter for the force-directed graph.
class GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Map<int, Set<int>> neighbors;
  final Offset panOffset;
  final double scale;
  final int? selectedIndex;
  final int? hoveredIndex;

  /// 0..1 eased progress of neighborhood dimming.
  final double focusAlpha;

  final bool isDark;

  GraphPainter({
    required this.nodes,
    required this.edges,
    required this.neighbors,
    required this.panOffset,
    required this.scale,
    required this.selectedIndex,
    required this.hoveredIndex,
    required this.focusAlpha,
    required this.isDark,
  });

  int? get _focusIndex => hoveredIndex ?? selectedIndex;

  bool _isNeighborOfFocus(int i) {
    final focus = _focusIndex;
    if (focus == null) return false;
    return neighbors[focus]?.contains(i) ?? false;
  }

  Color get _nodeColor =>
      isDark ? const Color(0xFF3B82F6) : AppColors.primary;

  Color get _isolatedColor =>
      isDark ? const Color(0xFF52525B) : const Color(0xFFA1A1AA);

  /// Base alpha per tier (monochrome lightness hierarchy).
  double _tierAlpha(GraphNode node) => switch (node.tier) {
        3 => 1.0,
        2 => 0.85,
        1 => 0.55,
        _ => 0.9,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    _drawGrid(canvas, size, center);

    canvas.save();
    canvas.translate(center.dx + panOffset.dx, center.dy + panOffset.dy);
    canvas.scale(scale);

    final focus = _focusIndex;
    final dim = focusAlpha; // 0 = no dimming, 1 = fully dimmed non-neighbors

    // ---- Edges ----
    final baseEdgeColor =
        isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
    for (final edge in edges) {
      final source = nodes[edge.source];
      final target = nodes[edge.target];

      final isActive =
          focus != null && (edge.source == focus || edge.target == focus);

      final Color color;
      final double width;
      if (isActive) {
        color = _nodeColor.withValues(alpha: 0.75);
        width = 1.5;
      } else {
        // Dark mode needs roughly 2x the alpha for equal legibility
        // (docs/design/interaction-principles.md #7).
        final base = isDark ? 0.22 : 0.12;
        final dimmed = isDark ? 0.07 : 0.04;
        final alpha =
            focus == null ? base : base + (dimmed - base) * dim;
        color = baseEdgeColor.withValues(alpha: alpha);
        width = 0.75;
      }

      canvas.drawLine(
        Offset(source.x, source.y),
        Offset(target.x, target.y),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = color
          ..strokeWidth = width / scale,
      );
    }

    // ---- Nodes ----
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final isSelected = selectedIndex == i;
      final isHovered = hoveredIndex == i;
      final isNeighbor = _isNeighborOfFocus(i);
      final isFocused = isSelected || isHovered;

      final baseAlpha = node.tier == 0 ? 0.9 : _tierAlpha(node);
      final double alpha;
      if (focus == null || isFocused) {
        alpha = baseAlpha;
      } else if (isNeighbor) {
        alpha = 1.0;
      } else {
        alpha = baseAlpha + (0.15 - baseAlpha) * dim;
      }

      final baseColor = node.tier == 0 ? _isolatedColor : _nodeColor;
      final radius = node.radius;

      // Glow behind focused node
      if (isFocused) {
        canvas.drawCircle(
          Offset(node.x, node.y),
          radius + 8 / scale,
          Paint()
            ..color = _nodeColor.withValues(alpha: 0.18)
            ..style = PaintingStyle.fill,
        );
      }

      // Fill
      canvas.drawCircle(
        Offset(node.x, node.y),
        radius,
        Paint()
          ..color = baseColor.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );

      // Hub marker: thin outer ring
      if (node.tier == 3) {
        canvas.drawCircle(
          Offset(node.x, node.y),
          radius + 2.5 / scale,
          Paint()
            ..color = baseColor.withValues(alpha: alpha * 0.4)
            ..strokeWidth = 1.0 / scale
            ..style = PaintingStyle.stroke,
        );
      }

      // Selection ring
      if (isSelected) {
        canvas.drawCircle(
          Offset(node.x, node.y),
          radius + 4 / scale,
          Paint()
            ..color = _nodeColor
            ..strokeWidth = 1.5 / scale
            ..style = PaintingStyle.stroke,
        );
      }
    }

    // ---- Labels (pills, drawn on top) ----
    final showAll = scale > 1.3;
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final isSelected = selectedIndex == i;
      final isHovered = hoveredIndex == i;
      final isNeighbor = _isNeighborOfFocus(i);
      final isFocused = isSelected || isHovered;

      final show = isFocused || isNeighbor || node.tier == 3 || showAll;
      if (!show) continue;

      // Non-focused labels fade out with dimming
      double labelAlpha = 1.0;
      if (focus != null && !isFocused && !isNeighbor && node.tier != 3) {
        labelAlpha = 1.0 - dim;
        if (labelAlpha <= 0.01) continue;
      }

      _drawLabelPill(canvas, node,
          emphasized: isFocused || isNeighbor, alpha: labelAlpha);
    }

    canvas.restore();
  }

  /// Rounded pill label below the node.
  void _drawLabelPill(Canvas canvas, GraphNode node,
      {required bool emphasized, required double alpha}) {
    final label = node.title.length > 20
        ? '${node.title.substring(0, 20)}…'
        : node.title;

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: (emphasized
                  ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary))
              .withValues(alpha: alpha),
          fontSize: 11 / scale,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padH = 8.0;
    const padV = 4.0;
    final pillW = textPainter.width + padH * 2 / scale;
    final pillH = textPainter.height + padV * 2 / scale;
    final left = node.x - pillW / 2;
    final top = node.y + node.radius + 4 / scale;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, pillW, pillH),
      Radius.circular(6 / scale),
    );

    // Pill background
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = (isDark ? AppColors.surfaceDark : AppColors.background)
            .withValues(alpha: 0.85 * alpha)
        ..style = PaintingStyle.fill,
    );
    // Pill border (tinted primary when emphasized)
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = (emphasized
                ? _nodeColor.withValues(alpha: 0.5)
                : (isDark ? AppColors.borderDark : AppColors.border))
            .withValues(alpha: (emphasized ? 0.5 : 1.0) * alpha)
        ..strokeWidth = 1.0 / scale
        ..style = PaintingStyle.stroke,
    );

    textPainter.paint(
      canvas,
      Offset(left + padH / scale, top + padV / scale),
    );
  }

  /// Sparse dot grid (40px, low alpha) for spatial reference.
  void _drawGrid(Canvas canvas, Size size, Offset center) {
    const spacing = 40.0;
    final paint = Paint()
      ..color = (isDark ? AppColors.borderDark : AppColors.border)
          .withValues(alpha: 0.3);

    final offsetX = (center.dx + panOffset.dx) % spacing;
    final offsetY = (center.dy + panOffset.dy) % spacing;

    for (double x = offsetX; x < size.width; x += spacing) {
      for (double y = offsetY; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}

/// Floating zoom control cluster.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.isDark,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  final bool isDark;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surfaceDark : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;
    final iconColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _control(Icons.add_rounded, '放大', onZoomIn, iconColor),
          Divider(height: 1, thickness: 1, color: borderColor),
          _control(Icons.remove_rounded, '缩小', onZoomOut, iconColor),
          Divider(height: 1, thickness: 1, color: borderColor),
          _control(Icons.fit_screen_rounded, '适应视图', onFit, iconColor),
        ],
      ),
    );
  }

  Widget _control(
      IconData icon, String tooltip, VoidCallback onPressed, Color color) {
    return IconButton(
      icon: Icon(icon, size: 18),
      color: color,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

/// Info card for selected node.
class _NodeInfoCard extends StatelessWidget {
  const _NodeInfoCard({
    required this.node,
    required this.isDark,
    required this.onOpen,
    required this.onClose,
  });

  final GraphNode node;
  final bool isDark;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  node.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(AppRadius.button),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            node.path,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.link_rounded,
                size: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${node.linkCount} 个连接',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('打开笔记'),
            ),
          ),
        ],
      ),
    );
  }
}
