import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:dart_application_1/model/categories.dart';
import 'package:dart_application_1/model/historyofactions.dart';
import 'package:dart_application_1/model/operations.dart';
import 'package:dart_application_1/utils/app_response.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:dart_application_1/model/model_response.dart';
import 'package:dart_application_1/model/user.dart';
import 'package:dart_application_1/utils/app_utils.dart';

class AppOperationController extends ResourceController {
  AppOperationController(this.managedContext);
  final ManagedContext managedContext;

  void AddActionHistory(
      String action, String? oldValue, String newValue, User? idUser) async {
    String tableName = "_operations";
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

  //Добавление новой операции
  @Operation.put()
  Future<Response> addOperation(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.body() Operations operation) async {
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

      if (operation.numberOperation == null ||
          operation.numberOperation!.trim() == "") {
        return Response.badRequest(
          body: ModelResponse(
              message: 'Поле номер операции обязательно для заполнения'),
        );
      }
      if (operation.nameOperation == null ||
          operation.nameOperation!.trim() == "") {
        return Response.badRequest(
          body: ModelResponse(
              message: 'Поле наименование операции обязательно для заполнения'),
        );
      }
      if (operation.descriptionOperation == null ||
          operation.descriptionOperation!.trim() == "") {
        return Response.badRequest(
          body: ModelResponse(
              message: 'Поле описание операции обязательно для заполнения'),
        );
      }
      if (operation.dateOperation == null) {
        return Response.badRequest(
          body: ModelResponse(
              message: 'Поле дата операции обязательно для заполнения'),
        );
      }
      if (operation.valueOperation == null || operation.valueOperation! < 1) {
        return Response.badRequest(
          body: ModelResponse(
              message: 'Поле сумма операции обязательно для заполнения'),
        );
      }
      if (operation.category!.idCategory == null) {
        return Response.badRequest(
          body: ModelResponse(message: 'Необходимо выбрать категорию операции'),
        );
      }

      final fFindCategory = await managedContext
          .fetchObjectWithID<Categories>(operation.category!.idCategory);
      if (fFindCategory == null) {
        return Response.badRequest(
          body: ModelResponse(message: 'Указанная категория не найдена'),
        );
      }

      late final int idOperation;
      await managedContext.transaction((transaction) async {
        final qCreateOperation = Query<Operations>(transaction)
          ..values.numberOperation = operation.numberOperation
          ..values.nameOperation = operation.nameOperation
          ..values.descriptionOperation = operation.descriptionOperation
          ..values.dateOperation = operation.dateOperation
          ..values.valueOperation = operation.valueOperation
          ..values.isDeleted = false
          ..values.user = fAuthUser
          ..values.category = fFindCategory;

        final createdOperation = await qCreateOperation.insert();
        AddActionHistory(
            "Insert new operation",
            null,
            // ignore: prefer_interpolation_to_compose_strings
            '"idOperation" : "' +
                createdOperation.idOperation.toString() +
                '", "numberOperation" : "' +
                createdOperation.numberOperation.toString() +
                '", "nameOperation" : "' +
                createdOperation.nameOperation.toString() +
                '", "descriptionOperation" : "' +
                createdOperation.descriptionOperation.toString() +
                '", "dateOperation" : "' +
                createdOperation.dateOperation.toString() +
                '", "valueOperation" : "' +
                createdOperation.valueOperation.toString() +
                '", "isDeleted" : "' +
                createdOperation.isDeleted.toString() +
                '", "userID" : "' +
                createdOperation.user!.id.toString() +
                '", "categoryID" : "' +
                createdOperation.category!.idCategory.toString() +
                '"',
            fAuthUser);
        idOperation = createdOperation.idOperation!;
      });
      var q = Query<Operations>(managedContext)
        ..join(object: (u) => u.category)
            .returningProperties((t) => [t.idCategory, t.nameCategory])
        ..join(object: (u) => u.user)
            .returningProperties((t) => [t.id, t.userName, t.email])
        ..where((element) => element.idOperation).equalTo(idOperation);
      var operationData = await q.fetchOne();
      return Response.ok(operationData);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка добавления операции');
    }
  }

  //Обновление операции
  @Operation.post()
  Future<Response> updateOperation(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.body() Operations operation) async {
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

      final fFindOperation = await managedContext
          .fetchObjectWithID<Operations>(operation.idOperation);
      if (fFindOperation == null) {
        return Response.badRequest(
          body: ModelResponse(message: 'Указанная операция не найдена'),
        );
      }

      if (operation.numberOperation == null ||
          operation.numberOperation!.trim() == "") {
        return Response.badRequest(
          body: ModelResponse(
              message: 'Поле номер операции обязательно для заполнения'),
        );
      }
      if (operation.nameOperation == null ||
          operation.nameOperation!.trim() == "") {
        return Response.badRequest(
          body: ModelResponse(
              message: 'Поле наименование операции обязательно для заполнения'),
        );
      }
      if (operation.descriptionOperation == null ||
          operation.descriptionOperation!.trim() == "") {
        return Response.badRequest(
          body: ModelResponse(
              message: 'Поле описание операции обязательно для заполнения'),
        );
      }
      if (operation.dateOperation == null) {
        return Response.badRequest(
          body: ModelResponse(
              message: 'Поле дата операции обязательно для заполнения'),
        );
      }
      if (operation.valueOperation == null || operation.valueOperation! < 1) {
        return Response.badRequest(
          body: ModelResponse(
              message: 'Поле сумма операции обязательно для заполнения'),
        );
      }
      if (operation.category!.idCategory == null) {
        return Response.badRequest(
          body: ModelResponse(message: 'Необходимо выбрать категорию операции'),
        );
      }

      final fFindCategory = await managedContext
          .fetchObjectWithID<Categories>(operation.category!.idCategory);
      if (fFindCategory == null) {
        return Response.badRequest(
          body: ModelResponse(message: 'Указанная категория не найдена'),
        );
      }

      final qUpdateOperation = Query<Operations>(managedContext)
        ..where((x) => x.idOperation).equalTo(operation.idOperation)
        ..values.numberOperation = operation.numberOperation
        ..values.nameOperation = operation.nameOperation
        ..values.isDeleted = fFindOperation.isDeleted
        ..values.descriptionOperation = operation.descriptionOperation
        ..values.dateOperation = operation.dateOperation
        ..values.valueOperation = operation.valueOperation
        ..values.user = fAuthUser
        ..values.category = fFindCategory;
      final updatedOperation = await qUpdateOperation.updateOne();

      AddActionHistory(
          "Update operation",
          // ignore: prefer_interpolation_to_compose_strings
          '"idOperation" : "' +
              fFindOperation.idOperation.toString() +
              '", "numberOperation" : "' +
              fFindOperation.numberOperation.toString() +
              '", "nameOperation" : "' +
              fFindOperation.nameOperation.toString() +
              '", "descriptionOperation" : "' +
              fFindOperation.descriptionOperation.toString() +
              '", "dateOperation" : "' +
              fFindOperation.dateOperation.toString() +
              '", "valueOperation" : "' +
              fFindOperation.valueOperation.toString() +
              '", "userID" : "' +
              fFindOperation.user!.id.toString() +
              '", "categoryID" : "' +
              fFindOperation.category!.idCategory.toString() +
              '"',
          // ignore: prefer_interpolation_to_compose_strings
          '"idOperation" : "' +
              operation.idOperation.toString() +
              '", "numberOperation" : "' +
              operation.numberOperation.toString() +
              '", "nameOperation" : "' +
              operation.nameOperation.toString() +
              '", "descriptionOperation" : "' +
              operation.descriptionOperation.toString() +
              '", "dateOperation" : "' +
              operation.dateOperation.toString() +
              '", "valueOperation" : "' +
              operation.valueOperation.toString() +
              '", "userID" : "' +
              fFindOperation.user!.id.toString() +
              '", "categoryID" : "' +
              operation.category!.idCategory.toString() +
              '"',
          fAuthUser);
      return Response.ok(updatedOperation);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка обновления категории');
    }
  }

  //Получение всех операций пользователя с сортировкой, фильтрацией, пагинацией и поиском
  @Operation.get()
  Future<Response> getOperations(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.query('typeSort') int typeSort,
    @Bind.query('filterByCategory') int filterByCategory,
    @Bind.query('filterByIsDeleted') int filterByIsDeleted,
    @Bind.query('page') int page,
    @Bind.query('search') String search,
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

      //typeSort 0 = Сортировка по умолчанию
      //typeSort 1 = Сортировка по наименованию ascending
      //typeSort 2 = Сортировка по наименованию descending
      //typeSort 3 = Сортировка по дате операции ascending
      //typeSort 4 = Сортировка по дате операции descending

      //filterByCategory 0 - Все
      //filterByCategory N - Только по указанному ID категории

      //filterByIsDeleted 0 - все
      //filterByIsDeleted 1 - не удалённые
      //filterByIsDeleted 2 - только удалённые

      //search - поиск
      var qOperationsAll = Query<Operations>(managedContext)
        ..join(object: (u) => u.category)
            .returningProperties((t) => [t.idCategory, t.nameCategory])
        ..join(object: (u) => u.user)
            .returningProperties((t) => [t.id, t.userName, t.email])
        ..returningProperties((element) => [
              element.idOperation,
              element.numberOperation,
              element.nameOperation,
              element.descriptionOperation,
              element.dateOperation,
              element.valueOperation,
              element.isDeleted,
              element.user,
              element.category
            ])
        ..where((x) => x.user!.id).equalTo(id);

      if (filterByCategory > 0) {
        qOperationsAll = qOperationsAll
          ..where((x) => x.category?.idCategory).equalTo(filterByCategory);
      }
      if (filterByIsDeleted >= 1 && filterByIsDeleted < 3) {
        qOperationsAll = qOperationsAll
          ..where((x) => x.isDeleted)
              .equalTo(filterByIsDeleted == 1 ? false : true);
      }

      if (typeSort > 0 && typeSort < 5) {
        qOperationsAll = qOperationsAll
          ..sortBy(
              (element) =>
                  typeSort < 3 ? element.nameOperation : element.dateOperation,
              typeSort.isOdd == true
                  ? QuerySortOrder.ascending
                  : QuerySortOrder.descending);
      }

      var operationsAll = await qOperationsAll.fetch();
      if (search.isNotEmpty && search.trim() != "") {
        operationsAll = operationsAll
            .where((element) =>
                element.nameOperation!
                    .toLowerCase()
                    .contains(search.toLowerCase()) ||
                element.numberOperation!
                    .toLowerCase()
                    .contains(search.toLowerCase()))
            .toList();
      }

      int pageSize = 4; //ИСПРАВИТЬ, ЭТО ДЛЯ ПРИМЕРА!
      if (page <= 0) page = 1;
      var items =
          operationsAll.skip((page - 1) * pageSize).take(pageSize).toList();

      return Response.ok(items);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка вывода данных');
    }
  }

  //Получение операции по ID
  @Operation.get('id')
  Future<Response> getOperationByID(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.query('idOperation') int idOperation) async {
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

      var qOperationById = Query<Operations>(managedContext)
        ..join(object: (u) => u.category)
            .returningProperties((t) => [t.idCategory, t.nameCategory])
        ..join(object: (u) => u.user)
            .returningProperties((t) => [t.id, t.userName, t.email])
        ..returningProperties((element) => [
              element.idOperation,
              element.numberOperation,
              element.nameOperation,
              element.descriptionOperation,
              element.dateOperation,
              element.valueOperation,
              element.isDeleted,
              element.user,
              element.category
            ])
        ..where((x) => x.user!.id).equalTo(id)
        ..where((x) => x.idOperation).equalTo(idOperation);
      final fOperationByID = await qOperationById.fetchOne();

      if (fOperationByID == null) {
        return AppResponse.badRequest(
            message: 'Операция не найдена с указанным ID');
      } else {
        return Response.ok(fOperationByID);
      }
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка получения данных');
    }
  }

  //Удаление категории
  @Operation.delete()
  Future<Response> deleteCategory(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.query('isDeleted') String isDeleted,
      @Bind.query('idOperation') int idOperation) async {
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
        ..returningProperties(
            (element) => [element.salt, element.hashPassword]);
      final fAuthUser = await qFindAuthUser.fetchOne();
      if (fAuthUser == null) {
        return AppResponse.badRequest(message: 'Ошибка авторизации');
      }

      final qOperationByID = Query<Operations>(managedContext)
        ..where((element) => element.idOperation).equalTo(idOperation)
        ..where((element) => element.user?.id).equalTo(id)
        ..returningProperties(
            (element) => [element.idOperation, element.isDeleted]);
      final fOperationByID = await qOperationByID.fetchOne();
      if (fOperationByID == null) {
        return AppResponse.badRequest(
            message: 'Операция не найдена с указанным ID');
      }

      final qUpdateOperation = Query<Operations>(managedContext)
        ..where((x) => x.idOperation).equalTo(idOperation)
        ..values.isDeleted = isDelet;
      await qUpdateOperation.updateOne();
      AddActionHistory(
          isDelet == true
              ? "Logical delete operation"
              : "Logical restore operation",
          // ignore: prefer_interpolation_to_compose_strings
          '"idOperation" : "' +
              idOperation.toString() +
              '", "isDeleted" : "' +
              fOperationByID.isDeleted.toString() +
              '"',
          // ignore: prefer_interpolation_to_compose_strings
          '"idOperation" : "' +
              idOperation.toString() +
              '", "isDeleted" : "' +
              isDeleted.toString() +
              '"',
          fAuthUser);
      return AppResponse.ok(
        body: isDelet == true ? 'Операция удалена' : 'Операция восстановлена',
      );
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка удаления данных');
    }
  }
}
