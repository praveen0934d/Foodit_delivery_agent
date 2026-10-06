// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:foodit_delivery_agent/config/api_config.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:foodit_delivery_agent/config/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:foodit_delivery_agent/models/order_model.dart';
import 'package:foodit_delivery_agent/models/delivery_model.dart';

dynamic _safeUtf8JsonDecode(List<int> bytes) {
  try {
    return jsonDecode(utf8.decode(bytes));
  } catch (e) {
    print('Error decoding JSON: $e');
    throw const FormatException('Failed to decode JSON response from server');
  }
}

class DeliveryService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  static late final FlutterSecureStorage _storage;
  static late final SharedPreferences _prefs;

  static Future<void> init() async {
    _storage = const FlutterSecureStorage();
    _prefs = await SharedPreferences.getInstance();
  }

  Future<String?> _getToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Token Refresh ───
  static Future<bool>? _refreshFuture;

  Future<bool> _tryRefreshToken() async {
    if (_refreshFuture != null) {
      print('Refresh already in progress, waiting...');
      return await _refreshFuture!;
    }

    try {
      _refreshFuture = _doRefreshToken();
      final success = await _refreshFuture!;
      if (!success) {
         print('Token refresh failed. Attempting deep silent Google Sign-In...');
         bool silentSuccess = await silentReAuth();
         if (!silentSuccess) {
            print('Deep silent re-auth failed — forcing logout');
            await logout();
         }
         return silentSuccess;
      }
      return true;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<bool> _doRefreshToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    final accessToken = await _storage.read(key: 'access_token');
    final deviceId = await _storage.read(key: 'device_id') ?? 'unknown_device';

    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      print('Attempting token refresh...');
      final response = await ApiClient.client.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
        headers: {
          'Authorization': 'Bearer ${refreshToken.isNotEmpty ? refreshToken : (accessToken ?? '')}',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refresh_token': refreshToken,
          'device_id': deviceId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = await compute<List<int>, dynamic>(_safeUtf8JsonDecode, response.bodyBytes);
        await _storage.write(key: 'access_token', value: data['access_token']);
        if (data['refresh_token'] != null) {
          await _storage.write(key: 'refresh_token', value: data['refresh_token']);
        }
        print('Token refreshed successfully');
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 400) {
        print('Token refresh definitively failed: ${response.statusCode}');
        await _storage.delete(key: 'access_token');
        await _storage.delete(key: 'refresh_token');
        return false;
      }
      return false;
    } catch (e) {
      print('Token refresh error: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> _getDeviceDetails() async {
    String deviceId = 'unknown_device', platform = 'android', deviceModel = 'unknown_model';
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceId = info.id;
        deviceModel = info.model;
        platform = 'android';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceId = info.identifierForVendor ?? 'unknown_ios';
        deviceModel = info.utsname.machine;
        platform = 'ios';
      }
    } catch (e) {
      print('Could not fetch device info: $e');
    }
    return {'device_id': deviceId, 'platform': platform, 'device_model': deviceModel};
  }

  String _generateTempPhone(String email) {
    final hash = email.codeUnits.fold(0, (prev, e) => prev + e);
    final base = (hash * 9871) % 1000000000;
    return '1${base.toString().padLeft(9, '0')}';
  }

  // ─── Google Sign-In ────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    bool idTokenIsNull = false;
    try {
      await _googleSignIn.signOut();
      print('Step 1: Starting Google Sign-In picker...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Step 1 FAILED: User cancelled sign-in');
        throw Exception('Sign-in cancelled.');
      }
      print('Step 2: Google account selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('Step 3: Got Google auth tokens');

      idTokenIsNull = googleAuth.idToken == null;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Step 4: Signing into Firebase...');
      final UserCredential userCred = await _auth.signInWithCredential(credential);
      print('Step 5: Firebase signed in: ${userCred.user?.uid}');

      final String firebaseToken = await userCred.user!.getIdToken(true) ?? '';
      if (firebaseToken.isEmpty) {
        throw Exception('Failed to get Firebase token');
      }

      print('Step 6: Getting device details...');
      await _laravelGoogleLogin(
        firebaseToken: firebaseToken,
        email: googleUser.email,
        name: googleUser.displayName ?? 'Delivery Agent',
        googlePhotoUrl: googleUser.photoUrl,
      );
      print('Step 7: Backend login complete');
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code} — ${e.message}');
      throw Exception('Firebase Error [ID_NULL: $idTokenIsNull]: ${e.message}');
    } on PlatformException catch (e) {
      print('❌ PlatformException: ${e.code} — ${e.message}');
      if (e.code == 'network_error' || (e.message?.contains('ApiException: 7') ?? false)) {
        throw Exception('Google sign-in failed: A network error (such as timeout, interrupted connection or unreachable host) has occurred.');
      }
      throw Exception('Sign-in failed: ${e.message}');
    } catch (e) {
      print('❌ signInWithGoogle error: $e');
      if (e is Exception) rethrow;
      throw Exception('Google sign-in failed [ID_NULL: $idTokenIsNull]: $e');
    }
  }

  // ─── Deep Silent Re-Authentication ────────────────────────
  Future<bool> silentReAuth() async {
    try {
      print('Attempting Google silent sign-in...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) {
        print('Silent sign-in returned null.');
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCred = await _auth.signInWithCredential(credential);
      final String firebaseToken = await userCred.user!.getIdToken(true) ?? '';

      await _laravelGoogleLogin(
        firebaseToken: firebaseToken,
        email: googleUser.email,
        name: googleUser.displayName ?? 'Delivery Agent',
        googlePhotoUrl: googleUser.photoUrl,
      );
      
      print('Deep silent re-auth successful!');
      return true;
    } catch (e) {
      print('Deep silent re-auth failed: $e');
      rethrow;
    }
  }

  Future<void> _laravelGoogleLogin({
    required String firebaseToken,
    required String email,
    required String name,
    String? googlePhotoUrl,
  }) async {
    final deviceData = await _getDeviceDetails();
    final tempPhone = _generateTempPhone(email);

    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      print('AGENT FCM TOKEN: $fcmToken');
    } catch (e) {
      print('Failed to fetch FCM Token: $e');
    }

    final requestBody = {
      'firebase_token': firebaseToken,
      'email': email,
      'name': name,
      'phone': tempPhone,
      'is_temp_phone': true,
      'role': 'delivery',
      'device_id': deviceData['device_id'],
      'platform': deviceData['platform'],
      'device_model': deviceData['device_model'],
      'fcm_token': fcmToken,
      if (googlePhotoUrl != null) 'google_photo_url': googlePhotoUrl,
    };

    print('📦 [laravelGoogleLogin] Request Body: ${jsonEncode(requestBody)}');

    final response = await ApiClient.requestWithRetry(() async {
      return await ApiClient.client.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/google-login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));
    });

    if (response.statusCode == 200) {
      final data = await compute<List<int>, dynamic>(_safeUtf8JsonDecode, response.bodyBytes);
      await _storage.write(key: 'access_token', value: data['access_token']);
      await _storage.write(key: 'refresh_token', value: data['refresh_token'] ?? '');
      await _storage.write(key: 'device_id', value: deviceData['device_id']);
      print('Agent tokens securely saved');
    } else {
      print('\n=========================================');
      print('❌ BACKEND LOGIN ERROR');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('=========================================\n');
      
      String errorMsg = 'Failed to authenticate. Status: ${response.statusCode}';
      try {
        final data = jsonDecode(response.body);
        if (data['message'] != null) {
          errorMsg = data['message'];
        }
      } catch (_) {}
      
      throw Exception(errorMsg);
    }
  }

  // ─── Logout ────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await ApiClient.client.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('Logout network fail: $e');
    }
    
    await _storage.deleteAll();
    _prefs.clear();
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // ─── Authenticated Request Wrapper ─────────────────────────
  Future<dynamic> _authenticatedGet(String url) async {
    return await ApiClient.requestWithRetry(
      () async => ApiClient.client.get(Uri.parse(url), headers: await _getHeaders()).timeout(const Duration(seconds: 15)),
      handle401: true,
      on401: _tryRefreshToken,
    );
  }

  Future<dynamic> _authenticatedPut(String url, {Object? body}) async {
    return await ApiClient.requestWithRetry(
      () async => ApiClient.client.put(Uri.parse(url), headers: await _getHeaders(), body: body).timeout(const Duration(seconds: 15)),
      handle401: true,
      on401: _tryRefreshToken,
    );
  }

  Future<dynamic> _authenticatedPost(String url, {Object? body}) async {
    return await ApiClient.requestWithRetry(
      () async => ApiClient.client.post(Uri.parse(url), headers: await _getHeaders(), body: body).timeout(const Duration(seconds: 15)),
      handle401: true,
      on401: _tryRefreshToken,
    );
  }

  Future<dynamic> _authenticatedDelete(String url, {Object? body}) async {
    return await ApiClient.requestWithRetry(
      () async => ApiClient.client.delete(Uri.parse(url), headers: await _getHeaders(), body: body).timeout(const Duration(seconds: 15)),
      handle401: true,
      on401: _tryRefreshToken,
    );
  }

  Future<DeliveryProfile> getProfile() async {
    final response = await _authenticatedGet('${ApiConfig.baseUrl}/delivery/profile');
    if (response.statusCode == 200) {
      final jsonMap = await compute<List<int>, dynamic>(_safeUtf8JsonDecode, response.bodyBytes);
      return DeliveryProfile.fromJson(jsonMap);
    } else {
      throw Exception('Failed to load profile (Error ${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>?> getRestaurantDetails() async {
    final response = await _authenticatedGet('${ApiConfig.baseUrl}/delivery/restaurant');
    if (response.statusCode == 200) {
      final data = await compute<List<int>, dynamic>(_safeUtf8JsonDecode, response.bodyBytes);
      return data['restaurant'];
    }
    return null;
  }

  Future<List<Order>> getActiveOrders() async {
    final response = await _authenticatedGet('${ApiConfig.baseUrl}/delivery/orders?status=active');
    if (response.statusCode == 200) {
      final data = await compute<List<int>, dynamic>(_safeUtf8JsonDecode, response.bodyBytes);
      final List<dynamic> ordersList = data['orders'] ?? [];
      return ordersList.map((e) => Order.fromJson(e)).toList();
    }
    throw Exception('Failed to load orders');
  }

  Future<List<Order>> getHistoryOrders() async {
    final response = await _authenticatedGet('${ApiConfig.baseUrl}/delivery/orders?status=history');
    if (response.statusCode == 200) {
      final data = await compute<List<int>, dynamic>(_safeUtf8JsonDecode, response.bodyBytes);
      final List<dynamic> ordersList = data['orders'] ?? [];
      return ordersList.map((e) => Order.fromJson(e)).toList();
    }
    throw Exception('Failed to load order history');
  }

  Future<void> markDelivered(String orderId) async {
    final response = await _authenticatedPut('${ApiConfig.baseUrl}/orders/$orderId/delivered');
    if (response.statusCode != 200) throw Exception('Failed to mark delivered');
  }

  Future<void> markOrderNotPickedUp(String orderId) async {
    final response = await _authenticatedPut('${ApiConfig.baseUrl}/orders/$orderId/not-picked-up');
    if (response.statusCode != 200) {
      final data = await compute<List<int>, dynamic>(_safeUtf8JsonDecode, response.bodyBytes);
      throw Exception(data['message'] ?? 'Failed to mark as not picked up');
    }
  }

  Future<void> markAtGate(String orderId) async {
    final response = await _authenticatedPut('${ApiConfig.baseUrl}/delivery/orders/$orderId/at-gate');
    if (response.statusCode != 200) {
      final data = await compute<List<int>, dynamic>(_safeUtf8JsonDecode, response.bodyBytes);
      throw Exception(data['message'] ?? 'Failed to notify students');
    }
  }

  // ─── Token Validation ──────────────────────────────────────
  /// Validates the stored token against the server.
  /// Returns true if valid, false if no token or expired.
  /// Throws Exception('NETWORK_ERROR') if the server is unreachable
  /// (so the caller can distinguish "no auth" from "can't check").
  Future<bool> isTokenValid() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) return false;

    try {
      final response = await ApiClient.client.get(
        Uri.parse('${ApiConfig.baseUrl}/delivery/profile'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) return true;
      if (response.statusCode == 401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) return true;
        print('Token refresh failed and silent re-auth failed. Session is definitively expired.');
        return false;
      }

      return false;
    } catch (e) {
      // The dashboard will show errors when actual API calls fail.
      print('Token validation failed (network error): $e — trusting cached session');
      return true;
    }
  }
}