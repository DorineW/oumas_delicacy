// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/colors.dart'; // Importing your AppColors

class BikeAnimation extends StatefulWidget {
  final double size;

  const BikeAnimation({super.key, this.size = 120});

  @override
  State<BikeAnimation> createState() => _BikeAnimationState();
}

class _BikeAnimationState extends State<BikeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Animations
  late Animation<double> _slideIn;
  late Animation<double> _slideOut;
  late Animation<double> _bounce;
  late Animation<double> _tilt;
  late Animation<double> _dustOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500), // 3.5 seconds loop
    )..repeat();

    // 1. SLIDE IN (0% to 40% of time)
    // Use easeOutQuart for a heavy, smooth braking effect
    _slideIn = Tween<double>(begin: -1.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutQuart),
      ),
    );

    // 2. SLIDE OUT (60% to 100% of time)
    // Use easeInBack. The bike will pull back slightly (anticipation) before zooming off
    _slideOut = Tween<double>(begin: 0.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInBack),
      ),
    );

    // 3. IDLE BOUNCE (Engine Vibration)
    // Create a rapid sine wave effect using a tween sequence that runs specifically during the idle phase
    _bounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -2.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -2.0, end: 0.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -1.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        // Bounce primarily when stopped (between 35% and 65%)
        curve: const Interval(0.35, 0.65, curve: Curves.easeInOut),
      ),
    );

    // 4. TILT (Physics)
    // Tilt forward slightly when braking, tilt back when accelerating
    _tilt = TweenSequence<double>([
      // Slide In: Tilt forward (braking)
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 0.05), weight: 30), // Brake dip
      TweenSequenceItem(
          tween: Tween(begin: 0.05, end: 0.0), weight: 10), // Settle
      // Idle: No tilt
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 20),
      // Slide Out: Tilt back (acceleration/wheelie)
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -0.08), weight: 10), // Rev up
      TweenSequenceItem(
          tween: Tween(begin: -0.08, end: 0.0), weight: 30), // Level out
    ]).animate(_controller);

    // 5. DUST OPACITY
    _dustOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10), // Puff in
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30), // Fade on stop
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 20), // No dust on idle
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10), // Puff out
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30), // Fade trail
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Calculate X position based on which phase we are in
        double xPos = 0;
        if (_controller.value < 0.4) {
          xPos = _slideIn.value;
        } else if (_controller.value > 0.6) {
          xPos = _slideOut.value;
        }

        // Combined Y position (bounce)
        double yPos = _bounce.value;

        return SizedBox(
          width: widget.size * 3, // Allow space for sliding
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Dust Trail (Behind bike)
              Positioned(
                bottom: 0,
                left: (widget.size * 1.5) + (xPos * widget.size) - 40, 
                // The logic above keeps dust attached to bike rear
                child: Opacity(
                  opacity: _dustOpacity.value,
                  child: Image.asset(
                    "assets/images/dust.png",
                    width: widget.size * 0.6,
                    height: widget.size * 0.4,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

              // The Bike - REMOVED ColorFiltered widget
              Transform(
                transform: Matrix4.identity()
                  ..translate(xPos * widget.size, yPos) // Move X and Bounce Y
                  ..rotateZ(_tilt.value), // Tilt based on acceleration
                alignment: Alignment.bottomCenter, // Pivot from wheels
                child: Image.asset(
                  "assets/images/bike.png",
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.delivery_dining,
                      size: widget.size,
                      color: AppColors.primary,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}