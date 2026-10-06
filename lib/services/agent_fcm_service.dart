
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:foodit_delivery_agent/config/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

@pragma('vm:entry-point')
Future<void> agentFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print(" Background/Terminated message: ${message.notification?.title}");
}

class AgentFCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();


  static bool isViewingActiveDeliveries = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // Must match AndroidManifest.xml
    'High Importance Notifications',
    description: 'Used for important delivery agent notifications.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );


  static final StreamController<String> _newDeliveryStream =
      StreamController<String>.broadcast();
  static Stream<String> get onNewDelivery => 
      _newDeliveryStream.stream.debounceTime(const Duration(milliseconds: 800));


  static String? _pendingOrderId;
  static bool _pendingReload = false;

  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  static StreamSubscription<String>? _onTokenRefreshSub;

  static bool hasPendingReload() => _pendingReload;

  static void clearPendingReload() {
    _pendingReload = false;
    _pendingOrderId = null;
  }

  static Future<void> init() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedAppSub?.cancel();
    await _onTokenRefreshSub?.cancel();

    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('Notification permission denied');
      return;
    }
    print('Agent notification permission granted');

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification tapped: ${response.payload}');
      },
    );

    _onTokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      print('Agent FCM Token refreshed');
      _sendTokenToBackend(newToken);
    });

    _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground: ${message.notification?.title}');

      if (message.data['type'] == 'orders_assigned') {
        _newDeliveryStream.add(message.data['order_id'] ?? '');

        if (!isViewingActiveDeliveries) {
          _showHeadsUpNotification(message);
        }

      } else {
        _showHeadsUpNotification(message);
      }
    });

    _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Background tap: ${message.notification?.title}');

      if (message.data['type'] == 'orders_assigned') {
        _pendingOrderId = message.data['order_id'] ?? '';
        _pendingReload = true;
        _newDeliveryStream.add(_pendingOrderId!);
      }
    });

    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('Killed state tap: ${initialMessage.notification?.title}');

      if (initialMessage.data['type'] == 'orders_assigned') {
        _pendingOrderId = initialMessage.data['order_id'] ?? '';
        _pendingReload = true;
        print(' Pending delivery stored: $_pendingOrderId');
      }
    }
  }

  static Future<void> initAndSendToken() async {
    try {
      String? fcmToken = await _messaging.getToken();

      print('\n=========================================');
      print(' AGENT FCM TOKEN: $fcmToken');
      print('=========================================\n');

      if (fcmToken != null) {
        await _sendTokenToBackend(fcmToken);
      }
    } catch (e) {
      print('Failed to get FCM token: $e');
    }
  }

  static Future<void> _showHeadsUpNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher', 

          styleInformation: BigTextStyleInformation(
            notification.body ?? '',
            contentTitle: notification.title,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  static Future<void> _sendTokenToBackend(String fcmToken) async {
    try {
      String? authToken = await _storage.read(key: 'access_token');
      print(' POST → ${ApiConfig.baseUrl}/delivery/fcm-token');
      
      final response = await ApiClient.requestWithRetry(() async {
        return await ApiClient.client.post(
          Uri.parse('${ApiConfig.baseUrl}/delivery/fcm-token'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (authToken != null) 'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode({'fcm_token': fcmToken}),
        );
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Agent FCM Token saved to backend!');
      } else {
        print('Backend rejected Agent FCM Token: ${response.body}');
      }
    } catch (e) {
      print('Error sending Agent FCM token: $e');
    }
  }

  static Future<void> clearTokenOnLogout() async {
    await _sendTokenToBackend('');
    await _messaging.deleteToken();
    print(' Agent FCM Token cleared on logout');
  }
}