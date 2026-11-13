import 'package:flutter/material.dart';

class AiSpeedDialFab extends StatefulWidget {
  final VoidCallback onOpenStudio;
  final VoidCallback onOpenChat;
  final bool isVisible;

  const AiSpeedDialFab({
    super.key,
    required this.onOpenStudio,
    required this.onOpenChat,
    this.isVisible = true,
  });

  @override
  State<AiSpeedDialFab> createState() => AiSpeedDialFabState();
}

class AiSpeedDialFabState extends State<AiSpeedDialFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: 0.0,
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void didUpdateWidget(covariant AiSpeedDialFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isVisible && _isOpen) {
      close();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void close() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _controller.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen) ...[
          // Studio Action
          ScaleTransition(
            scale: _expandAnimation,
            child: FadeTransition(
              opacity: _expandAnimation,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FloatingActionButton.extended(
                  heroTag: 'speed_dial_studio',
                  elevation: 4,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                  onPressed: () {
                    close();
                    widget.onOpenStudio();
                  },
                  icon: const Icon(Icons.auto_stories_outlined, size: 20),
                  label: const Text('Studio', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
          // Ask AI Action
          ScaleTransition(
            scale: _expandAnimation,
            child: FadeTransition(
              opacity: _expandAnimation,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FloatingActionButton.extended(
                  heroTag: 'speed_dial_ask_ai',
                  elevation: 4,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  onPressed: () {
                    close();
                    widget.onOpenChat();
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                  label: const Text('Ask AI', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
        // Main Toggle FAB
        FloatingActionButton(
          heroTag: 'speed_dial_main',
          elevation: 4,
          backgroundColor: _isOpen
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primary,
          foregroundColor: _isOpen
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onPrimary,
          onPressed: toggle,
          tooltip: _isOpen ? 'Close AI menu' : 'AI tools (Studio & Ask AI)',
          child: AnimatedRotation(
            turns: _isOpen ? 0.25 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _isOpen ? Icons.close_rounded : Icons.auto_awesome_rounded,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}
