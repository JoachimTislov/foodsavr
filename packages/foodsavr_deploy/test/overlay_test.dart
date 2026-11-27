import 'dart:convert';
import 'dart:io';

import 'package:foodsavr_deploy/foodsavr_deploy.dart';
import 'package:test/test.dart';

const _overlay = {
  'identity': {'githubRepository': 'someone/fork'},
  'environments': {
    'test': {
      'provisioned': true,
      'firebase': {'projectId': 'fork-test', 'webAppId': '1:1:web:1'},
      'channels': {
        'develop': 'fork-test',
        'daily': 'fork-test-daily',
        'weekly': 'fork-test-weekly',
      },
    },
  },
};

void main() {
  const manifest = '../../deploy/instance.yaml';

  test('tracked manifest is unbound: no cloud environment is provisioned', () {
    final r = loadManifest(manifest);
    expect(r.errors, isEmpty);
    final instance = r.instance!;
    expect(validate(instance).errors, isEmpty);
    expect(instance.identity.githubRepository, isNull);
    expect(
      instance.environments.values.where((e) => e.cloud && e.provisioned),
      isEmpty,
    );
  });

  test('overlay merges instance state over the shared ladder', () {
    final r = loadManifest(manifest, overlay: jsonEncode(_overlay));
    expect(r.errors, isEmpty);
    final instance = r.instance!;
    expect(validate(instance).errors, isEmpty);
    expect(instance.identity.githubRepository, 'someone/fork');
    expect(instance.identity.region, isNotEmpty, reason: 'base kept');
    final test = instance.environments['test']!;
    expect(test.firebase!.projectId, 'fork-test');
    expect(test.channels['daily'], 'fork-test-daily');
    expect(test.githubEnvironment, 'test', reason: 'base kept');
  });

  test('provisioned environments need the repository', () {
    final overlay = {..._overlay}..remove('identity');
    final r = loadManifest(manifest, overlay: jsonEncode(overlay));
    expect(
      validate(r.instance!).errors,
      contains(contains('identity.githubRepository')),
    );
  });

  test('instanceOverlay prefers DEPLOY_INSTANCE, then local state', () {
    final dir = Directory.systemTemp.createTempSync('overlay');
    addTearDown(() => dir.deleteSync(recursive: true));
    final local = File('${dir.path}/instance.local.json')
      ..writeAsStringSync(jsonEncode({'deployInstance': _overlay}));
    final env = {'FOODSAVR_INSTANCE_LOCAL': local.path};
    expect(jsonDecode(instanceOverlay(dir.path, env)!), _overlay);
    expect(
      instanceOverlay(dir.path, {...env, 'DEPLOY_INSTANCE': '{"a": 1}'}),
      '{"a": 1}',
    );
    expect(
      instanceOverlay(dir.path, {
        'FOODSAVR_INSTANCE_LOCAL': '${dir.path}/missing.json',
      }),
      isNull,
    );
    expect(
      jsonDecode(
        instanceOverlay(dir.path, {
          'HOME': dir.path,
          'FOODSAVR_INSTANCE_LOCAL': '~/instance.local.json',
        })!,
      ),
      _overlay,
      reason: '~ expands as in scripts/instance_local.py',
    );
  });
}
