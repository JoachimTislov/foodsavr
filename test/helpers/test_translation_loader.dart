import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// Loads real translations before a widget test's fake async zone.
class TestTranslationLoader extends AssetLoader {
  final Map<String, dynamic> _translations;

  TestTranslationLoader([String languageCode = 'en'])
    : _translations =
          jsonDecode(
                File(
                  'assets/translations/$languageCode.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      _translations;
}
