import 'package:foodit_delivery_agent/data/repositories/delivery_repository.dart';
import 'package:foodit_delivery_agent/services/delivery_service.dart';
import 'package:foodit_delivery_agent/models/order_model.dart';
import 'package:foodit_delivery_agent/models/delivery_model.dart';

class DeliveryRepositoryImpl implements DeliveryRepository {
  final DeliveryService _remoteDataSource;

  DeliveryRepositoryImpl(this._remoteDataSource);

  @override
  Future<bool> isTokenValid() => _remoteDataSource.isTokenValid();

  @override
  Future<void> signInWithGoogle() => _remoteDataSource.signInWithGoogle();

  @override
  Future<void> logout() => _remoteDataSource.logout();

  @override
  Future<List<Order>> getActiveOrders() => _remoteDataSource.getActiveOrders();

  @override
  Future<List<Order>> getHistoryOrders() => _remoteDataSource.getHistoryOrders();

  @override
  Future<void> markDelivered(String orderId) => _remoteDataSource.markDelivered(orderId);

  @override
  Future<void> markOrderNotPickedUp(String orderId) => _remoteDataSource.markOrderNotPickedUp(orderId);

  @override
  Future<void> markAtGate(String orderId) => _remoteDataSource.markAtGate(orderId);

  @override
  Future<DeliveryProfile> getProfile() => _remoteDataSource.getProfile();

  @override
  Future<Map<String, dynamic>?> getRestaurantDetails() => _remoteDataSource.getRestaurantDetails();
}
