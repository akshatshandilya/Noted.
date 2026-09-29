import 'dart:async';

import 'package:flutter/material.dart';
import 'noted_logo_animation.dart';
import 'splash_config.dart';

/// Launch screen. Plays the wordmark reveal on the app's own background
/// (light or dark, following the theme), holds briefly, then fades into
/// [next]. With reduced motion enabled it skips the reveal: fade in → hold →
/// fade out.
class NotedSplashScreen extends StatefulWidget {
  final Widget next;
  const NotedSplashScreen({super.key, required this.next});

  @override
  State<NotedSplashScreen> createState() => _NotedSplashScreenState();
}

class _NotedSplashScreenState extends State<NotedSplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _reduceMotion = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: SplashConfig.revealMs),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) {
      _controller.value = 1; // wordmark fully visible, gently faded in below
      _timer = Timer(const Duration(milliseconds: SplashConfig.reducedMotionHoldMs), _goNext);
    } else {
      _controller.forward();
      _timer = Timer(
        Duration(milliseconds: SplashConfig.revealMs + SplashConfig.holdMs),
        _goNext,
      );
    }
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: SplashConfig.exitFadeMs),
      pageBuilder: (_, __, ___) => widget.next,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic), child: child),
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = NotedLogoAnimation(controller: _controller);
    return Scaffold(
      body: Center(
        child: _reduceMotion
            ? TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 300),
                builder: (_, v, child) => Opacity(opacity: v, child: child),
                child: logo,
              )
            : logo,
      ),
    );
  }
}
