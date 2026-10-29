import 'package:flutter/material.dart';
import 'package:site_pulse/core/theme/app_theme.dart';

/// Modern Ambient Background for Site Pulse dashboards and pages.
/// Features a subtle top-violet ambient wash and soft radial orbs
/// that give cards depth and polish across the entire application.
class AppPageBackground extends StatelessWidget {
  final Widget child;

  const AppPageBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F7),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEDE9FE), // Soft Violet-100 top ambient wash
            Color(0xFFF3F2F8), // Smooth ambient fade
            Color(0xFFF6F6F9), // Crisp neutral bottom
          ],
          stops: [0.0, 0.18, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Ambient decorative glow orbs (ignored for pointer events)
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    right: -30,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 180,
                    left: -40,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primaryLight.withValues(alpha: 0.08),
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
