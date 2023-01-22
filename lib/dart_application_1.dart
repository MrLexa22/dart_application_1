import 'dart:io';
import 'package:conduit/conduit.dart';
import 'package:dart_application_1/controllers/app_auth_controller.dart';
import 'package:dart_application_1/controllers/app_categories_controller.dart';
import 'package:dart_application_1/controllers/app_operations_controller.dart';
import 'package:dart_application_1/controllers/app_token_controller.dart';
import 'package:dart_application_1/controllers/app_user_controller.dart';
import 'model/user.dart';
import 'model/categories.dart';
import 'model/operations.dart';
import 'model/historyofactions.dart';

class AppService extends ApplicationChannel {
  late final ManagedContext managedContext;

  @override
  Future prepare() {
    final persistentStore = _initDataBase();
    managedContext = ManagedContext(
        ManagedDataModel.fromCurrentMirrorSystem(), persistentStore);
    return super.prepare();
  }

  @override
  Controller get entryPoint => Router()
    ..route('token/[:refresh]').link(() => AppAuthController(managedContext))
    ..route('user/[:getProfile]')
        .link(AppTokenController.new)!
        .link(() => AppUserController(managedContext))
    ..route('category/[:id]')
        .link(AppTokenController.new)!
        .link(() => AppCategoryController(managedContext))
    ..route('operation/[:id]')
        .link(AppTokenController.new)!
        .link(() => AppOperationController(managedContext));

  PersistentStore _initDataBase() {
    final username = Platform.environment['DB_USERNAME'] ?? 'postgres';
    final password = Platform.environment['DB_PASSWORD'] ?? '1';
    final host = Platform.environment['DB_HOST'] ?? '127.0.0.1';
    final port = int.parse(Platform.environment['DB_PORT'] ?? '5432');
    final databaseName = Platform.environment['DB_NAME'] ?? 'postgres';
    return PostgreSQLPersistentStore(
        username, password, host, port, databaseName);
  }
}
