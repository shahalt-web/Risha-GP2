import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:risha_v01/shared/config/feature_flags.dart';
import 'package:risha_v01/shared/services/child_task_progress_service.dart';

class ChildShapeMatchingScreen extends StatefulWidget {
  const ChildShapeMatchingScreen({super.key});

  @override
  State<ChildShapeMatchingScreen> createState() =>
      _ChildShapeMatchingScreenState();
}

class _ChildShapeMatchingScreenState extends State<ChildShapeMatchingScreen> {
  final _taskProgressService = ChildTaskProgressService();
  final Set<_ShapeKind> _matchedShapes = <_ShapeKind>{};
  Timer? _completionTimer;

  bool get _isComplete => _matchedShapes.length == _ShapeKind.values.length;

  @override
  void initState() {
    super.initState();
    unawaited(_redirectIfCompletedToday());
  }

  Future<void> _redirectIfCompletedToday() async {
    if (FeatureFlags.bypassDailyTaskCompletionRestrictionsTemporarily) {
      return;
    }
    try {
      final progress = await _taskProgressService
          .getSelectedChildTaskProgress();
      if (!mounted || !progress.isCompleted(ChildTaskIds.shapeMatching)) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('تم إنجاز هذه المهمة اليوم. ستعود غدًا.'),
            ),
          );
        context.go('/child-home/daily-home');
      });
    } catch (_) {
      // If progress loading fails, keep the task accessible.
    }
  }

  void _handleShapeMatched(_ShapeKind shape) {
    if (_matchedShapes.contains(shape)) {
      return;
    }
    setState(() => _matchedShapes.add(shape));

    if (_isComplete) {
      _completionTimer?.cancel();
      _completionTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) {
          return;
        }
        context.go('/child-home/hero-reward?task=shape-matching');
      });
    }
  }

  void _closeScreen(BuildContext context) {
    _completionTimer?.cancel();
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/child-home/daily-home');
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE6D4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFB8D7A8),
                        border: Border(
                          right: BorderSide(color: Color(0xFF1795F1), width: 2),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 10,
                            left: 8,
                            child: _CloseButton(
                              onTap: () => _closeScreen(context),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 76, 22, 28),
                            child: Column(
                              children: [
                                Text(
                                  _isComplete
                                      ? 'أحسنت!\nطابقت كل الأشكال'
                                      : 'هل تستطيع مطابقة كل\nشكل بمكانه؟',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 44),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _ShapeTarget(
                                        shape: _ShapeKind.triangle,
                                        size: 100,
                                        isMatched: _matchedShapes.contains(
                                          _ShapeKind.triangle,
                                        ),
                                        onAccepted: _handleShapeMatched,
                                      ),
                                      _ShapeTarget(
                                        shape: _ShapeKind.star,
                                        size: 96,
                                        isMatched: _matchedShapes.contains(
                                          _ShapeKind.star,
                                        ),
                                        onAccepted: _handleShapeMatched,
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: _ShapeTarget(
                                          shape: _ShapeKind.circle,
                                          size: 96,
                                          isMatched: _matchedShapes.contains(
                                            _ShapeKind.circle,
                                          ),
                                          onAccepted: _handleShapeMatched,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      color: const Color(0xFFF1E6CF),
                      padding: const EdgeInsets.fromLTRB(8, 38, 8, 8),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _DraggableShapeSlot(
                            shape: _ShapeKind.star,
                            size: 104,
                            isMatched: _matchedShapes.contains(_ShapeKind.star),
                          ),
                          const SizedBox(height: 34),
                          _DraggableShapeSlot(
                            shape: _ShapeKind.circle,
                            size: 88,
                            isMatched: _matchedShapes.contains(
                              _ShapeKind.circle,
                            ),
                          ),
                          const SizedBox(height: 38),
                          _DraggableShapeSlot(
                            shape: _ShapeKind.triangle,
                            size: 66,
                            isMatched: _matchedShapes.contains(
                              _ShapeKind.triangle,
                            ),
                          ),
                          const Spacer(),
                          Image.asset(
                            'assets/risha/risha_thinking.png',
                            width: 118,
                            height: 118,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShapeTarget extends StatelessWidget {
  const _ShapeTarget({
    required this.shape,
    required this.size,
    required this.isMatched,
    required this.onAccepted,
  });

  final _ShapeKind shape;
  final double size;
  final bool isMatched;
  final ValueChanged<_ShapeKind> onAccepted;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_ShapeKind>(
      onWillAcceptWithDetails: (details) => details.data == shape && !isMatched,
      onAcceptWithDetails: (details) => onAccepted(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedScale(
          duration: const Duration(milliseconds: 160),
          scale: isHovering ? 1.08 : 1,
          child: _ShapeAsset(
            shape: shape,
            size: size,
            color: isMatched
                ? const Color(0xFFF7CF33)
                : Colors.white.withValues(alpha: 0.96),
          ),
        );
      },
    );
  }
}

class _DraggableShapeSlot extends StatelessWidget {
  const _DraggableShapeSlot({
    required this.shape,
    required this.size,
    required this.isMatched,
  });

  final _ShapeKind shape;
  final double size;
  final bool isMatched;

  @override
  Widget build(BuildContext context) {
    if (isMatched) {
      return SizedBox(width: size, height: size);
    }

    return Draggable<_ShapeKind>(
      data: shape,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: _ShapeAsset(
          shape: shape,
          size: size + 6,
          color: const Color(0xFFF7CF33),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.18,
        child: _ShapeAsset(
          shape: shape,
          size: size,
          color: const Color(0xFFF7CF33),
        ),
      ),
      child: _ShapeAsset(
        shape: shape,
        size: size,
        color: const Color(0xFFF7CF33),
      ),
    );
  }
}

class _ShapeAsset extends StatelessWidget {
  const _ShapeAsset({
    required this.shape,
    required this.size,
    required this.color,
  });

  final _ShapeKind shape;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      shape.assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: BlendMode.srcIn,
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFF2E3A70),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 19),
        ),
      ),
    );
  }
}

enum _ShapeKind {
  triangle('assets/shapes/triangle.png'),
  star('assets/shapes/Star.png'),
  circle('assets/shapes/circle.png');

  const _ShapeKind(this.assetPath);

  final String assetPath;
}
