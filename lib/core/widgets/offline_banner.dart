import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:site_pulse/core/theme/app_theme.dart';

/// Top banner that listens to network connectivity.
/// When offline: shows "Offline - entries are saved on this device".
/// When online: hidden (SizedBox.shrink).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.overrideOffline,
  });

  /// Optional override for testing offline state without platform channels.
  final bool? overrideOffline;

  bool _isOffline(List<ConnectivityResult> results) {
    if (results.isEmpty) return true;
    return results.every((r) => r == ConnectivityResult.none);
  }

  @override
  Widget build(BuildContext context) {
    if (overrideOffline != null) {
      return overrideOffline! ? _buildBanner() : const SizedBox.shrink();
    }

    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final results = snapshot.data;
        final isOffline = results != null && _isOffline(results);
        if (!isOffline) {
          return const SizedBox.shrink();
        }
        return _buildBanner();
      },
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.warning,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 18, color: Colors.white),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Offline - entries are saved on this device',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
