import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class ImageSlider extends StatefulWidget {
  const ImageSlider({super.key});

  @override
  State<ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<ImageSlider> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentIndex = 0;

  static const _images = [
    'assets/images/img2.png',
    'assets/images/img3.png',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 106,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _images.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(_images[index], fit: BoxFit.cover),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        AnimatedSmoothIndicator(
          activeIndex: _currentIndex,
          count: _images.length,
          effect: const ExpandingDotsEffect(
            dotHeight: 9,
            dotWidth: 9,
            expansionFactor: 3,
            activeDotColor: Color(0xffe30625),
            dotColor: Color(0xffd8d6d2),
            spacing: 10,
          ),
        ),
      ],
    );
  }
}
