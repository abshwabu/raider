import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final AnimationController _bokehController;
  Timer? _navTimer;

  // Bokeh circle definitions
  static const int _bokehCount = 6;
  late final List<_BokehCircle> _bokehCircles;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _bokehController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // Generate randomized bokeh circles
    final rng = Random(42); // fixed seed for consistency
    _bokehCircles = List.generate(_bokehCount, (i) {
      return _BokehCircle(
        dx: rng.nextDouble(),
        dy: rng.nextDouble(),
        radius: 20.0 + rng.nextDouble() * 60.0,
        baseOpacity: 0.03 + rng.nextDouble() * 0.06,
        phaseOffset: rng.nextDouble(),
      );
    });

    _animController.forward();

    // Navigate to library after brief brand presentation
    _navTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        context.go('/library');
      }
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _animController.dispose();
    _bokehController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Theme-aware backgrounds
    final backgroundColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final progressBgColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFCBD5E1);
    final subtitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final bokehColor = isDark
        ? const Color(0xFF6366F1)
        : const Color(0xFF4F46E5);
    // Gradient colors adapt to brightness
    final gradientColors = isDark
        ? const [Color(0xFFFFFFFF), Color(0xFFC7D2FE), Color(0xFF818CF8)]
        : const [Color(0xFF1E293B), Color(0xFF4338CA), Color(0xFF6366F1)];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // ── Bokeh particles ────────────────────────
          AnimatedBuilder(
            animation: _bokehController,
            builder: (context, _) {
              return Stack(
                children: _bokehCircles.map((circle) {
                  final animValue = _bokehController.value;
                  // Each circle has a phase offset for organic motion
                  final phase = (animValue + circle.phaseOffset) % 1.0;
                  final opacity = circle.baseOpacity *
                      (0.5 + 0.5 * sin(phase * pi * 2));

                  return Positioned(
                    left: circle.dx * MediaQuery.of(context).size.width -
                        circle.radius,
                    top: circle.dy * MediaQuery.of(context).size.height -
                        circle.radius,
                    child: Container(
                      width: circle.radius * 2,
                      height: circle.radius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bokehColor.withValues(alpha: opacity.clamp(0.0, 1.0)),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // ── Main content ──────────────────────────
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glowing app logo
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1)
                                .withValues(alpha: isDark ? 0.35 : 0.25),
                            blurRadius: 36,
                            spreadRadius: 4,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Brand Name
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Text(
                        'RAIDER',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      'AI BOOK READER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Wider progress indicator with glow
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1)
                                .withValues(alpha: isDark ? 0.4 : 0.25),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: 48,
                        height: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            backgroundColor: progressBgColor,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Data class for a single bokeh circle.
class _BokehCircle {
  final double dx;
  final double dy;
  final double radius;
  final double baseOpacity;
  final double phaseOffset;

  const _BokehCircle({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.baseOpacity,
    required this.phaseOffset,
  });
}
