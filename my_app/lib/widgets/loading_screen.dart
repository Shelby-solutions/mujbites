import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  String _emoji = '🍳';
  double _emojiSize = 32;
  late Timer _emojiTimer;
  late Timer _sizeTimer;
  
  final List<String> _emojis = ['🍳', '✨', '⭐', '🍴', '🍽️'];
  
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _bounceAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Start repeating animation
    _startAnimation();
    _setupTimers();
  }

  void _startAnimation() {
    if (_disposed) return;
    _controller.forward().then((_) {
      if (_disposed) return;
      _controller.reverse().then((_) {
        if (_disposed) return;
        _startAnimation();
      });
    });
  }

  void _setupTimers() {
    _emojiTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || _disposed) return;
      setState(() {
        _emoji = _emojis[timer.tick % _emojis.length];
      });
    });
    
    _sizeTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!mounted || _disposed) return;
      setState(() {
        _emojiSize = 40;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || _disposed) return;
        setState(() {
          _emojiSize = 32;
        });
      });
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _emojiTimer.cancel();
    _sizeTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFEFCE8), Colors.white],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated emojis
            Stack(
              children: [
                ScaleTransition(
                  scale: _bounceAnimation,
                  child: Text(
                    _emoji,
                    style: TextStyle(
                      fontSize: _emojiSize,
                    ),
                  ),
                ),
                Positioned(
                  top: -16,
                  right: -16,
                  child: ScaleTransition(
                    scale: _bounceAnimation,
                    child: const Text(
                      '✨',
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -16,
                  left: -16,
                  child: ScaleTransition(
                    scale: _bounceAnimation,
                    child: const Text(
                      '⭐',
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Loading text
            Text(
              'Cooking up something special...',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Bouncing dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _BouncingDot(
                    delay: Duration(milliseconds: index * 200),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _BouncingDot extends StatefulWidget {
  final Duration delay;

  const _BouncingDot({required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    )..addListener(() {
      setState(() {});
    });

    Future.delayed(widget.delay, () {
      _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, _animation.value),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
} 