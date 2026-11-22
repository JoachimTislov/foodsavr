import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_model.dart';
import '../utils/view_mode_helper.dart';
import 'list_query.dart';

class ListQueryState extends ChangeNotifier {
  ListQueryState(String scope, {this.linkSort, this.linkStatus})
    : _key = 'listQuery.$scope';

  final String _key;
  final ListSort? linkSort;
  final ProductStatus? linkStatus;
  SharedPreferences? _preferences;
  Future<void>? _restoring;

  String search = '';
  String? category;
  String? collectionId;
  ProductStatus? status;
  ListSort sort = ListSort.original;
  ProductViewMode viewMode = ProductViewMode.normal;

  ListQuery get query => ListQuery(
    search: search,
    category: category,
    collectionId: collectionId,
    status: status,
    sort: sort,
  );

  Future<void> restore() => _restoring ??= _restore();

  Future<void> _restore() async {
    _preferences = await SharedPreferences.getInstance();
    final saved = _preferences?.getString(_key);
    if (saved != null) {
      try {
        final values = jsonDecode(saved);
        if (values is Map<String, dynamic>) {
          category = _string(values['category']);
          collectionId = _string(values['collection']);
          status = ProductStatus.values.asNameMap()[values['status']];
          sort = ListSort.values.asNameMap()[values['sort']] ?? sort;
          viewMode =
              ProductViewMode.values.asNameMap()[values['viewMode']] ??
              viewMode;
        }
      } on FormatException {
        // Fall back to defaults when local preferences are malformed.
      }
    }
    if (linkStatus != null || linkSort != null) {
      category = null;
      collectionId = null;
      status = linkStatus ?? status;
      sort = linkSort ?? sort;
    }
  }

  static String? _string(Object? value) => value is String ? value : null;

  void searchFor(String value) {
    search = value;
    notifyListeners();
  }

  void update(VoidCallback change) {
    change();
    notifyListeners();
    unawaited(_save());
  }

  Future<void> _save() async {
    try {
      await _preferences?.setString(
        _key,
        jsonEncode({
          'category': category,
          'collection': collectionId,
          'status': status?.name,
          'sort': sort.name,
          'viewMode': viewMode.name,
        }),
      );
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    }
  }
}
