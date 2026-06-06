import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class ImageSlider extends StatefulWidget {
  const ImageSlider({super.key});

  @override
  State<ImageSlider> createState() => _PageViewState();
}

class _PageViewState extends State<ImageSlider> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentIndex = 0;

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
          height: 90,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              //_buildImage('assets/images/img1.png'),
              _buildImage('assets/images/img2.png'),
              _buildImage('assets/images/img3.png'),
            ],
          ),
        ),

        const SizedBox(height: 25),

        AnimatedSmoothIndicator(
          activeIndex: _currentIndex,
          count: 2,
          effect: ExpandingDotsEffect(
            dotHeight: 8,
            dotWidth: 8,
            expansionFactor: 3,
            activeDotColor: Color.fromARGB(255, 219, 7, 35),
            dotColor: Color.fromARGB(255, 215, 213, 209),
            spacing: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildImage(String path) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(path, fit: BoxFit.cover),
      ),
    );
  }
}
