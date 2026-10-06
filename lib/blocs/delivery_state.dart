import 'package:equatable/equatable.dart';
import 'package:foodit_delivery_agent/models/delivery_model.dart';
import 'package:foodit_delivery_agent/models/order_model.dart';

abstract class DeliveryState extends Equatable {
  const DeliveryState();
  @override
  List<Object> get props => [];
}

class DeliveryLoading extends DeliveryState {}

class DeliveryLoaded extends DeliveryState {
  final DeliveryProfile profile;
  final List<Order> activeOrders;
  final List<Order> historyOrders;

  const DeliveryLoaded({
    required this.profile,
    required this.activeOrders,
    required this.historyOrders,
  });

  @override
  List<Object> get props => [profile, activeOrders, historyOrders];
}

class DeliveryError extends DeliveryState {
  final String message;
  const DeliveryError(this.message);
  @override
  List<Object> get props => [message];
}