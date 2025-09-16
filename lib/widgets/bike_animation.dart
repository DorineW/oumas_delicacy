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
    return Stack(
      alignment: Alignment.center,
      children: [
        // Dust trail
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _dustOpacityAnimation.value,
              child: Transform.translate(
                offset: Offset(_slideAnimation.value.dx * widget.size - widget.size * 0.7, 0),
                child: Image.asset(
                  "assets/images/dust.png", // Add a dust trail image to your assets
                  width: widget.size * 0.8,
                  height: widget.size * 0.3,
                  fit: BoxFit.fitWidth,
                ),
              ),
            );
          },
        ),
        
        // Bike with sliding and revving animations
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                _slideAnimation.value.dx * widget.size,
                _revAnimation.value,
              ),
              child: Image.asset(
                "assets/images/bike.png",
                width: widget.size,
                height: widget.size,
              ),
            );
          },
        ),
      ],
    );
  }
}