import 'package:dart_application_1/dart_application_1.dart';
import 'dart:io';
import 'package:conduit/conduit.dart';
import 'package:dart_application_1/model/operations.dart';
import 'package:dart_application_1/model/user.dart';

class Categories extends ManagedObject<_Categories> implements _Categories {}

class _Categories {
  @primaryKey
  int? idCategory;

  @Column(unique: true, indexed: true)
  String? nameCategory;

  ManagedSet<Operations>? operationsList;
}
