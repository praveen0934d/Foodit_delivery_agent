import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../data/repositories/delivery_repository.dart';
import '../services/agent_fcm_service.dart';
import '../models/order_model.dart';
import '../models/delivery_model.dart';

abstract class DeliveryEvent {}

class LoadDeliveryDashboard extends DeliveryEvent {}

class GoogleSignInRequested extends DeliveryEvent {}

class MarkOrderDelivered extends DeliveryEvent {
  final String orderId;
  MarkOrderDelivered(this.orderId);
}

class MarkOrderNotPickedUp extends DeliveryEvent {
  final String orderId;
  final String reason;
  MarkOrderNotPickedUp(this.orderId, this.reason);
}

class MarkAtGateRequested extends DeliveryEvent {
  final List<String> orderIds;
  MarkAtGateRequested(this.orderIds);
}

abstract class DeliveryState {}
class DeliveryInitial extends DeliveryState {}
class DeliveryLoading extends DeliveryState {}
class DeliverySignedIn extends DeliveryState {}

class DeliveryLoaded extends DeliveryState {
  final List<Order> activeOrders;
  final List<Order> historyOrders;
  final DeliveryProfile profileData;
  final Map<String, dynamic>? restaurantData;

  DeliveryLoaded(this.activeOrders, this.historyOrders, this.profileData, this.restaurantData);
}

class DeliveryError extends DeliveryState {
  final String message;
  DeliveryError(this.message);
}

class DeliverySessionExpired extends DeliveryState {
  final String message;
  DeliverySessionExpired([this.message = 'Session expired. Please log in again.']);
}

class DeliveryBloc extends Bloc<DeliveryEvent, DeliveryState> {
  final DeliveryRepository deliveryRepository;

  DeliveryBloc(this.deliveryRepository) : super(DeliveryInitial()) {

    // ─── Google Sign-In ──────────────────────────────────────
    on<GoogleSignInRequested>((event, emit) async {
      print('BLOC: GoogleSignInRequested received');
      emit(DeliveryLoading());
      try {
        print('BLOC: Calling deliveryRepository.signInWithGoogle()...');
        await deliveryRepository.signInWithGoogle();
        print('BLOC: signInWithGoogle completed');
        try {
          await AgentFCMService.init();
          print('BLOC: FCM init done');
        } catch (e) {
          print('BLOC: FCM init failed but continuing: $e');
        }
        print('BLOC: Emitting DeliverySignedIn');
        emit(DeliverySignedIn());
      } catch (e) {
        print('❌ BLOC: Google Sign-In Error: $e');
        emit(DeliveryError(e.toString().replaceFirst('Exception: ', '')));
      }
    });

    // ─── Load Dashboard ──────────────────────────────────────
    on<LoadDeliveryDashboard>((event, emit) async {
      emit(DeliveryLoading());
      try {
        final profile = await deliveryRepository.getProfile();
        final active = await deliveryRepository.getActiveOrders();
        final history = await deliveryRepository.getHistoryOrders();
        final restaurant = await deliveryRepository.getRestaurantDetails();
        emit(DeliveryLoaded(active, history, profile, restaurant));
      } catch (e) {
        final errorMsg = e.toString();
        if (errorMsg.contains('SESSION_EXPIRED')) {
          emit(DeliverySessionExpired());
        } else {
          emit(DeliveryError(errorMsg));
        }
      }
    });

    on<MarkOrderDelivered>((event, emit) async {
      if (state is DeliveryLoaded) {
        final currentState = state as DeliveryLoaded;
        try {
          await deliveryRepository.markDelivered(event.orderId);
          add(LoadDeliveryDashboard());
        } catch (e) {
          if (e.toString().contains('SESSION_EXPIRED')) {
            emit(DeliverySessionExpired());
          } else {
            emit(DeliveryError(e.toString()));
            emit(currentState);
          }
        }
      }
    }, transformer: droppable());

    on<MarkOrderNotPickedUp>((event, emit) async {
      if (state is DeliveryLoaded) {
        final currentState = state as DeliveryLoaded;
        try {
          await deliveryRepository.markOrderNotPickedUp(event.orderId);
          add(LoadDeliveryDashboard());
        } catch (e) {
          if (e.toString().contains('SESSION_EXPIRED')) {
            emit(DeliverySessionExpired());
          } else {
            emit(DeliveryError(e.toString()));
            emit(currentState);
          }
        }
      }
    }, transformer: droppable());

    on<MarkAtGateRequested>((event, emit) async {
      if (state is DeliveryLoaded) {
        final currentState = state as DeliveryLoaded;
        try {
          // Loop through the given order IDs and hit the API
          for (var id in event.orderIds) {
            await deliveryRepository.markAtGate(id);
          }
          // Instead of refreshing the dashboard (which resets UI state), 
          // we could just emit a small toast, but for now, we'll keep the dashboard loaded
          emit(currentState); 
        } catch (e) {
          emit(DeliveryError(e.toString()));
          emit(currentState);
        }
      }
    }, transformer: droppable());
  }
}