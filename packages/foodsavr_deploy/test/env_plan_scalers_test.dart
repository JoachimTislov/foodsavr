import 'dart:convert';

import 'package:foodsavr_deploy/foodsavr_deploy.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('env', () {
    test('dotenv carries identity, flavor and is shell-quoted', () {
      final m = baseManifest();
      m['identity']['name'] = "it's";
      final out = renderEnv(
        Deployment.of(load(m), 'production'),
        EnvFormat.dotenv,
      );
      expect(out, contains("FLAVOR='production'\n"));
      expect(out, contains("PROJECT_ID='p-prod'\n"));
      expect(out, contains("TF_STATE_BUCKET='p-prod-tfstate'\n"));
      expect(out, contains("TF_STATE_PREFIX='firebase'\n"));
      expect(out, contains("VAR_SUFFIX=''\n"));
      expect(out, contains(r"INSTANCE_NAME='it'\''s'"));
    });

    test('github format omits reserved GITHUB_* names', () {
      final d = Deployment.of(load(baseManifest()), 'development');
      final out = renderEnv(d, EnvFormat.github);
      expect(out, contains('FLAVOR=development\n'));
      expect(out, contains('EMULATOR=true\n'));
      expect(out, contains('VAR_SUFFIX=_DEVELOPMENT\n'));
      expect(out, isNot(contains('GITHUB_')));
      expect(out, isNot(contains('PROJECT_ID')));
    });

    test(
      'tfvars include level, firebase_plan, region, and the budget of paid levels',
      () {
        final m = baseManifest();
        m['environments']['production']['currentLevel'] = 'blaze';
        final out = renderEnv(
          Deployment.of(load(m), 'production'),
          EnvFormat.tfvars,
        );
        expect(out, contains('level = "blaze"\n'));
        expect(out, contains('firebase_plan = "blaze"\n'));
        expect(out, contains('region = "europe-north1"\n'));
        expect(out, contains('project_id = "p-prod"\n'));
        expect(out, contains('monthly_budget_usd = 10\n'));
      },
    );

    Map<String, dynamic> channelManifest() {
      final m = baseManifest();
      m['environments']['test'] = {
        'currentLevel': 'spark',
        'firebase': {'projectId': 'p-test', 'webAppId': '1:2:web:2'},
        'channels': {'develop': 'p-test', 'daily': 'p-test-daily'},
      };
      return m;
    }

    test('channels resolve their environment and Hosting site', () {
      final i = load(channelManifest());
      expect(i.environmentForChannel('daily')?.name, 'test');
      expect(i.environmentForChannel('stable')?.name, 'production');
      expect(i.environmentForChannel('weekly'), isNull);
      final out = renderEnv(
        Deployment.of(i, 'test'),
        EnvFormat.dotenv,
        channel: 'daily',
      );
      expect(out, contains("CHANNEL='daily'\n"));
      expect(out, contains("SITE_ID='p-test-daily'\n"));
      expect(out, contains("VAR_SUFFIX='_TEST'\n"));
      expect(out, contains("PROVISIONED='true'\n"));
      expect(
        renderEnv(Deployment.of(i, 'production'), EnvFormat.dotenv),
        contains("SITE_ID='p-prod'\n"),
      );
    });

    test('tfvars list channel branches and the extra Hosting sites', () {
      final out = renderEnv(
        Deployment.of(load(channelManifest()), 'test'),
        EnvFormat.tfvars,
      );
      expect(out, contains('deploy_branches = ["develop", "daily"]\n'));
      expect(out, contains('hosting_sites = ["p-test-daily"]\n'));
    });

    test('unprovisioned environments emit no cloud identity', () {
      final m = baseManifest();
      m['environments']['production'] = {
        'currentLevel': 'spark',
        'provisioned': false,
      };
      final out = renderEnv(
        Deployment.of(load(m), 'production'),
        EnvFormat.github,
        channel: 'stable',
      );
      expect(out, contains('PROVISIONED=false\n'));
      expect(out, isNot(contains('PROJECT_ID')));
      expect(out, isNot(contains('SITE_ID')));
    });

    test('unknown environment is an argument error', () {
      expect(
        () => Deployment.of(load(baseManifest()), 'staging'),
        throwsArgumentError,
      );
    });
  });

  group('plan', () {
    final d = Deployment.of(load(baseManifest()), 'production');

    test('next level uses the declared migration', () {
      final p = planTransition(d)!;
      expect(p.to.name, 'blaze');
      expect(p.declared, isTrue);
      expect(p.enablesBilling, isTrue);
      expect(p.approvalRequired, isTrue); // recommend mode
      expect(p.steps.first, contains('ADR 0003'));
      expect(p.toJson()['class'], 'inPlace');
    });

    test('jumps derive steps from the binding diff', () {
      final p = planTransition(d, to: 'supa')!;
      expect(p.direction, 'jump');
      expect(p.migrationClass, MigrationClass.authMove);
      expect(p.declared, isFalse);
      expect(p.executable, isFalse);
      expect(p.bindingChanges.map((c) => c.capability), ['auth', 'documents']);
    });

    test('auto mode lifts approval only for inPlace', () {
      final m = baseManifest();
      m['behavior']['mode'] = 'auto';
      final auto = Deployment.of(load(m), 'production');
      expect(planTransition(auto)!.approvalRequired, isFalse);
      expect(planTransition(auto, to: 'supa')!.approvalRequired, isTrue);
    });
  });

  group('scalers', () {
    final d = Deployment.of(load(baseManifest()), 'production');
    final trigger = d.triggers.first;

    test('auth users are counted across batchGet pages', () async {
      final seen = <Uri>[];
      final client = MockClient((req) async {
        seen.add(req.url);
        expect(req.headers['x-goog-user-project'], 'p-prod');
        expect(req.headers['authorization'], 'Bearer tok');
        final page = req.url.queryParameters['nextPageToken'];
        return http.Response(
          jsonEncode(
            page == null
                ? {'users': List.filled(1000, {}), 'nextPageToken': 'p2'}
                : {'users': List.filled(5, {})},
          ),
          200,
        );
      });
      final api = GoogleApi('p-prod', client: client, token: 'tok');
      expect(await FirebaseAuthUsersScaler(api).read(trigger, d), 1005);
      expect(seen, hasLength(2));
    });

    test('firestore ops take the max daily sum', () async {
      final client = MockClient(
        (req) async => http.Response(
          jsonEncode({
            'timeSeries': [
              {
                'points': [
                  {
                    'interval': {'endTime': 'd1'},
                    'value': {'int64Value': '120'},
                  },
                  {
                    'interval': {'endTime': 'd2'},
                    'value': {'int64Value': '300'},
                  },
                ],
              },
              {
                'points': [
                  {
                    'interval': {'endTime': 'd1'},
                    'value': {'int64Value': '200'},
                  },
                ],
              },
            ],
          }),
          200,
        ),
      );
      final api = GoogleApi('p-prod', client: client, token: 'tok');
      expect(await FirestoreDailyOpsScaler(api).read(trigger, d), 320);
    });

    test('hosting storage sums FINALIZED versions in GiB', () async {
      final client = MockClient(
        (req) async => http.Response(
          jsonEncode({
            'versions': [
              {'status': 'FINALIZED', 'versionBytes': '${1 << 30}'},
              {'status': 'DELETED', 'versionBytes': '${5 << 30}'},
            ],
          }),
          200,
        ),
      );
      final api = GoogleApi('p-prod', client: client, token: 'tok');
      expect(await HostingStorageScaler(api).read(trigger, d), 1.0);
    });

    test('HTTP errors throw (poller falls back to hold)', () async {
      final client = MockClient((req) async => http.Response('no', 403));
      final api = GoogleApi('p-prod', client: client, token: 'tok');
      expect(
        HostingStorageScaler(api).read(trigger, d),
        throwsA(isA<StateError>()),
      );
    });
  });
}
