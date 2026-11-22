import 'package:foodsavr_deploy/foodsavr_deploy.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

Matcher hasError(String fragment) =>
    contains(predicate<String>((e) => e.contains(fragment), fragment));

void main() {
  test('repository manifests are valid', () {
    for (final path in [
      '../../deploy/instance.yaml',
      '../../deploy/examples/firebase-free-web.yaml',
    ]) {
      final r = loadManifest(path);
      expect(r.errors, isEmpty, reason: path);
      expect(validate(r.instance!).errors, isEmpty, reason: path);
    }
  });

  test('base fixture is valid', () {
    expect(errorsOf(baseManifest()), isEmpty);
  });

  group('structure', () {
    test('unknown and missing keys are reported with paths', () {
      final m = baseManifest();
      (m['levels'] as List)[0]['colour'] = 'red';
      (m['levels'] as List)[1].remove('plan');
      expect(errorsOf(m), hasError('levels[0].colour: unknown key'));
      expect(errorsOf(m), hasError('levels[1].plan: required'));
    });

    test('environment names are the four flavors', () {
      final m = baseManifest();
      m['environments']['qa'] = {'currentLevel': 'spark', 'emulator': true};
      expect(errorsOf(m), hasError('environments.qa: unknown key'));
    });
  });

  group('ladder', () {
    test('level names are unique', () {
      final m = baseManifest();
      (m['levels'] as List)[2]['name'] = 'blaze';
      expect(errorsOf(m), hasError('duplicate name'));
    });

    test('built levels bind every capability', () {
      final m = baseManifest();
      (m['levels'] as List)[1]['bindings'].remove('hosting');
      expect(errorsOf(m), hasError('must bind capability hosting'));
    });

    test('spec-ahead levels may leave capabilities unbound', () {
      final m = baseManifest();
      (m['levels'] as List)[2]['bindings'].remove('hosting');
      expect(errorsOf(m), isEmpty);
    });

    test('paid levels declare a budget', () {
      final m = baseManifest();
      (m['levels'] as List)[1].remove('budget');
      expect(errorsOf(m), hasError('paid level must declare a budget'));
    });

    test('migration class cannot understate the binding diff', () {
      final m = baseManifest();
      (m['levels'] as List)[2]['migration']['class'] = 'inPlace';
      expect(errorsOf(m), hasError('understates the binding diff'));
    });
  });

  group('environments', () {
    test('production is required', () {
      final m = baseManifest();
      m['environments'].remove('production');
      expect(errorsOf(m), hasError('production is required'));
    });

    test('currentLevel must exist and be built', () {
      final m = baseManifest();
      m['environments']['production']['currentLevel'] = 'nope';
      expect(errorsOf(m), hasError('currentLevel nope is not a level'));
      m['environments']['production']['currentLevel'] = 'supa';
      expect(errorsOf(m), hasError('must be a built level'));
    });

    test('cloud firebase environments need an identity', () {
      final m = baseManifest();
      m['environments']['production'].remove('firebase');
      expect(errorsOf(m), hasError('needs firebase identity'));
    });

    test('identities are unique unless sharedWith', () {
      final m = baseManifest();
      m['environments']['staging'] = {
        'currentLevel': 'spark',
        'firebase': {'projectId': 'p-prod', 'webAppId': '1:1:web:2'},
      };
      expect(errorsOf(m), hasError('share Firebase project p-prod'));
      m['environments']['staging']['sharedWith'] = ['production'];
      expect(errorsOf(m), isEmpty);
    });

    test('each environment can sit at its own level', () {
      final m = baseManifest();
      m['environments']['production']['currentLevel'] = 'blaze';
      final i = load(m);
      expect(validate(i).errors, isEmpty);
      expect(Deployment.of(i, 'production').current.name, 'blaze');
      expect(Deployment.of(i, 'development').current.name, 'spark');
    });

    test('overrides must name existing triggers and keep bands ordered', () {
      final m = baseManifest();
      m['environments']['production']['triggers'] = {
        'ghost': {'warn': 0.5},
        'users': {'warn': 0.95},
      };
      final errors = errorsOf(m);
      expect(errors, hasError('override for unknown trigger ghost'));
      expect(errors, hasError('trigger users: warn must be < promote'));
    });
  });

  group('mode', () {
    test('auto is allowed when the next transition is inPlace', () {
      final m = baseManifest();
      m['behavior']['mode'] = 'auto';
      expect(errorsOf(m), isEmpty);
    });

    test('auto is rejected when the next transition moves data', () {
      final m = baseManifest();
      m['environments']['production']['currentLevel'] = 'blaze';
      m['environments']['production']['behavior'] = {'mode': 'auto'};
      expect(errorsOf(m), hasError('mode auto is only allowed'));
    });
  });

  group('triggers', () {
    test('warn < promote and demote < warn', () {
      final m = baseManifest();
      (m['triggers'] as List)[0]['promote'] = 0.5;
      (m['triggers'] as List)[1]['demote'] = 0.7;
      final errors = errorsOf(m);
      expect(errors, hasError('warn must be < promote'));
      expect(errors, hasError('demote must be >= 0 and < warn'));
    });

    test('limit must exist on built levels where the trigger is active', () {
      final m = baseManifest();
      (m['levels'] as List)[0]['limits'].remove('readsPerDay');
      expect(errorsOf(m), hasError('limit readsPerDay missing on level spark'));
    });

    test('scaler type must be known', () {
      final m = baseManifest();
      (m['triggers'] as List)[0]['scaler'] = {'type': 'keda'};
      expect(errorsOf(m), hasError('unknown scaler keda'));
    });
  });

  test('transitionClass follows the binding diff', () {
    final i = load(baseManifest());
    expect(transitionClass(i.levels[0], i.levels[1]), MigrationClass.inPlace);
    expect(transitionClass(i.levels[1], i.levels[2]), MigrationClass.authMove);
  });
}
