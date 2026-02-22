import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

// Import from the tool if it was exported, but since it's a CLI script,
// we might need to test it by running it as a process or extracting the logic.
// For TDD of the logic, we'll implement the tests for the core functions.

// Since the tool is in 'tool/', we'll define the expected behavior here.
// In a real TDD scenario, we'd have a library we can import.
// For now, let's test the CLI behavior using Process.run.

void main() {
  late Directory tempDir;
  late Directory assetsDir;
  late Directory libDir;
  late File enJson;
  late File nbJson;
  late File mainDart;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('loc_test');
    assetsDir = await Directory(
      '${tempDir.path}/assets/translations',
    ).create(recursive: true);
    libDir = await Directory('${tempDir.path}/lib').create(recursive: true);

    enJson = File('${assetsDir.path}/en-US.json');
    nbJson = File('${assetsDir.path}/nb-NO.json');
    mainDart = File('${libDir.path}/main.dart');

    await enJson.writeAsString(
      jsonEncode({
        'auth': {'login': 'Login'},
      }),
    );
    await nbJson.writeAsString(
      jsonEncode({
        'auth': {'login': 'Logg inn'},
      }),
    );
    await mainDart.writeAsString('''
      import 'package:easy_localization/easy_localization.dart';
      void main() {
        print("auth.login".tr());
      }
    ''');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<ProcessResult> runCheck() async {
    return Process.run('dart', [
      '/home/joachim/projects/foodsavr-gemini/tool/check_localizations.dart',
    ], workingDirectory: tempDir.path);
  }

  test('Validation passes with consistent files', () async {
    final result = await runCheck();
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout, contains('Localization validation passed'));
  });

  test('Validation fails if key is missing in JSON', () async {
    await mainDart.writeAsString('''
      void main() {
        print("auth.missing".tr());
      }
    ''');
    final result = await runCheck();
    expect(result.exitCode, 1);
    expect(result.stdout, contains('Missing keys from source'));
    expect(result.stdout, contains('auth.missing'));
  });

  test('Validation fails if key is unused in source', () async {
    await enJson.writeAsString(
      jsonEncode({
        'auth': {'login': 'Login', 'unused': 'Unused'},
      }),
    );
    // nbJson still only has login, so it should also fail on consistency
    final result = await runCheck();
    expect(result.exitCode, 1);
    expect(result.stdout, contains('Unused keys'));
    expect(result.stdout, contains('auth.unused'));
  });

  test(
    'Validation fails if structure is inconsistent (missing in one locale)',
    () async {
      await enJson.writeAsString(
        jsonEncode({
          'auth': {'login': 'Login', 'extra': 'Extra'},
        }),
      );
      // Use it in source so it's not "unused"
      await mainDart.writeAsString('''
      void main() {
        print("auth.login".tr());
        print("auth.extra".tr());
      }
    ''');

      final result = await runCheck();
      expect(result.exitCode, 1);
      expect(
        result.stdout,
        contains('is missing keys present in other locales'),
      );
      expect(result.stdout, contains('auth.extra'));
    },
  );
}
