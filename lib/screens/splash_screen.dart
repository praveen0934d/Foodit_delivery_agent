import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:foodit_delivery_agent/config/api_config.dart';
import 'package:foodit_delivery_agent/screens/testing_mode_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:foodit_delivery_agent/screens/delivery_login_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foodit_delivery_agent/services/delivery_service.dart';
import 'package:foodit_delivery_agent/data/repositories/config_repository.dart';
import 'package:foodit_delivery_agent/di/injection_container.dart' as di;
import 'package:foodit_delivery_agent/blocs/delivery_bloc.dart';

// Update these imports to match your actual file structure
import 'delivery_dashboard.dart';
// import 'login_screen.dart'; // Uncomment and point to your actual login screen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulseAnim;

  // Version Check States
  bool _needsUpdate = false;
  String _updateUrl = '';

  // Delivery Theme Color (From your Dashboard)
  final Color primaryTeal = const Color(0xFF00897B);
  bool _networkError = false;

  @override
  void initState() {
    super.initState();

    // 1. Initialize Animations
    _setupAnimations();

    // 2. Check App Version FIRST
    _checkAppVersion();
  }

  Future<void> _checkAppVersion() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/test')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['deli_app'] == true) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TestingModeScreen()),
            );
          }
          return;
        }
      }
    } catch (e) {
      print("❌ TESTING MODE CHECK FAILED: $e");
    }

    try {
      final configRepo = di.sl<ConfigRepository>();
      final config = await configRepo.checkAppVersion();
      
      if (config.needsUpdate) {
        print("🛑 VERSIONS DO NOT MATCH! LOCKING APP.");
        if (mounted) {
          setState(() {
            _needsUpdate = true;
            _updateUrl = config.updateUrl;
          });
        }
        return; // Stop here and show the update screen!
      }
    } catch (e) {
      // If you see this in your logs, your campus Wi-Fi blocked the request entirely
      print("⏱VERSION CHECK SKIPPED (Network blocked or too slow): $e");
    }

    if (mounted && !_needsUpdate) {
      _checkAuthAndNavigate();
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      final service = DeliveryService();
      final isValid = await service.isTokenValid();

      if (!mounted) return;

      if (isValid) {
        context.read<DeliveryBloc>().add(LoadDeliveryDashboard());
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeliveryDashboard()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeliveryLoginScreen()));
        print("Token invalid or missing! Redirecting to Login...");
      }
    } catch (e) {
      print("Auth check failed: $e");
      if (mounted) {
        setState(() {
          _networkError = true;
        });
      }
    }
  }

  void _setupAnimations() {
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn);

    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn);
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _logoCtrl.forward().then((_) => _textCtrl.forward());
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchUpdateUrl() async {
    final Uri url = Uri.parse(_updateUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $_updateUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryTeal, const Color(0xFF26A69A), const Color(0xFF4DB6AC)], // Teal gradients
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(top: -60, right: -60,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(width: 220, height: 220,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), shape: BoxShape.circle)),
                ),
              ),
            ),
            Positioned(bottom: -80, left: -80,
              child: Container(width: 280, height: 280,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle)),
            ),
            Positioned(bottom: 100, right: 40,
              child: Container(width: 60, height: 60,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle)),
            ),

            // Main content
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: _needsUpdate
                    ? _buildUpdateUI()
                    : _networkError
                        ? _buildNetworkErrorUI()
                        : _buildSplashContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── UPDATE REQUIRED UI ───
  Widget _buildUpdateUI() {
    return Container(
      key: const ValueKey('update_ui'),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 15)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: primaryTeal.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.system_security_update_rounded, size: 56, color: primaryTeal),
          ),
          const SizedBox(height: 24),
          const Text(
            "Update Required",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 12),
          Text(
            "A new version of FOODIT Agent is available. Please update to continue delivering.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _launchUpdateUrl,
              child: const Text("Download Update", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  // ─── NETWORK ERROR / RETRY UI ───
  Widget _buildNetworkErrorUI() {
    return Container(
      key: const ValueKey('network_error_ui'),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 15)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.orange),
          ),
          const SizedBox(height: 24),
          const Text(
            "Connection Issue",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 12),
          Text(
            "Could not verify your session. Please check your internet connection and try again.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                setState(() {
                  _networkError = false;
                });
                _checkAuthAndNavigate();
              },
              child: const Text("Try Again", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── NORMAL SPLASH UI ───
  Widget _buildSplashContent() {
    return Column(
      key: const ValueKey('splash_ui'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo
        ScaleTransition(
          scale: _logoScale,
          child: FadeTransition(
            opacity: _logoFade,
            child: Container(
              height: 110, width: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 12)),
                ],
              ),
              child: Icon(Icons.moped_rounded, size: 68, color: primaryTeal),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Text
        SlideTransition(
          position: _textSlide,
          child: FadeTransition(
            opacity: _textFade,
            child: Column(
              children: [
                const Text(
                  'foodit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'AGENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80),

        // Loading dots
        FadeTransition(
          opacity: _textFade,
          child: _LoadingDots(),
        ),
      ],
    );
  }
}

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}