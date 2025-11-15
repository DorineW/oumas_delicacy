import 'dart:async';
import 'package:flutter/material.dart';

// --- START: CarouselCard Component (The visual wrapper) ---

/// A container designed for the Carousel to give items a modern,
/// rounded, and 'demure' card look with a subtle shadow.
class CarouselCard extends StatelessWidget {
  final Widget child;

  const CarouselCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Provides the 'demure' curved look with a subtle shadow
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0), // Rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3), // subtle shadow
          ),
        ],
      ),
      // Clip the content (image/text) to match the container's rounded corners
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: child,
      ),
    );
  }
}

// --- END: CarouselCard Component ---
// -----------------------------------------------------------------
// --- START: Carousel Component (The logic handler) ---

/// Generic auto-scrolling carousel with a page indicator.
/// [children] : any widgets you want to rotate (typically wrapped in CarouselCard).
/// [height]   : fixed height (default 140).
/// [interval] : auto-switch interval (default 4s).
/// [curve]    : page transition curve.
/// [viewport] : % of screen width each page occupies (default .82).
class Carousel extends StatefulWidget {
  final List<Widget> children;
  final double height;
  final Duration interval;
  final Curve curve;
  final double viewport;

  const Carousel({
    super.key,
    required this.children,
    this.height = 140,
    this.interval = const Duration(seconds: 4),
    this.curve = Curves.easeOutCubic,
    this.viewport = .82,
  });

  @override
  State<Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<Carousel> {
  late final PageController _pageCtrl;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: widget.viewport);

    // Start timer only if there are items and auto-scrolling is enabled
    if (widget.interval != Duration.zero && widget.children.length > 1) {
      _startTimer();
    }
  }

  /// Starts the auto-scroll timer.
  void _startTimer() {
    _timer?.cancel();
    // Use addPostFrameCallback to ensure the PageView is initialized before starting timer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _timer = Timer.periodic(widget.interval, (_) => _nextPage());
      }
    });
  }

  /// Pauses the auto-scroll timer.
  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Animates the carousel to the next page.
  void _nextPage() {
    if (!mounted || widget.children.length <= 1 || !_pageCtrl.hasClients) return;

    // Calculate the next page index
    _page = (_page + 1) % widget.children.length;
    
    // Animate the page transition
    _pageCtrl.animateToPage(
      _page,
      duration: const Duration(milliseconds: 450),
      curve: widget.curve,
    );
  }

  /// Handles user interaction to pause/resume the timer.
  bool _handleScrollNotification(Notification notification) {
    if (notification is ScrollStartNotification) {
      // User started dragging, pause the timer
      if (_timer != null) {
        _pauseTimer();
      }
    } else if (notification is ScrollEndNotification) {
      // User stopped dragging, restart the timer after a short delay
      if (_timer == null && widget.children.length > 1) {
        // Wait a moment for the user to settle before resuming
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _startTimer();
          }
        });
      }
    }
    return false;
  }

  @override
  void dispose() {
    _pauseTimer();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();
    
    // Handle the case where there is only one child (no scrolling needed)
    if (widget.children.length == 1) {
      return SizedBox(
        height: widget.height,
        child: Center(child: widget.children.first),
      );
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. PageView for the scrolling content
        SizedBox(
          height: widget.height,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.children.length,
              onPageChanged: (i) {
                setState(() => _page = i); // Update the page index for the indicator
              },
              itemBuilder: (_, i) => Padding(
                // Minimal horizontal padding to allow cards to take up max space
                padding: const EdgeInsets.symmetric(horizontal: 4), 
                child: widget.children[i],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 10), // Spacing between carousel and indicator
        
        // 2. Page Indicator (Dots)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.children.length,
            (index) => _buildIndicator(index == _page),
          ),
        ),
      ],
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8.0,
      width: isActive ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: isActive ? Colors.deepOrange : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(4.0),
      ),
    );
  }
}
// --- END: Carousel Component ---