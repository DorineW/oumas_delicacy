import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/connectivity_provider.dart';

class NoConnectionScreen extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? customMessage;

  const NoConnectionScreen({
    super.key,
    this.onRetry,
    this.customMessage,
  });

  void _retryConnectionCheck(BuildContext context) {
    if (onRetry != null) {
      onRetry!();
    } else {
      _tryProviderRetry(context);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking connection...'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _tryProviderRetry(BuildContext context) {
    try {
      final connectivityProvider = context.read<ConnectivityProvider?>();
      connectivityProvider?.retry();
    } catch (e) {
      debugPrint('No connectivity provider found: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildConnectionIcon(),
                const SizedBox(height: 32),
                Text(
                  'Connection Lost',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  customMessage ??
                      'We can\'t connect to the server right now. '
                      'Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.darkText.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                _buildRetryButton(context),
                const SizedBox(height: 16),
                _buildSettingsButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
        ),
        Icon(
          Icons.wifi_off_rounded,
          size: 64,
          color: AppColors.darkText.withOpacity(0.5),
        ),
        Positioned(
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.close,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRetryButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () => _retryConnectionCheck(context),
        icon: const Icon(Icons.refresh, color: AppColors.white),
        label: const Text(
          'Try Again',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    return TextButton(
      onPressed: () => _openNetworkSettings(context),
      child: const Text(
        'Open Network Settings',
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _openNetworkSettings(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Redirecting to network settings...'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    // Later you can use url_launcher or app_settings package here
  }
}
