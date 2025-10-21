// lib/screens/location.dart

import 'package:flutter/material.dart';
import '../constants/colors.dart';

class LocationScreen extends StatefulWidget {
  final dynamic initialPosition;

  const LocationScreen({super.key, this.initialPosition});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _selectedAddress = "123 Main Street, Nairobi, Kenya"; // Default address
  }

  void _confirmLocation() {
    // return address
    Navigator.pop(context, {
      'address': _selectedAddress ?? 'Default Location',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Delivery Location'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.location_on, size: 48, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Current Location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedAddress ?? 'Loading...',
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Confirm Location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
