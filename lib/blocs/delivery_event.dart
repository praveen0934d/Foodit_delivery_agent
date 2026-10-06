import 'package:equatable/equatable.dart';

abstract class DeliveryEvent extends Equatable {
  const DeliveryEvent();
  @override
  List<Object> get props => [];
}

class LoadDeliveryData extends DeliveryEvent {}

class MarkOrderDelivered extends DeliveryEvent {
  final String orderId;
  const MarkOrderDelivered(this.orderId);
  @override
  List<Object> get props => [orderId];
}

class MarkOrderNotPickedUp extends DeliveryEvent {
  final String orderId;
  final String reason; // We capture this from the UI for safety/future-proofing
  
  const MarkOrderNotPickedUp({required this.orderId, required this.reason});
  
  @override
  List<Object> get props => [orderId, reason];
}