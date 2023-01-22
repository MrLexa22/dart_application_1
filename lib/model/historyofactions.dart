import 'package:conduit/conduit.dart';
import 'package:dart_application_1/model/user.dart';

class HistoryOfActions extends ManagedObject<_HistoryOfActions>
    implements _HistoryOfActions {}

class _HistoryOfActions {
  @primaryKey
  int? idHistory;

  @Column(nullable: false)
  String? tableName;

  @Column(nullable: false)
  String? action;

  @Column(nullable: true)
  String? oldValue;

  @Column(nullable: false)
  String? newValue;

  @Relate(#historyofactions, isRequired: false)
  User? user;
}
