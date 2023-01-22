import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:dart_application_1/model/categories.dart';
import 'package:dart_application_1/model/historyofactions.dart';
import 'package:dart_application_1/utils/app_response.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:dart_application_1/model/model_response.dart';
import 'package:dart_application_1/model/user.dart';
import 'package:dart_application_1/utils/app_utils.dart';

class AppCategoryController extends ResourceController {
  AppCategoryController(this.managedContext);
  final ManagedContext managedContext;

  void AddActionHistory(
      String action, String? oldValue, String newValue, User? idUser) async {
    String tableName = "_categories";
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

  //Добавление новой категории
  @Operation.put()
  Future<Response> addCategory(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.body() Categories category) async {
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

      if (category.nameCategory!.trim() == "") {
        return Response.badRequest(
          body:
              ModelResponse(message: 'Поле наименование категории обязательно'),
        );
      }
      late final int idCategory;
      await managedContext.transaction((transaction) async {
        final qCreateCategory = Query<Categories>(transaction)
          ..values.nameCategory = category.nameCategory;

        final createdCategory = await qCreateCategory.insert();
        AddActionHistory(
            "Insert new category",
            null,
            // ignore: prefer_interpolation_to_compose_strings
            '"idcategory" : "' +
                createdCategory.idCategory.toString() +
                '", "namecategory" : "' +
                createdCategory.nameCategory.toString() +
                '"',
            fAuthUser);
        idCategory = createdCategory.idCategory!;
      });
      final categoryData =
          await managedContext.fetchObjectWithID<Categories>(idCategory);
      return AppResponse.ok(
          message: 'Успешное добавление категории',
          body: categoryData!.backing.contents);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка добавления категории');
    }
  }

  //Обновление категории
  @Operation.post()
  Future<Response> updateCategory(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.body() Categories category) async {
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

      if (category.nameCategory!.trim() == "") {
        return Response.badRequest(
          body:
              ModelResponse(message: 'Поле наименование категории обязательно'),
        );
      }

      final qFindCategory = Query<Categories>(managedContext)
        ..where((element) => element.idCategory).equalTo(category.idCategory)
        ..returningProperties((element) => [element.nameCategory]);
      final fFindCategory = await qFindCategory.fetchOne();
      if (fFindCategory == null) {
        return Response.badRequest(
          body: ModelResponse(message: 'Категория с указанным id не найдена'),
        );
      }

      final qUpdateCategory = Query<Categories>(managedContext)
        ..where((x) => x.idCategory).equalTo(category.idCategory)
        ..values.nameCategory = category.nameCategory;
      final updatedCategory = await qUpdateCategory.updateOne();

      AddActionHistory(
          "Update category",
          // ignore: prefer_interpolation_to_compose_strings
          '"idcategory" : "' +
              fFindCategory.idCategory.toString() +
              '", "namecategory" : "' +
              fFindCategory.nameCategory.toString() +
              '"',
          // ignore: prefer_interpolation_to_compose_strings
          '"idcategory" : "' +
              updatedCategory!.idCategory.toString() +
              '", "namecategory" : "' +
              updatedCategory.nameCategory.toString() +
              '"',
          fAuthUser);
      return Response.ok(updatedCategory);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка обновления категории');
    }
  }

  //Получение всех категорий с сортировкой и поиском
  @Operation.get()
  Future<Response> getCategories(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.query('typeSort') int typeSort,
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

      //search - поиск
      var qCategoriesAll = Query<Categories>(managedContext)
        ..returningProperties(
            (element) => [element.idCategory, element.nameCategory]);

      if (typeSort == 1 || typeSort == 2) {
        qCategoriesAll = qCategoriesAll
          ..sortBy(
              (element) => element.nameCategory,
              typeSort.isOdd == true
                  ? QuerySortOrder.ascending
                  : QuerySortOrder.descending);
      }

      var categoriesAll = await qCategoriesAll.fetch();
      if (search.isNotEmpty && search.trim() != "") {
        categoriesAll = categoriesAll
            .where((element) => element.nameCategory!
                .toLowerCase()
                .contains(search.toLowerCase()))
            .toList();
      }

      return Response.ok(categoriesAll);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка вывода данных');
    }
  }

  //Получение категории по ID
  @Operation.get('id')
  Future<Response> getCategoryByID(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.query('idCategory') int idCategory) async {
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

      final qCategoryByID = Query<Categories>(managedContext)
        ..where((element) => element.idCategory).equalTo(idCategory)
        ..returningProperties(
            (element) => [element.idCategory, element.nameCategory]);
      final fCategoryByID = await qCategoryByID.fetchOne();
      if (fCategoryByID == null) {
        return AppResponse.badRequest(
            message: 'Категория не найдена с указанным ID');
      } else {
        return Response.ok(fCategoryByID);
      }
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка получения данных');
    }
  }

  //Удаление категории
  @Operation.delete()
  Future<Response> deleteCategory(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.query('idCategory') int idCategory) async {
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

      final qCategoryByID = Query<Categories>(managedContext)
        ..where((element) => element.idCategory).equalTo(idCategory)
        ..returningProperties(
            (element) => [element.idCategory, element.nameCategory]);
      final fCategoryByID = await qCategoryByID.fetchOne();
      if (fCategoryByID == null) {
        return AppResponse.badRequest(
            message: 'Категория не найдена с указанным ID');
      } else {
        final fDeletedCategoryByID = await qCategoryByID.delete();
        AddActionHistory(
            "Delete category",
            // ignore: prefer_interpolation_to_compose_strings
            '"idcategory" : "' +
                fCategoryByID.idCategory.toString() +
                '", "namecategory" : "' +
                fCategoryByID.nameCategory.toString() +
                '"',
            // ignore: prefer_interpolation_to_compose_strings
            'DELETED',
            fAuthUser);
        return Response.ok("Категория успешно удалена");
      }
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка удаления данных');
    }
  }
}
