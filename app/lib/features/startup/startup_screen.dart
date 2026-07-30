import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_motion.dart';
import '../../core/design/app_spacing.dart';
import 'providers/startup_controller.dart';

class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({required this.readyChild, super.key});

  final Widget readyChild;

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen>
    with TickerProviderStateMixin {
  bool _allowTransition = false;

  late final AnimationController _revealController;
  late final AnimationController _pulseController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkOffset;

  @override
  void initState() {
    super.initState();

    _revealController = AnimationController(
      vsync: this,
      duration: AppMotion.brandReveal,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: AppMotion.glowPulse,
    );

    _logoScale = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = CurvedAnimation(
      parent: _revealController,
      curve: const Interval(0, 0.45, curve: Curves.easeOut),
    );

    _wordmarkOpacity = CurvedAnimation(
      parent: _revealController,
      curve: const Interval(0.35, 1, curve: Curves.easeOut),
    );

    _wordmarkOffset =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _revealController,
            curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
          ),
        );

    _revealController.forward();
    _pulseController.repeat(reverse: true);

    Future.microtask(() {
      ref.read(startupControllerProvider.notifier).initialize();
    });
    Future.microtask(() async {
      await ref.read(startupControllerProvider.notifier).initialize();

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      setState(() {
        _allowTransition = true;
      });
    });
  }

  @override
  void dispose() {
    _revealController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startupControllerProvider);

    return AnimatedSwitcher(
      duration: AppMotion.startupExit,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: state.isReady && _allowTransition
          ? KeyedSubtree(key: const ValueKey('ready'), child: widget.readyChild)
          : Scaffold(
              key: const ValueKey('startup'),
              backgroundColor: const Color(0xFF05050A),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      const Spacer(),
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _revealController,
                          _pulseController,
                        ]),
                        builder: (context, child) {
                          final glowStrength =
                              0.18 + (_pulseController.value * 0.22);

                          return Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primaryDark,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: glowStrength,
                                      ),
                                      blurRadius:
                                          34 + (_pulseController.value * 18),
                                      spreadRadius:
                                          4 + (_pulseController.value * 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 52,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FadeTransition(
                        opacity: _wordmarkOpacity,
                        child: SlideTransition(
                          position: _wordmarkOffset,
                          child: Column(
                            children: [
                              Text(
                                'Ovexiq',
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1.2,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'One goal. Complete workflow.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white60,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: AppMotion.statusTransition,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.25),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          state.message,
                          key: ValueKey(state.message),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (state.hasError)
                        FilledButton(
                          onPressed: () {
                            ref
                                .read(startupControllerProvider.notifier)
                                .retry();
                          },
                          child: const Text('Try again'),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            width: 220,
                            height: 4,
                            child: LinearProgressIndicator(
                              value: state.progress,
                              backgroundColor: Colors.white12,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
