import 'package:get_it/get_it.dart';
import 'package:foodit_delivery_agent/services/delivery_service.dart';
import 'package:foodit_delivery_agent/data/repositories/delivery_repository.dart';
import 'package:foodit_delivery_agent/data/repositories/delivery_repository_impl.dart';
import 'package:foodit_delivery_agent/data/repositories/config_repository.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Remote Data Source
  sl.registerLazySingleton(() => DeliveryService());

  // Repository
  sl.registerLazySingleton<DeliveryRepository>(
    () => DeliveryRepositoryImpl(sl()),
  );
  
  sl.registerLazySingleton<ConfigRepository>(
    () => ConfigRepositoryImpl(),
  );
}
