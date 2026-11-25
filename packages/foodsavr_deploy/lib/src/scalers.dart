import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'deployment.dart';
import 'model/trigger.dart';

/// Reads one metric for a trigger, in the unit of the trigger's limit key.
/// Throws on any failure; the poller turns that into a hold (fallback).
abstract class Scaler {
  String get type;
  Future<double> read(Trigger t, Deployment i);
}

/// Metric values from a JSON object keyed by trigger name (or the scaler's
/// `key` param). Used for dry runs and tests.
class FileScaler implements Scaler {
  FileScaler(this.metrics);

  factory FileScaler.load(String path) {
    final decoded = jsonDecode(File(path).readAsStringSync());
    if (decoded is! Map) throw FormatException('$path: expected an object');
    return FileScaler({
      for (final e in decoded.entries)
        if (e.value is num) '${e.key}': (e.value as num).toDouble(),
    });
  }

  final Map<String, double> metrics;

  @override
  String get type => 'file';

  @override
  Future<double> read(Trigger t, Deployment i) async {
    final key = '${t.scaler.params['key'] ?? t.name}';
    final v = metrics[key];
    if (v == null) throw StateError('no metric "$key" in metrics file');
    return v;
  }
}

/// Authenticated GET against Google APIs. Token from `ACCESS_TOKEN`, else
/// `gcloud auth print-access-token`; `x-goog-user-project` is required for
/// user credentials (see scripts/web/hosting_storage_guard.py).
class GoogleApi {
  GoogleApi(this.project, {http.Client? client, String? token})
    : _client = client ?? http.Client(),
      _token = token;

  final String project;
  final http.Client _client;
  String? _token;

  String _accessToken() {
    final env = Platform.environment['ACCESS_TOKEN'];
    if (env != null && env.isNotEmpty) return env;
    final r = Process.runSync('gcloud', ['auth', 'print-access-token']);
    if (r.exitCode != 0) throw StateError('gcloud auth failed: ${r.stderr}');
    return '${r.stdout}'.trim();
  }

  Future<Map<String, Object?>> get(Uri uri) async {
    final token = _token ??= _accessToken();
    final res = await _client.get(
      uri,
      headers: {
        'authorization': 'Bearer $token',
        'x-goog-user-project': project,
      },
    );
    if (res.statusCode != 200) {
      throw StateError('GET ${uri.path}: HTTP ${res.statusCode}');
    }
    return (jsonDecode(res.body) as Map).cast<String, Object?>();
  }
}

/// Total Firebase Auth users via `accounts:batchGet` (no count endpoint).
class FirebaseAuthUsersScaler implements Scaler {
  FirebaseAuthUsersScaler(this.api);

  final GoogleApi api;

  @override
  String get type => 'firebaseAuthUsers';

  @override
  Future<double> read(Trigger t, Deployment i) async {
    var count = 0;
    String? page;
    do {
      final body = await api.get(
        Uri.https(
          'identitytoolkit.googleapis.com',
          '/v1/projects/${api.project}/accounts:batchGet',
          {'maxResults': '1000', 'nextPageToken': ?page},
        ),
      );
      count += (body['users'] as List?)?.length ?? 0;
      page = body['nextPageToken'] as String?;
    } while (page != null && page.isNotEmpty);
    return count.toDouble();
  }
}

/// Highest daily Firestore op count (`op`: read|write|delete) over the last
/// 7 days from Cloud Monitoring.
class FirestoreDailyOpsScaler implements Scaler {
  FirestoreDailyOpsScaler(this.api, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final GoogleApi api;
  final DateTime Function() _now;

  @override
  String get type => 'firestoreDailyOps';

  @override
  Future<double> read(Trigger t, Deployment i) async {
    final op = t.scaler.params['op'];
    final end = _now().toUtc();
    final daily = <String, double>{};
    String? page;
    do {
      final body = await api.get(
        Uri.https(
          'monitoring.googleapis.com',
          '/v3/projects/${api.project}/timeSeries',
          {
            'filter':
                'metric.type="firestore.googleapis.com/document/'
                '${op}_ops_count"',
            'interval.startTime': end
                .subtract(const Duration(days: 7))
                .toIso8601String(),
            'interval.endTime': end.toIso8601String(),
            'aggregation.alignmentPeriod': '86400s',
            'aggregation.perSeriesAligner': 'ALIGN_SUM',
            'aggregation.crossSeriesReducer': 'REDUCE_SUM',
            'pageToken': ?page,
          },
        ),
      );
      for (final s in (body['timeSeries'] as List?) ?? const []) {
        for (final p in ((s as Map)['points'] as List?) ?? const []) {
          final day = '${(p as Map)['interval']?['endTime']}';
          final v = p['value'] as Map? ?? const {};
          final n = num.tryParse('${v['int64Value'] ?? v['doubleValue']}');
          if (n != null) daily[day] = (daily[day] ?? 0) + n;
        }
      }
      page = body['nextPageToken'] as String?;
    } while (page != null && page.isNotEmpty);
    return daily.values.fold<double>(0, (a, b) => a > b ? a : b);
  }
}

/// Hosting storage in GiB across all sites in the project, using FINALIZED
/// version sizes as in scripts/web/hosting_storage_guard.py.
class HostingStorageScaler implements Scaler {
  HostingStorageScaler(this.api);

  final GoogleApi api;

  @override
  String get type => 'hostingStorage';

  @override
  Future<double> read(Trigger t, Deployment i) async {
    final projectPath = '/v1beta1/projects/${api.project}/sites';
    final sites = <String>{};
    await for (final site in _list(projectPath, 'sites')) {
      final name = site['name'] as String;
      final match = RegExp(
        r'^projects/[a-zA-Z0-9_-]+/(sites/[a-z0-9-]+)$',
      ).firstMatch(name);
      if (match == null || match.end != name.length) {
        throw FormatException('Invalid Hosting site name', name);
      }
      sites.add(match[1]!);
    }
    final selected = i.firebase?.siteId ?? api.project;
    if (!sites.contains('sites/$selected')) {
      throw StateError('Hosting inventory is missing site $selected');
    }

    var bytes = 0;
    for (final site in sites) {
      final names = <String>{};
      final prefix = '$site/versions/';
      await for (final version in _list(
        '/v1beta1/$site/versions',
        'versions',
      )) {
        final status = version['status'] as String;
        if (status != 'FINALIZED') continue;
        final name = version['name'] as String;
        final size = int.parse('${version['versionBytes'] ?? 0}', radix: 10);
        if (!name.startsWith(prefix) || size < 0 || !names.add(name)) {
          throw FormatException('Invalid Hosting version inventory', name);
        }
        bytes += size;
      }
    }
    return bytes / (1024 * 1024 * 1024);
  }

  Stream<Map<String, Object?>> _list(String path, String key) async* {
    String? page;
    final seen = <String>{};
    do {
      final body = await api.get(
        Uri.https('firebasehosting.googleapis.com', path, {
          'pageSize': '100',
          'pageToken': ?page,
        }),
      );
      final next = body.containsKey('nextPageToken')
          ? body['nextPageToken'] as String
          : '';
      // ProtoJSON omits empty repeated fields, so an absent list is empty.
      final rows = body.containsKey(key) ? body[key] as List : const [];
      if (body.containsKey('error') || (next.isNotEmpty && !seen.add(next))) {
        throw StateError('Incomplete Hosting inventory for $path');
      }
      for (final row in rows) {
        yield (row as Map).cast<String, Object?>();
      }
      page = next;
    } while (page.isNotEmpty);
  }
}

/// Live scalers for an instance's Firebase project.
Map<String, Scaler> liveScalers(Deployment i, {http.Client? client}) {
  final project = i.firebase?.projectId;
  if (project == null) return {};
  final api = GoogleApi(project, client: client);
  return {
    for (final s in <Scaler>[
      FirebaseAuthUsersScaler(api),
      FirestoreDailyOpsScaler(api),
      HostingStorageScaler(api),
    ])
      s.type: s,
  };
}
