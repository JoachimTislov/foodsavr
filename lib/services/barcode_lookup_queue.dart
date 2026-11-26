import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A barcode scanned offline, saved as a placeholder product and waiting for
/// its Open Food Facts lookup.
@immutable
class QueuedBarcodeLookup {
  final String productId;
  final String barcode;
  final String languageCode;

  const QueuedBarcodeLookup({
    required this.productId,
    required this.barcode,
    required this.languageCode,
  });

  factory QueuedBarcodeLookup.fromJson(Map<String, dynamic> json) =>
      QueuedBarcodeLookup(
        productId: json['productId'] as String,
        barcode: json['barcode'] as String,
        languageCode: json['languageCode'] as String? ?? 'nb',
      );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'barcode': barcode,
    'languageCode': languageCode,
  };

  @override
  bool operator ==(Object other) =>
      other is QueuedBarcodeLookup &&
      other.productId == productId &&
      other.barcode == barcode &&
      other.languageCode == languageCode;

  @override
  int get hashCode => Object.hash(productId, barcode, languageCode);
}

/// Barcode lookups waiting for a connection, persisted across restarts.
@lazySingleton
class BarcodeLookupQueue extends ChangeNotifier {
  /// Local cache key; must be in the `SharedPreferencesWithCache` allow-list.
  static const preferenceKey = 'pending_barcode_lookups';

  final String? Function() _read;
  final Future<void> Function(String value) _write;
  List<QueuedBarcodeLookup>? _entries;

  BarcodeLookupQueue(SharedPreferencesWithCache prefs)
    : _read = (() => prefs.getString(preferenceKey)),
      _write = ((value) => prefs.setString(preferenceKey, value));

  /// A queue that lives only in memory.
  BarcodeLookupQueue.memory() : _read = (() => null), _write = ((_) async {});

  List<QueuedBarcodeLookup> get entries => List.unmodifiable(_load());

  int get length => _load().length;

  Future<void> enqueue(QueuedBarcodeLookup entry) async {
    final entries = _load();
    if (entries.contains(entry)) return;
    entries.add(entry);
    await _save();
  }

  Future<void> remove(QueuedBarcodeLookup entry) async {
    if (_load().remove(entry)) await _save();
  }

  List<QueuedBarcodeLookup> _load() {
    if (_entries case final entries?) return entries;
    final raw = _read();
    var loaded = <QueuedBarcodeLookup>[];
    if (raw != null) {
      try {
        loaded = [
          for (final item in jsonDecode(raw) as List<dynamic>)
            QueuedBarcodeLookup.fromJson(item as Map<String, dynamic>),
        ];
      } on FormatException {
        // A corrupt entry list is dropped rather than blocking the queue.
      } on TypeError {
        // Same for entries with an unexpected shape.
      }
    }
    return _entries = loaded;
  }

  Future<void> _save() async {
    notifyListeners();
    await _write(jsonEncode([for (final e in _load()) e.toJson()]));
  }
}
