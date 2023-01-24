import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:dart_application_1/model/historyofactions.dart';
import 'package:dart_application_1/utils/app_response.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:dart_application_1/model/model_response.dart';
import 'package:dart_application_1/model/user.dart';
import 'package:dart_application_1/utils/app_utils.dart';

class AppUserController extends ResourceController {
  AppUserController(this.managedContext);
  final ManagedContext managedContext;

  void AddActionHistory(
      String action, String? oldValue, String newValue, User? idUser) async {
    String tableName = "_user";
    await managedContext.transaction((transaction) async {
      final qCreateHistory = Query<HistoryOfActions>(transaction)
        ..values.tableName = tableName
        ..values.action = action
        ..values.oldValue = oldValue
        ..values.newValue = newValue
        ..values.user = idUser;
      final createdHistory = await qCreateHistory.insert();
    });
  }

  @Operation.get('getProfile')
  Future<Response> getProfile(
      @Bind.header(HttpHeaders.authorizationHeader) String header) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final user = await managedContext.fetchObjectWithID<User>(id);
      user!.removePropertiesFromBackingMap(['refreshToken', 'accessToken']);

      return AppResponse.ok(
          message: 'Успешное получение профиля', body: user.backing.contents);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка получения профиля');
    }
  }

  @Operation.get()
  Future<Response> getUsers(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.query('idUser') int idUser,
    @Bind.query('typeSort') int typeSort,
    @Bind.query('filterDeletedUsers') int filterDeletedUsers,
    @Bind.query('search') String search,
    @Bind.query('page') int page,
  ) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final qFindAuthUser = Query<User>(managedContext)
        ..where((element) => element.id).equalTo(id)
        ..returningProperties(
            (element) => [element.salt, element.hashPassword]);
      final fAuthUser = await qFindAuthUser.fetchOne();
      if (fAuthUser == null) {
        return AppResponse.badRequest(message: 'Ошибка авторизации');
      }

      if (idUser > 0) {
        final qUserByID = Query<User>(managedContext)
          ..where((element) => element.id).equalTo(idUser)
          ..returningProperties((element) =>
              [element.id, element.userName, element.email, element.isDeleted]);
        final fUserByID = await qUserByID.fetchOne();
        if (fUserByID == null) {
          return AppResponse.badRequest(
              message: 'Пользователь не найден с указанным ID');
        } else {
          return Response.ok(fUserByID);
        }
      }

      //typeSort 0 = Сортировка по умолчанию
      //typeSort 1 = Сортировка по логину ascending
      //typeSort 2 = Сортировка по логину descending
      //typeSort 3 = Сортировка по email ascending
      //typeSort 4 = Сортировка по email descending

      //filterDeletedUsers 0 = Все пользователи
      //filterDeletedUsers 1 = Только не удалённые
      //filterDeletedUsers 2 = Только удалённые

      //search - поиск
      //page - пагинация
      var qusersAll = Query<User>(managedContext)
        ..returningProperties((element) =>
            [element.userName, element.email, element.isDeleted, element.id]);

      if (filterDeletedUsers == 1 || filterDeletedUsers == 2) {
        qusersAll = qusersAll
          ..where((element) => element.isDeleted)
              .equalTo(filterDeletedUsers == 1 ? false : true);
      }

      if (typeSort > 0 && typeSort < 5) {
        qusersAll = qusersAll
          ..sortBy(
              (element) => typeSort < 3 ? element.userName : element.email,
              typeSort.isOdd == true
                  ? QuerySortOrder.ascending
                  : QuerySortOrder.descending);
      }

      var usersAll = await qusersAll.fetch();
      if (search.isNotEmpty && search.trim() != "") {
        usersAll = usersAll
            .where((element) =>
                element.userName!
                    .toLowerCase()
                    .contains(search.toLowerCase()) ||
                element.email!.contains(search.toLowerCase()))
            .toList();
      }

      int pageSize = 5;
      if (page <= 0) page = 1;
      var items = usersAll.skip((page - 1) * pageSize).take(pageSize).toList();
      return Response.ok(items);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка вывода данных');
    }
  }

  @Operation.post()
  Future<Response> updateProfile(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.body() User user) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final fUser = await managedContext.fetchObjectWithID<User>(id);
      final qUpdateUser = Query<User>(managedContext)
        ..where((element) => element.id).equalTo(id)
        ..values.userName = user.userName ?? fUser!.userName
        ..values.email = user.email ?? fUser!.email ?? fUser!.email;

      await qUpdateUser.updateOne();
      final findUser = await managedContext.fetchObjectWithID<User>(id);
      findUser!.removePropertiesFromBackingMap(['refreshToken', 'accessToken']);
      AddActionHistory(
          "Update profile",
          // ignore: prefer_interpolation_to_compose_strings
          '"email" : "' +
              fUser!.email.toString() +
              '", "userName" : "' +
              fUser.userName.toString() +
              '"',
          // ignore: prefer_interpolation_to_compose_strings
          '"email" : "' +
              findUser.email.toString() +
              '", "userName" : "' +
              findUser.userName.toString() +
              '"',
          fUser);
      return AppResponse.ok(
        message: 'Успешное обновление данных',
        body: findUser.backing.contents,
      );
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка обновления данных');
    }
  }

  @Operation.put()
  Future<Response> updatePassword(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.query('oldPassword') String oldPassword,
      @Bind.query('newPassword') String newPassword) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final qFindUser = Query<User>(managedContext)
        ..where((element) => element.id).equalTo(id)
        ..returningProperties(
            (element) => [element.salt, element.hashPassword]);

      final fUser = await qFindUser.fetchOne();
      final oldHashPassword =
          generatePasswordHash(oldPassword, fUser!.salt ?? "");

      if (oldHashPassword != fUser.hashPassword) {
        return AppResponse.badRequest(message: 'Не верный пароль');
      }

      final newHashPassword =
          generatePasswordHash(newPassword, fUser.salt ?? "");

      final qUpdateUser = Query<User>(managedContext)
        ..where((x) => x.id).equalTo(id)
        ..values.hashPassword = newHashPassword;

      await qUpdateUser.updateOne();
      AddActionHistory(
          "Update password",
          // ignore: prefer_interpolation_to_compose_strings
          '"hashPassword" : "' + fUser.hashPassword.toString() + '"',
          // ignore: prefer_interpolation_to_compose_strings
          '"hashPassword" : "' + newHashPassword.toString() + '"',
          fUser);
      return AppResponse.ok(
        body: 'Успешное обновление пароля',
      );
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка обновления данных');
    }
  }

  @Operation.delete()
  Future<Response> logicalremove(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.query('isDeleted') String isDeleted,
    @Bind.query('idUser') int idUser,
  ) async {
    try {
      bool isDelet = false;
      if (isDeleted != "true" && isDeleted != "false") {
        return AppResponse.badRequest(message: 'Ошибка запроса');
      }
      if (isDeleted == "true") {
        isDelet = true;
      }
      if (isDeleted == "false") {
        isDelet = false;
      }
      final id = AppUtils.getIdFromHeader(header);
      final qFindAuthUser = Query<User>(managedContext)
        ..where((element) => element.id).equalTo(id)
        ..returningProperties((element) =>
            [element.salt, element.hashPassword, element.isDeleted]);
      final fAuthUser = await qFindAuthUser.fetchOne();
      if (fAuthUser == null) {
        return AppResponse.badRequest(message: 'Ошибка авторизации');
      }

      final qUpdateUser = Query<User>(managedContext)
        ..where((x) => x.id).equalTo(idUser)
        ..values.isDeleted = isDelet;
      await qUpdateUser.updateOne();
      AddActionHistory(
          isDelet == true ? "Logical delete user" : "Logical restore user",
          // ignore: prefer_interpolation_to_compose_strings
          '"isDeleted" : "' + fAuthUser.isDeleted.toString() + '"',
          // ignore: prefer_interpolation_to_compose_strings
          '"isDeleted" : "' + isDeleted.toString() + '"',
          fAuthUser);
      return AppResponse.ok(
        body: isDelet == true
            ? 'Пользователь заблокирован'
            : 'Пользователь восстановлен',
      );
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка обновления данных');
    }
  }
}
