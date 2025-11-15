// lib/widgets/smart_product_image.dart
import 'package:flutter/material.dart';

class SmartProductImage extends StatelessWidget {
  final String imageUrl;
  final bool removeBackground;
  final double height;
  final double width;
  final BoxDecoration? containerDecoration;

  const SmartProductImage({
    super.key,
    required this.imageUrl,
    this.removeBackground = true,
    this.height = 120,
    this.width = 120,
    this.containerDecoration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: containerDecoration ?? BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          if (removeBackground) ...[
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        
          Center(
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                1, 0, 0, 0, 0,
                0, 1, 0, 0, 0,
                0, 0, 1, 0, 0,
                0, 0, 0, 0.95, 0,
              ]),
              child: imageUrl.isEmpty
                  ? Container(
                      height: height,
                      width: width,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      height: height,
                      width: width,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: height,
                          width: width,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
