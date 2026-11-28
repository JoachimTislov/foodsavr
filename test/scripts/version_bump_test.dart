import 'package:test/test.dart';

import '../../scripts/version/version_bump.dart';

void main() {
  const pubspec = 'name: app\nversion: 1.4.7+12\ndependencies:\n  a: ^1.0.0\n';

  test('parses MAJOR.MINOR.PATCH+BUILD', () {
    expect(parseVersion(pubspec).toString(), '1.4.7+12');
  });

  test('patch bump keeps major and minor', () {
    expect(parseVersion(pubspec).bump(BumpPart.patch).toString(), '1.4.8+13');
  });

  test('minor bump resets patch', () {
    expect(parseVersion(pubspec).bump(BumpPart.minor).toString(), '1.5.0+13');
  });

  test('major bump resets minor and patch', () {
    expect(parseVersion(pubspec).bump(BumpPart.major).toString(), '2.0.0+13');
  });

  test('replaceVersion rewrites only the version line', () {
    final next = parseVersion(pubspec).bump(BumpPart.minor);
    expect(
      replaceVersion(pubspec, next),
      'name: app\nversion: 1.5.0+13\ndependencies:\n  a: ^1.0.0\n',
    );
  });

  test('rejects a missing build number or missing line', () {
    expect(() => parseVersion('version: 1.0.0\n'), throwsFormatException);
    expect(() => parseVersion('name: app\n'), throwsFormatException);
  });

  test('parsePart rejects unknown values', () {
    expect(parsePart('minor'), BumpPart.minor);
    expect(() => parsePart('huge'), throwsFormatException);
  });
}
