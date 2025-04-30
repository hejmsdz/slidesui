import 'dart:math';

import 'package:flutter/material.dart';
import 'package:slidesui/strings.dart';

class PresentationOnboarding extends StatefulWidget {
  const PresentationOnboarding({super.key, this.onComplete});

  final void Function()? onComplete;

  @override
  State<PresentationOnboarding> createState() => _PresentationOnboardingState();
}

class _PresentationOnboardingState extends State<PresentationOnboarding> {
  int _currentStep = 0;

  final List<Widget Function()> _steps = [
    () => Stack(
          children: [
            const SwipeIndicator(direction: SwipeDirection.left),
            OnboardingText(text: strings['onboardingSwipeLeft']!),
          ],
        ),
    () => Stack(
          children: [
            const SwipeIndicator(direction: SwipeDirection.right),
            OnboardingText(text: strings['onboardingSwipeRight']!),
          ],
        ),
    () => Stack(
          children: [
            const DoubleTapIndicator(alignmentX: 0.8),
            OnboardingText(text: strings['onboardingDoubleTapRight']!),
          ],
        ),
    () => Stack(
          children: [
            const DoubleTapIndicator(alignmentX: -0.8),
            OnboardingText(text: strings['onboardingDoubleTapLeft']!),
          ],
        ),
    () => Stack(
          children: [
            const DoubleTapIndicator(alignmentX: 0),
            OnboardingText(text: strings['onboardingDoubleTapCenter']!),
          ],
        ),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: true,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black87,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
        Builder(
          builder: (context) {
            if (_currentStep >= _steps.length) return Container();
            return _steps[_currentStep]();
          },
        ),
        Align(
          alignment: Alignment(0, 1),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  child: Text(strings['ok']!),
                  onPressed: () {
                    setState(() {
                      _currentStep++;
                    });

                    if (_currentStep >= _steps.length) {
                      widget.onComplete?.call();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class Dot extends StatelessWidget {
  const Dot({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

enum SwipeDirection {
  left,
  right,
}

class SwipeIndicator extends StatefulWidget {
  const SwipeIndicator({super.key, required this.direction});

  final SwipeDirection direction;

  @override
  State<SwipeIndicator> createState() => _SwipeIndicatorState();
}

class _SwipeIndicatorState extends State<SwipeIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1, milliseconds: 500),
      vsync: this,
    )..repeat(reverse: false, period: const Duration(seconds: 2));

    final isLeft = widget.direction == SwipeDirection.left;
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.0),
      end: const Offset(-10.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: isLeft ? Curves.ease : Curves.easeIn,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInQuad,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLeft = widget.direction == SwipeDirection.left;

    return Align(
      alignment: Alignment(isLeft ? 0.8 : -0.8, 0),
      child: Transform(
        transform: Matrix4.identity()..scale(isLeft ? 1.0 : -1.0, 1.0, 1.0),
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Dot(),
          ),
        ),
      ),
    );
  }
}

class DoubleTapIndicator extends StatefulWidget {
  const DoubleTapIndicator({super.key, required this.alignmentX});

  final double alignmentX;

  @override
  State<DoubleTapIndicator> createState() => _DoubleTapIndicatorState();
}

class DoubleTapCurve extends Curve {
  @override
  double transform(double t) {
    if (t > 2 / 3) {
      return 0;
    }
    return (sin(3 * t * pi)).abs();
  }
}

class _DoubleTapIndicatorState extends State<DoubleTapIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: false, period: const Duration(milliseconds: 1200));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: DoubleTapCurve(),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(widget.alignmentX, 0),
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Dot(),
      ),
    );
  }
}

class OnboardingText extends StatelessWidget {
  const OnboardingText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(0, 0.6),
      child: Text(
        text,
        style: TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}
