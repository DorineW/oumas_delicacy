// lib/utils/error_snackbar.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';

/// Helper class to show consistent error messages across the app
class ErrorSnackbar {
  /// Check if error is network-related
  static bool _isNetworkError(dynamic error) {
    if (error == null) return false;
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socket') ||
           errorString.contains('network') ||
           errorString.contains('connection') ||
           errorString.contains('timeout') ||
           error is SocketException ||
           error is TimeoutException ||
           error is HttpException;
  }

  /// Get user-friendly error message
  static String _getUserFriendlyMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred';
    
    if (_isNetworkError(error)) {
      return 'No internet connection. Please check your network and try again.';
    }
    
    if (error is PostgrestException) {
      return 'Database error. Please try again or check your connection.';
    }
    
    if (error is AuthException) {
      return error.message;
    }
    
    String message = error.toString();
    if (message.contains('\n')) {
      message = message.split('\n').first;
    }
    if (message.length > 100) {
      message = '${message.substring(0, 100)}...';
    }
    return message.isEmpty ? 'An error occurred. Please try again.' : message;
  }

  /// Show an error snackbar with user-friendly message
  static void show(BuildContext context, dynamic error, {String? prefix}) {
    final message = _getUserFriendlyMessage(error);
    final fullMessage = prefix != null ? '$prefix: $message' : message;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isNetworkError(error) 
                  ? Icons.signal_wifi_off 
                  : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fullMessage,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Show a network connectivity error with retry option
  static void showNetworkError(
    BuildContext context, 
    {required VoidCallback onRetry}
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.signal_wifi_off, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No internet connection. Please check your network.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: onRetry,
        ),
      ),
    );
  }
  
  /// Show a success message
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  /// Show a warning message
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  /// Show an info message
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
