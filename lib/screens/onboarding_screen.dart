import 'package:flutter/material.dart';
import 'package:concentric_transition/concentric_transition.dart';
import '../constants/colors.dart';
import '../widgets/bike_animation.dart';

// IMPORTANT: Added required onFinish callback to the widget.
class OnboardingPage extends StatelessWidget {
  final VoidCallback onFinish;

  const OnboardingPage({super.key, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OnboardingPagePresenter(
        pages: [
          // Page 1: Local Flavor and Freshness
          OnboardingPageModel(
            title: '🍽️ Savor the Taste of Home',
            description:
                'Authentic African and local delicacies, prepared with fresh ingredients and love,(๑ᵔ⤙ᵔ๑).',
            bgColor: const Color(0xFFFFEBEE),
            textColor: AppColors.darkText,
            icon: Icons.fastfood_outlined,
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primary,
          ),
          // Page 2: Fast & Reliable Delivery
          OnboardingPageModel(
            title: '⚡ Delivered Fresh, Fast, and Hot',
            description: 'Our dedicated riders ensure your meal arrives piping hot and exactly when you expect it. ( ˘▽˘)っ♨.',
            bgColor: const Color(0xFFFFF5F5),
            textColor: AppColors.darkText,
            showBikeAnimation: true,
            iconBgColor: AppColors.primary,
          ),
          // Page 3: Effortless Ordering & Favorites
          OnboardingPageModel(
            title: '❤️ Find Your Next Favorite Meal',
            description:
                'Easily bookmark your preferred dishes, track your order history, and reorder your comfort food with a single tap. ദ്ദി(˵•̀ ᴗ - ˵)✧.',
            bgColor: AppColors.white,
            textColor: AppColors.darkText,
            icon: Icons.favorite_outline,
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primary,
          ),
        ],
        // FIXED: Call the required callback instead of navigating globally
        onFinish: onFinish,
      ),
    );
  }
}

class OnboardingPagePresenter extends StatefulWidget {
  final List<OnboardingPageModel> pages;
  final VoidCallback? onSkip;
  final VoidCallback? onFinish;

  const OnboardingPagePresenter({
    super.key,
    required this.pages,
    this.onSkip,
    this.onFinish,
  });

  @override
  State<OnboardingPagePresenter> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPagePresenter> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: ConcentricPageView(
        colors: widget.pages.map((p) => p.bgColor).toList(),
        radius: screenWidth * 0.08,
        itemCount: widget.pages.length,
        scaleFactor: 1.5,
        verticalPosition: 0.75,
        opacityFactor: 1.5,
        onChange: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        nextButtonBuilder: (context) => const SizedBox.shrink(),
        itemBuilder: (index) {
          final page = widget.pages[index];
          final isLastPage = index == widget.pages.length - 1;
          
          return SafeArea(
            child: Column(
              children: [
                // Main Content
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon/Animation Section
                      Container(
                        padding: const EdgeInsets.all(20.0),
                        margin: const EdgeInsets.symmetric(vertical: 32.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: page.iconBgColor?.withOpacity(0.15) ?? page.textColor.withOpacity(0.15),
                          boxShadow: [
                            BoxShadow(
                              color: (page.iconBgColor ?? page.textColor).withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: page.showBikeAnimation
                            ? const BikeAnimation(size: 160)
                            : Icon(
                                page.icon ?? Icons.fastfood_outlined,
                                size: screenHeight * 0.12,
                                color: page.iconColor ?? page.textColor,
                              ),
                      ),
                      
                      // Title Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (index == 0) ...[
                              Icon(
                                Icons.restaurant_menu,
                                color: AppColors.primary,
                                size: screenHeight * 0.028,
                              ),
                              const SizedBox(width: 8),
                            ] else if (index == 1) ...[
                              Icon(
                                Icons.bolt,
                                color: AppColors.accent,
                                size: screenHeight * 0.028,
                              ),
                              const SizedBox(width: 8),
                            ] else if (index == 2) ...[
                              Icon(
                                Icons.favorite,
                                color: AppColors.primary,
                                size: screenHeight * 0.028,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                page.title.replaceAll('🍽️', '').replaceAll('⚡', '').replaceAll('❤️', '').trim(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: page.textColor,
                                  fontSize: screenHeight * 0.028,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.1),
                                      offset: const Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Description Section
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: screenWidth * 0.8,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: page.textColor.withOpacity(0.9),
                            fontSize: screenHeight * 0.018,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bottom Section - Buttons
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Page Indicator (Animated Dots)
                      if (!isLastPage)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              widget.pages.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                height: 8.0,
                                width: _currentPage == i ? 24.0 : 8.0,
                                decoration: BoxDecoration(
                                  color: _currentPage == i ? AppColors.primary : Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                              ),
                            ),
                          ),
                        ),
                      
                      // Finish Button (only on last page)
                      if (isLastPage)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: AppColors.primary.withOpacity(0.5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: widget.onFinish,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Let's Go!",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.rocket_launch_rounded,
                                  size: screenHeight * 0.03,
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Skip Button
                      if (!isLastPage)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: page.textColor,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          onPressed: widget.onFinish,
                          child: const Text("Skip"),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class OnboardingPageModel {
  final String title;
  final String description;
  final Color bgColor;
  final Color textColor;
  final IconData? icon;
  final bool showBikeAnimation;
  final Color? iconColor;
  final Color? iconBgColor;

  OnboardingPageModel({
    required this.title,
    required this.description,
    this.bgColor = AppColors.primary,
    this.textColor = AppColors.white,
    this.icon,
    this.showBikeAnimation = false,
    this.iconColor,
    this.iconBgColor,
  });
}
