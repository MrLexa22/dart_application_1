import 'package:dart_application_1/dart_application_1.dart';
import 'dart:io';
import 'package:conduit/conduit.dart';
import 'package:dart_application_1/model/user.dart';

import 'categories.dart';

class Operations extends ManagedObject<_Operations> implements _Operations {}

class _Operations {
  @primaryKey
  int? idOperation;

  @Column(unique: true, indexed: true)
  String? numberOperation;

  @Column(nullable: false)
  String? nameOperation;

  @Column(nullable: false)
  String? descriptionOperation;

  @Column(nullable: false)
  DateTime? dateOperation;

  @Column(nullable: false)
  double? valueOperation;

  @Column(nullable: false)
  bool? isDeleted;

  @Relate(#operationsList, isRequired: true, onDelete: DeleteRule.cascade)
  User? user;

  @Relate(#operationsList, isRequired: true, onDelete: DeleteRule.cascade)
  Categories? category;
}
