import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late Directory assetsDir;
  late Directory libDir;
  late File enJson;
  late File nbJson;
  late File mainDart;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gen_test');
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
      void main() {
        print("auth.login".tr());
      }
    ''');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<ProcessResult> runGenerate() async {
    return Process.run('dart', [
      '/home/joachim/projects/foodsavr-gemini/tool/generate_localizations.dart',
    ], workingDirectory: tempDir.path);
  }

  test('Generates stubs for keys in source but not in JSON', () async {
    await mainDart.writeAsString('''
      void main() {
        print("auth.login".tr());
        print("auth.new_key".tr());
      }
    ''');

    final result = await runGenerate();
    expect(result.exitCode, 0, reason: result.stderr.toString());

    final enMap =
        jsonDecode(await enJson.readAsString()) as Map<String, dynamic>;
    final nbMap =
        jsonDecode(await nbJson.readAsString()) as Map<String, dynamic>;

    expect(enMap['auth']['new_key'], '[STUB] auth.new_key');
    expect(nbMap['auth']['new_key'], '[STUB] auth.new_key');
  });

  test('Generates stubs for keys in one locale but not in others', () async {
    await enJson.writeAsString(
      jsonEncode({
        'auth': {'login': 'Login', 'only_in_en': 'Only in EN'},
      }),
    );

    final result = await runGenerate();
    expect(result.exitCode, 0);

    final nbMap =
        jsonDecode(await nbJson.readAsString()) as Map<String, dynamic>;
    expect(nbMap['auth']['only_in_en'], '[STUB] auth.only_in_en');
  });

  test('Resulting JSON is sorted alphabetically', () async {
    await enJson.writeAsString(
      jsonEncode({'zebra': 'Zebra', 'apple': 'Apple'}),
    );

    await runGenerate();

    final enContent = await enJson.readAsString();
    final firstKeyIndex = enContent.indexOf('apple');
    final secondKeyIndex = enContent.indexOf('zebra');
    expect(firstKeyIndex < secondKeyIndex, isTrue);
  });
}
