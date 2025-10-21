import 'dart:async';
import 'package:flutter/material.dart';

/// Generic auto-scrolling carousel.
/// [children] : any widgets you want to rotate.
/// [height]   : fixed height (default 140).
/// [interval] : auto-switch interval (default 4s).
/// [curve]    : page transition curve.
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

    // Start timer after a delay to ensure PageView is built
    if (widget.interval != Duration.zero && widget.children.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _timer = Timer.periodic(widget.interval, (_) => _nextPage());
        }
      });
    }
  }

  void _nextPage() {
    if (!mounted) return;
    if (widget.children.length <= 1) return;
    if (!_pageCtrl.hasClients) return;

    _page = (_page + 1) % widget.children.length;
    _pageCtrl.animateToPage(
      _page,
      duration: const Duration(milliseconds: 450),
      curve: widget.curve,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: widget.height,
      child: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.children.length,
        onPageChanged: (i) => _page = i,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: widget.children[i],
        ),
      ),
    );
  }
}