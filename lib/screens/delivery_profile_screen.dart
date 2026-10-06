import 'package:flutter/material.dart';
import '../services/delivery_service.dart';

import '../models/delivery_model.dart';

class DeliveryProfileScreen extends StatelessWidget {
  final DeliveryProfile profileData;
  const DeliveryProfileScreen({super.key, required this.profileData});

  final Color primaryTeal = const Color(0xFF00897B);

  Future<void> _handleLogout(BuildContext context) async {
    // (server notification, Firebase sign-out, Google sign-out, token removal)
    final service = DeliveryService();
    await service.logout();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDelivered = profileData.totalDelivered;
    final activeOrdersCount = profileData.activeOrdersCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('My Profile', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: primaryTeal.withValues(alpha: 0.1),
                  child: Icon(Icons.moped, size: 40, color: primaryTeal),
                ),
                const SizedBox(height: 16),
                Text(
                  profileData.name,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  profileData.phone,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: primaryTeal, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      const Text('Total Delivered', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('$totalDelivered', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    children: [
                      const Text('Active Orders', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('$activeOrdersCount', style: const TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Logout Button
          SizedBox(
            width: double.infinity, height: 55,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () => _handleLogout(context),
            ),
          ),
        ],
      ),
    );
  }
}