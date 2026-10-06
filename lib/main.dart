import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

import 'services/delivery_service.dart';
import 'services/agent_fcm_service.dart';
import 'config/api_client.dart';
import 'data/repositories/delivery_repository.dart';
import 'di/injection_container.dart' as di;

import 'blocs/delivery_bloc.dart';

import 'screens/delivery_login_screen.dart';
import 'screens/delivery_dashboard.dart';
import 'screens/splash_screen.dart';

import 'dart:ui';
import 'package:flutter/foundation.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    ApiClient.init(); // Start network listener

    // Capture synchronous Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FLUTTER UI ERROR: ${details.exception}');
      try {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } catch (_) {}
    };

    // Capture asynchronous native/engine errors
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('ASYNC ENGINE ERROR: $error');
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (_) {}
      return true;
    };

    runApp(const AppShell());
  }, (error, stack) {
    debugPrint('ZONED GUARDED ERROR: $error');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}
  });
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize heavy bindings off the main thread or concurrently
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
    } catch (e) {
      print('🔥 Firebase Init Error: $e');
    }
    
    await DeliveryService.init();
    
    await di.init();

    // Defer FCM bindings (non-critical for first frame)
    Future.microtask(() async {
      try {
        FirebaseMessaging.onBackgroundMessage(agentFirebaseMessagingBackgroundHandler);
        await AgentFCMService.init();
        print('FCM initialized');
      } catch (e) {
        print('FCM init error: $e');
      }
    });

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // Immediately render a lightweight frame while Firebase loads
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF00897B),
        ),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => DeliveryBloc(di.sl<DeliveryRepository>())),
      ],
      child: MaterialApp(
        title: 'Foodit Delivery',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
          scaffoldBackgroundColor: const Color(0xFFF5F6F8),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: false,
          ),
        ),
        home: const SplashScreen(), 
        routes: {
          '/login': (context) => const DeliveryLoginScreen(),
          '/delivery_dashboard': (context) {
            AgentFCMService.initAndSendToken();
            context.read<DeliveryBloc>().add(LoadDeliveryDashboard());
            return const DeliveryDashboard();
          },
        },
      ),
    );
  }
}