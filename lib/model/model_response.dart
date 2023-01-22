import 'package:dart_application_1/dart_application_1.dart';
import 'dart:io';
import 'package:conduit/conduit.dart';

class ModelResponse {
  ModelResponse({this.error, this.data, this.message});

  final dynamic error;
  final dynamic data;
  final dynamic message;

  Map<String, dynamic> toJson() =>
      {'error': error ?? '', 'data': data ?? '', 'message': message ?? ''};
}
