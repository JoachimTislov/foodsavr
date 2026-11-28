/// Pure semver bump logic for the `version: MAJOR.MINOR.PATCH+BUILD` line of
/// `pubspec.yaml`. See specs/ci-workflows.md, "Versioning and release tags".
library;

enum BumpPart { major, minor, patch }

final RegExp _versionLine = RegExp(
  r'^version:[ \t]*(\d+)\.(\d+)\.(\d+)\+(\d+)[ \t]*$',
  multiLine: true,
);

/// A parsed `MAJOR.MINOR.PATCH+BUILD` version.
class AppVersion {
  const AppVersion(this.major, this.minor, this.patch, this.build);

  final int major;
  final int minor;
  final int patch;
  final int build;

  /// Applies semver rules and always increments [build] by one.
  AppVersion bump(BumpPart part) => switch (part) {
    BumpPart.major => AppVersion(major + 1, 0, 0, build + 1),
    BumpPart.minor => AppVersion(major, minor + 1, 0, build + 1),
    BumpPart.patch => AppVersion(major, minor, patch + 1, build + 1),
  };

  @override
  String toString() => '$major.$minor.$patch+$build';
}

/// Parses the `version:` line of [pubspec]; throws [FormatException] if it is
/// missing or not of the form `MAJOR.MINOR.PATCH+BUILD`.
AppVersion parseVersion(String pubspec) {
  final match = _versionLine.firstMatch(pubspec);
  if (match == null) {
    throw const FormatException(
      'pubspec.yaml has no "version: MAJOR.MINOR.PATCH+BUILD" line.',
    );
  }
  return AppVersion(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
  );
}

/// Returns [pubspec] with only the `version:` line replaced.
String replaceVersion(String pubspec, AppVersion next) =>
    pubspec.replaceFirstMapped(_versionLine, (_) => 'version: $next');

/// Parses a `major|minor|patch` argument; throws [FormatException] otherwise.
BumpPart parsePart(String value) {
  for (final part in BumpPart.values) {
    if (part.name == value) return part;
  }
  throw FormatException('Unknown part "$value"; use major, minor or patch.');
}
