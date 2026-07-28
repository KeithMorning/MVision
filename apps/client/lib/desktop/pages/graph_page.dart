import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';

import '../../app/providers.dart';

/// Graph View page - visualizes document links as a force-directed graph.
class GraphPage extends ConsumerStatefulWidget {
  const GraphPage({super.key});

  @override
  ConsumerState<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends ConsumerState<GraphPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  // Graph data
  List<GraphNode> _nodes = [];
  List<GraphEdge> _edges = [];
  
  // Interaction state
  Offset _panOffset = Offset.zero;
  double _scale = 1.0;
  int? _selectedNodeIndex;
  int? _hoveredNodeIndex;
  
  // Simulation
  bool _isSimulating = true;
  int _simulationTicks = 0;
  static const int _maxSimulationTicks = 300;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60fps
    )..addListener(_simulationStep);
    
    _loadGraphData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadGraphData() {
    final db = ref.read(databaseProvider);
    final docs = db.getAllDocumentTitles();
    
    // Create nodes
    _nodes = docs.map((doc) {
      final id = doc['id'] as String;
      final backlinkCount = db.getBacklinkCount(id);
      return GraphNode(
        id: id,
        title: doc['title'] as String,
        path: doc['path'] as String,
        linkCount: backlinkCount,
        // Initialize with random positions in a circle
        x: (math.Random().nextDouble() - 0.5) * 600,
        y: (math.Random().nextDouble() - 0.5) * 400,
      );
    }).toList();

    // Create node ID to index map
    final nodeIndexMap = <String, int>{};
    for (int i = 0; i < _nodes.length; i++) {
      nodeIndexMap[_nodes[i].id] = i;
    }

    // Create edges from links table
    _edges = [];
    for (int i = 0; i < _nodes.length; i++) {
      final outgoing = db.getOutgoingLinks(_nodes[i].id);
      for (final link in outgoing) {
        final targetId = link['target_doc_id'] as String;
        final targetIndex = nodeIndexMap[targetId];
        if (targetIndex != null && targetIndex != i) {
          _edges.add(GraphEdge(source: i, target: targetIndex));
        }
      }
    }

    // Start simulation
    _isSimulating = true;
    _simulationTicks = 0;
    _animationController.repeat();
    
    setState(() {});
  }

  void _simulationStep() {
    if (!_isSimulating || _nodes.isEmpty) return;
    
    _simulationTicks++;
    if (_simulationTicks > _maxSimulationTicks) {
      _isSimulating = false;
      _animationController.stop();
      return;
    }

    // Cooling factor
    final temperature = 1.0 - (_simulationTicks / _maxSimulationTicks);
    final cooling = temperature * temperature;

    // Apply forces
    _applyForces(cooling);
    
    setState(() {});
  }

  void _applyForces(double cooling) {
    const repulsionStrength = 5000.0;
    const attractionStrength = 0.01;
    const centerGravity = 0.01;
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

    // Center gravity
    for (final node in _nodes) {
      node.fx -= node.x * centerGravity;
      node.fy -= node.y * centerGravity;
    }

    // Apply forces with cooling
    for (final node in _nodes) {
      if (node.isDragging) continue;
      
      node.vx = (node.vx + node.fx) * damping * cooling;
      node.vy = (node.vy + node.fy) * damping * cooling;
      
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
    _isSimulating = true;
    _animationController.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '${_edges.length} 连接',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Restart simulation
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新布局',
            onPressed: _restartSimulation,
          ),
          // Zoom controls
          IconButton(
            icon: const Icon(Icons.zoom_in_rounded),
            tooltip: '放大',
            onPressed: () => setState(() => _scale = (_scale * 1.2).clamp(0.2, 5.0)),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_rounded),
            tooltip: '缩小',
            onPressed: () => setState(() => _scale = (_scale / 1.2).clamp(0.2, 5.0)),
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong_rounded),
            tooltip: '居中',
            onPressed: () => setState(() {
              _panOffset = Offset.zero;
              _scale = 1.0;
            }),
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
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
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
                GestureDetector(
                  onScaleStart: (_) => _selectedNodeIndex = null,
                  onScaleUpdate: (details) {
                    setState(() {
                      _scale = (_scale * details.scale).clamp(0.2, 5.0);
                      _panOffset += details.focalPointDelta;
                    });
                  },
                  onTapUp: (details) => _handleTap(details.localPosition),
                  child: MouseRegion(
                    onHover: (event) => _handleHover(event.localPosition),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: GraphPainter(
                        nodes: _nodes,
                        edges: _edges,
                        panOffset: _panOffset,
                        scale: _scale,
                        selectedIndex: _selectedNodeIndex,
                        hoveredIndex: _hoveredNodeIndex,
                        isDark: isDark,
                      ),
                    ),
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
                      onClose: () => setState(() => _selectedNodeIndex = null),
                    ),
                  ),
                // Legend
                Positioned(
                  right: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '图例',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text('节点大小 = 链接数', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _handleTap(Offset localPosition) {
    final size = context.size ?? Size.zero;
    final center = Offset(size.width / 2, size.height / 2);
    
    // Transform screen coordinates to graph coordinates
    final graphX = (localPosition.dx - center.dx - _panOffset.dx) / _scale;
    final graphY = (localPosition.dy - center.dy - _panOffset.dy) / _scale;

    // Find clicked node
    for (int i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      final radius = node.radius;
      final dx = graphX - node.x;
      final dy = graphY - node.y;
      if (dx * dx + dy * dy <= radius * radius * 1.5) {
        setState(() => _selectedNodeIndex = i);
        return;
      }
    }
    
    setState(() => _selectedNodeIndex = null);
  }

  void _handleHover(Offset localPosition) {
    final size = context.size ?? Size.zero;
    final center = Offset(size.width / 2, size.height / 2);
    
    final graphX = (localPosition.dx - center.dx - _panOffset.dx) / _scale;
    final graphY = (localPosition.dy - center.dy - _panOffset.dy) / _scale;

    for (int i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      final radius = node.radius;
      final dx = graphX - node.x;
      final dy = graphY - node.y;
      if (dx * dx + dy * dy <= radius * radius * 1.5) {
        if (_hoveredNodeIndex != i) {
          setState(() => _hoveredNodeIndex = i);
        }
        return;
      }
    }
    
    if (_hoveredNodeIndex != null) {
      setState(() => _hoveredNodeIndex = null);
    }
  }
}

/// A node in the graph representing a document.
class GraphNode {
  final String id;
  final String title;
  final String path;
  final int linkCount;
  
  double x;
  double y;
  double vx = 0;
  double vy = 0;
  double fx = 0;
  double fy = 0;
  bool isDragging = false;

  GraphNode({
    required this.id,
    required this.title,
    required this.path,
    required this.linkCount,
    required this.x,
    required this.y,
  });

  double get radius => 6.0 + (linkCount * 2.0).clamp(0, 20);
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
  final Offset panOffset;
  final double scale;
  final int? selectedIndex;
  final int? hoveredIndex;
  final bool isDark;

  GraphPainter({
    required this.nodes,
    required this.edges,
    required this.panOffset,
    required this.scale,
    required this.selectedIndex,
    required this.hoveredIndex,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    canvas.save();
    canvas.translate(center.dx + panOffset.dx, center.dy + panOffset.dy);
    canvas.scale(scale);

    // Draw edges
    final edgePaint = Paint()
      ..color = (isDark ? AppColors.borderDark : AppColors.border).withValues(alpha: 0.5)
      ..strokeWidth = 1.0 / scale
      ..style = PaintingStyle.stroke;

    final highlightEdgePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.6)
      ..strokeWidth = 2.0 / scale
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final source = nodes[edge.source];
      final target = nodes[edge.target];
      
      final isHighlighted = selectedIndex == edge.source || 
                           selectedIndex == edge.target ||
                           hoveredIndex == edge.source || 
                           hoveredIndex == edge.target;
      
      canvas.drawLine(
        Offset(source.x, source.y),
        Offset(target.x, target.y),
        isHighlighted ? highlightEdgePaint : edgePaint,
      );
    }

    // Draw nodes
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final isSelected = selectedIndex == i;
      final isHovered = hoveredIndex == i;
      
      // Node circle
      final nodePaint = Paint()
        ..color = isSelected || isHovered
            ? AppColors.primary
            : AppColors.primary.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(node.x, node.y),
        node.radius,
        nodePaint,
      );

      // Selection ring
      if (isSelected) {
        final ringPaint = Paint()
          ..color = AppColors.primary
          ..strokeWidth = 2.0 / scale
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(
          Offset(node.x, node.y),
          node.radius + 4,
          ringPaint,
        );
      }

      // Label (only show for larger nodes or when zoomed in)
      if (scale > 0.6 || node.linkCount > 3 || isSelected || isHovered) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: node.title.length > 20 
                ? '${node.title.substring(0, 20)}...' 
                : node.title,
            style: TextStyle(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              fontSize: 11 / scale,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            node.x - textPainter.width / 2,
            node.y + node.radius + 4,
          ),
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
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
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            node.path,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
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
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${node.linkCount} 个反向链接',
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
