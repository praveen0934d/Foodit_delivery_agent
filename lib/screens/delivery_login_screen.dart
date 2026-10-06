import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/delivery_bloc.dart';
import '../screens/delivery_dashboard.dart';

class DeliveryLoginScreen extends StatefulWidget {
  const DeliveryLoginScreen({super.key});

  @override
  State<DeliveryLoginScreen> createState() => _DeliveryLoginScreenState();
}

class _DeliveryLoginScreenState extends State<DeliveryLoginScreen> {
  final Color primaryTeal = const Color(0xFF00897B);

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocConsumer<DeliveryBloc, DeliveryState>(
        listener: (context, state) {
          if (state is DeliveryError) {
            // Stop loading and show error
            _showError(state.message);
          } else if (state is DeliverySignedIn) {
            // Google sign-in succeeded — now load dashboard data
            context.read<DeliveryBloc>().add(LoadDeliveryDashboard());
          } else if (state is DeliveryLoaded) {
            // Data loaded — navigate to dashboard
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const DeliveryDashboard()),
              (route) => false,
            );
          }
        },
        builder: (context, state) {
          // Show spinner only during active Google sign-in or data loading
          // DeliveryInitial = first open, show the sign-in button
          final isLoading = state is DeliveryLoading;
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryTeal.withValues(alpha: 0.1),
                        ),
                        child: Icon(Icons.moped, size: 72, color: primaryTeal),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Delivery Agent Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sign in with your Google account to start delivering.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                    ),
                    const SizedBox(height: 48),

                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryTeal.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryTeal.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: primaryTeal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.verified_user_rounded, color: primaryTeal, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Registered Agents Only', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black87)),
                                const SizedBox(height: 3),
                                Text('Only approved delivery agents can sign in.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Google Sign-In Button
                    GestureDetector(
                      onTap: isLoading ? null : () {
                        context.read<DeliveryBloc>().add(GoogleSignInRequested());
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300, width: 1.5),
                          boxShadow: isLoading ? [] : [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Center(
                          child: isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(width: 22, height: 22,
                                      child: CircularProgressIndicator(color: primaryTeal, strokeWidth: 2.5)),
                                    const SizedBox(width: 14),
                                    const Text('Signing in...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(
                                      'https://www.google.com/favicon.ico',
                                      width: 22, height: 22,
                                      errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata_rounded, color: Colors.red, size: 26),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Continue with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Center(
                      child: Text(
                        'By signing in, you accept the Terms & Privacy Policy',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}