import 'package:foodit_delivery_agent/models/order_model.dart';
import 'package:foodit_delivery_agent/models/delivery_model.dart';

abstract class DeliveryRepository {
  Future<bool> isTokenValid();
  Future<void> signInWithGoogle();
  Future<void> logout();
  Future<List<Order>> getActiveOrders();
  Future<List<Order>> getHistoryOrders();
  Future<void> markDelivered(String orderId);
  Future<void> markOrderNotPickedUp(String orderId);
  Future<void> markAtGate(String orderId);
  Future<DeliveryProfile> getProfile();
  Future<Map<String, dynamic>?> getRestaurantDetails();
}
