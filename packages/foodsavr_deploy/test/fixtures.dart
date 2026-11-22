import 'dart:convert';

import 'package:foodsavr_deploy/foodsavr_deploy.dart';

/// A small valid manifest as plain data; tests mutate a copy.
Map<String, dynamic> baseManifest() => {
  'version': 1,
  'identity': {
    'name': 't',
    'githubRepository': 'me/foodsavr',
    'region': 'europe-north1',
  },
  'capabilities': ['auth', 'documents', 'hosting'],
  'levels': [
    {
      'name': 'spark',
      'provider': 'firebase',
      'plan': 'spark',
      'status': 'built',
      'paid': false,
      'limits': {'authUsersTotal': 1000, 'readsPerDay': 100},
      'bindings': {
        'auth': 'firebase/auth',
        'documents': 'firebase/firestore',
        'hosting': 'firebase/hosting',
      },
    },
    {
      'name': 'blaze',
      'provider': 'firebase',
      'plan': 'blaze',
      'status': 'built',
      'paid': true,
      'limits': {'authUsersTotal': 10000, 'readsPerDay': 1000},
      'bindings': {
        'auth': 'firebase/auth',
        'documents': 'firebase/firestore',
        'hosting': 'firebase/hosting',
      },
      'budget': {
        'monthlyUsd': 10,
        'alertThresholds': [0.5, 1.0],
      },
      'migration': {
        'class': 'inPlace',
        'reversible': true,
        'steps': ['Link billing.'],
      },
    },
    {
      'name': 'supa',
      'provider': 'supabase',
      'plan': 'free',
      'status': 'spec-ahead',
      'paid': false,
      'limits': {'authUsersTotal': 50000},
      'bindings': {
        'auth': 'supabase/auth',
        'documents': 'supabase/postgres',
        'hosting': 'firebase/hosting',
      },
      'migration': {
        'class': 'authMove',
        'reversible': false,
        'steps': ['Move users.'],
      },
    },
  ],
  'triggers': [
    {
      'name': 'users',
      'capability': 'auth',
      'binding': 'firebase/auth',
      'scaler': {'type': 'file'},
      'limit': 'authUsersTotal',
      'warn': 0.7,
      'promote': 0.9,
      'demote': 0.3,
    },
    {
      'name': 'reads',
      'capability': 'documents',
      'binding': 'firebase/firestore',
      'scaler': {'type': 'file'},
      'limit': 'readsPerDay',
      'warn': 0.6,
      'promote': 0.8,
      'demote': 0.2,
    },
  ],
  'behavior': {
    'pollingInterval': '24h',
    'stabilizationPolls': 2,
    'minDwell': '7d',
    'mode': 'recommend',
    'fallback': {'action': 'hold', 'alertAfterFailures': 2},
  },
  'environments': {
    'development': {'currentLevel': 'spark', 'emulator': true},
    'production': {
      'currentLevel': 'spark',
      'firebase': {'projectId': 'p-prod', 'webAppId': '1:1:web:1'},
    },
  },
};

/// Parses [m] (JSON is YAML); throws with the errors if structurally bad.
DeploymentInstance load(Map<String, dynamic> m) {
  final r = parseManifest(jsonEncode(m));
  if (r.instance == null) throw StateError(r.errors.join('\n'));
  return r.instance!;
}

List<String> errorsOf(Map<String, dynamic> m) {
  final r = parseManifest(jsonEncode(m));
  return r.instance == null ? r.errors : validate(r.instance!).errors;
}
