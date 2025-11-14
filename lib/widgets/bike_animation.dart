// lib/widgets/bike_animation.dart
import 'package:flutter/material.dart';

class BikeAnimation extends StatefulWidget {
  final double size;
  
  const BikeAnimation({super.key, this.size = 120});
  
  @override
  State<BikeAnimation> createState() => _BikeAnimationState();
}

class _BikeAnimationState extends State<BikeAnimation> 
    with SingleTickerProviderStateMixin {
  // Animation constants for better maintainability
  static const double _dustOffsetMultiplier = 0.4;
  static const double _dustWidthMultiplier = 0.8;
  static const double _dustHeightMultiplier = 0.3;
  
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _revAnimation;
  late Animation<double> _dustOpacityAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Faster movement
    )..repeat();
    
    // Main sliding animation (left to right)
    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(-1.5, 0),
          end: const Offset(-0.5, 0),
        ),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(-0.5, 0),
          end: const Offset(0, 0),
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(0, 0)),
        weight: 10, // Pause at center
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0, 0),
          end: const Offset(0.5, 0),
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.5, 0),
          end: const Offset(1.5, 0),
        ),
        weight: 15,
      ),
    ]).animate(_controller);
    
    // Revving animation (up-down movement during pause)
    _revAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 50),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -5)
          .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -5, end: 0)
          .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -3)
          .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -3, end: 0)
          .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 10),
    ]).animate(_controller);
    
    // Dust trail opacity (visible only during movement)
    _dustOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0),
        weight: 10, // Fade out during pause
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 0),
        weight: 10, // Stay hidden during pause
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1),
        weight: 10, // Fade in after pause
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1),
        weight: 20,
      ),
    ]).animate(_controller);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Delivery bike animation',
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dust trail
          AnimatedBuilder(
            animation: _controller,
            child: Image.asset(
              "assets/images/dust.png",
              width: widget.size * _dustWidthMultiplier,
              height: widget.size * _dustHeightMultiplier,
              fit: BoxFit.fitWidth,
              errorBuilder: (context, error, stackTrace) {
                // Silent fallback - no dust if asset missing
                return const SizedBox.shrink();
              },
            ),
            builder: (context, child) {
              return Opacity(
                opacity: _dustOpacityAnimation.value,
                child: Transform.translate(
                  offset: Offset(
                    _slideAnimation.value.dx * widget.size - (widget.size * _dustOffsetMultiplier),
                    0,
                  ),
                  child: child,
                ),
              );
            },
          ),
          
          // Bike with sliding and revving animations
          AnimatedBuilder(
            animation: _controller,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0xFFE57373), // Reddish-orange tint
                BlendMode.modulate,
              ),
              child: Image.asset(
                "assets/images/bike.png",
                width: widget.size,
                height: widget.size,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to motorcycle icon if asset missing
                  return Icon(
                    Icons.two_wheeler,
                    size: widget.size * 0.8,
                    color: const Color(0xFFE57373),
                  );
                },
              ),
            ),
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  _slideAnimation.value.dx * widget.size,
                  _revAnimation.value,
                ),
                child: child,
              );
            },
          ),
        ],
      ),
    );
  }
}