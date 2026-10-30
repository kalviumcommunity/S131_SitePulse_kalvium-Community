import 'package:flutter/material.dart';
import 'package:site_pulse/core/theme/app_theme.dart';

/// Modern Harmonious Ambient Background for Site Pulse dashboards.
/// Uses a refined cool-neutral slate canvas (Zinc-100 / Slate-100) with a gentle
/// ambient violet mist that creates balanced, elegant contrast with white cards and buttons
/// without harsh or jarring contrast.
class AppPageBackground extends StatelessWidget {
  final Widget child;

  const AppPageBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFEAECF0), // Refined neutral slate canvas
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEBE8F6), // Subtle soft violet ambient mist at top
            Color(0xFFEAECF0), // Smooth neutral transition
            Color(0xFFE3E6EB), // Grounded cool slate base
          ],
          stops: [0.0, 0.35, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Soft ambient decorative glow orbs (ignored for pointer events)
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 200,
                    left: -40,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF6366F1).withValues(alpha: 0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Foreground content
          child,
        ],
      ),
    );
  }
}
