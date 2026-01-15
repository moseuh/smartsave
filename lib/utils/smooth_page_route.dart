import 'package:flutter/material.dart';

/// Smooth page transition animations for professional UX
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;
  final PageTransitionType transitionType;

  SmoothPageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 400),
    this.transitionType = PageTransitionType.slideRight,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _buildTransition(
              animation,
              secondaryAnimation,
              child,
              transitionType,
            );
          },
        );
}

enum PageTransitionType {
  slideRight,
  slideUp,
  fade,
  scale,
  fadeScale,
  slideRightFade,
}

Widget _buildTransition(
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
  PageTransitionType type,
) {
  const curve = Curves.easeInOutCubic;

  switch (type) {
    case PageTransitionType.slideRight:
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: curve)),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.3, 0.0),
          ).animate(CurvedAnimation(parent: secondaryAnimation, curve: curve)),
          child: child,
        ),
      );

    case PageTransitionType.slideUp:
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: curve)),
        child: child,
      );

    case PageTransitionType.fade:
      return FadeTransition(
        opacity: animation,
        child: child,
      );

    case PageTransitionType.scale:
      return ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: curve),
        ),
        child: child,
      );

    case PageTransitionType.fadeScale:
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: curve),
          ),
          child: child,
        ),
      );

    case PageTransitionType.slideRightFade:
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.3, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: curve)),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
  }
}

/// Extension for easy navigation with smooth transitions
extension SmoothNavigation on BuildContext {
  Future<T?> pushSmooth<T>(
    Widget page, {
    PageTransitionType type = PageTransitionType.slideRight,
  }) {
    return Navigator.push<T>(
      this,
      SmoothPageRoute<T>(page: page, transitionType: type),
    );
  }

  Future<T?> pushReplacementSmooth<T>(
    Widget page, {
    PageTransitionType type = PageTransitionType.fade,
  }) {
    return Navigator.pushReplacement<T, void>(
      this,
      SmoothPageRoute<T>(page: page, transitionType: type),
    );
  }
}
