// Deployment levels CLI (ADR 0005). Recommends only; never mutates infra.
//
//   levels validate [manifest] [--env E]
//   levels plan [--to LEVEL] [--env E] [--json]
//   levels poll [--state FILE] [--metrics FILE] [--summary FILE] [--json]
//   levels env [--format dotenv|github|tfvars] [--env E] [--channel C]
//   levels environments [--cloud] [--json]
//
// `env --channel C` without `--env` selects the environment that deploys
// release channel C (exit 3 when none does) and emits that channel's site.
//
// The manifest defaults to deploy/instance.yaml in the repository root.
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:foodsavr_deploy/foodsavr_deploy.dart';

const _encoder = JsonEncoder.withIndent('  ');

ArgParser _common() => ArgParser()
  ..addOption('manifest', abbr: 'm', help: 'Manifest path')
  ..addOption('env', abbr: 'e', defaultsTo: 'production', allowed: flavors);

Future<void> main(List<String> argv) async {
  final parser = ArgParser()..addFlag('help', abbr: 'h', negatable: false);
  parser
    ..addCommand('validate', _common())
    ..addCommand(
      'plan',
      _common()
        ..addOption('to')
        ..addFlag('json'),
    )
    ..addCommand(
      'poll',
      _common()
        ..addOption('state', help: 'JSON state file (read, then written)')
        ..addOption('metrics', help: 'JSON metrics file (file scaler)')
        ..addOption('summary', help: 'Also write Markdown here')
        ..addFlag('json'),
    )
    ..addCommand(
      'env',
      _common()
        ..addOption(
          'format',
          defaultsTo: 'dotenv',
          allowed: [for (final f in EnvFormat.values) f.name],
        )
        ..addOption('channel', help: 'Release channel (branch) to deploy'),
    )
    ..addCommand(
      'environments',
      _common()
        ..addFlag('cloud', help: 'Only provisioned non-emulator environments')
        ..addFlag('json'),
    );

  ArgResults args;
  try {
    args = parser.parse(argv);
  } on FormatException catch (e) {
    _die('${e.message}\n\n${parser.usage}', 64);
  }
  final cmd = args.command;
  if (args.flag('help') || cmd == null) {
    stdout.writeln(
      'usage: levels <validate|plan|poll|env|environments> [options]\n'
      '${parser.usage}',
    );
    exit(cmd == null && !args.flag('help') ? 64 : 0);
  }
  final manifest =
      cmd.option('manifest') ??
      (cmd.rest.isNotEmpty ? cmd.rest.first : _defaultManifest());
  final parsed = loadManifest(manifest);
  if (parsed.instance == null) {
    _report(manifest, parsed.errors, const []);
    exit(1);
  }
  final instance = parsed.instance!;
  final report = validate(instance);
  if (cmd.name == 'validate') {
    _report(manifest, report.errors, report.warnings);
    if (report.ok) {
      stdout.writeln(
        '$manifest: OK (${instance.levels.length} levels, '
        '${instance.triggers.length} triggers, environments: '
        '${[for (final e in instance.environments.values) '${e.name}@${e.currentLevel}'].join(', ')})',
      );
    }
    exit(report.ok ? 0 : 1);
  }
  if (!report.ok) {
    _report(manifest, report.errors, report.warnings);
    exit(1);
  }
  if (cmd.name == 'environments') {
    final envs = [
      for (final e in instance.environments.values)
        if (!cmd.flag('cloud') || (e.cloud && e.provisioned)) e,
    ];
    if (cmd.flag('json')) {
      stdout.writeln(
        jsonEncode([
          for (final e in envs)
            {
              'name': e.name,
              'level': e.currentLevel,
              'emulator': e.emulator,
              'provisioned': e.provisioned,
              'channels': e.servedChannels.toList(),
              'varSuffix': varSuffix(e.name),
            },
        ]),
      );
    } else {
      for (final e in envs) {
        stdout.writeln(
          '${e.name} ${e.currentLevel} ${e.emulator ? 'emulator' : 'cloud'}',
        );
      }
    }
    return;
  }
  final channel = cmd.name == 'env' ? cmd.option('channel') : null;
  var envName = cmd.option('env')!;
  if (channel != null && !cmd.wasParsed('env')) {
    final served = instance.environmentForChannel(channel);
    if (served == null) _die('no environment deploys channel $channel', 3);
    envName = served.name;
  }
  final Deployment d;
  try {
    d = Deployment.of(instance, envName);
  } on ArgumentError catch (e) {
    _die('--env ${e.message}', 64);
  }
  if (channel != null &&
      d.environment.channels.isNotEmpty &&
      !d.environment.channels.containsKey(channel)) {
    _die('environment $envName does not deploy channel $channel', 64);
  }

  switch (cmd.name) {
    case 'plan':
      final plan = planTransition(d, to: cmd.option('to'));
      if (plan == null) {
        _die(
          cmd.option('to') == null
              ? '${d.currentLevel} is the top level; nothing to plan'
              : 'no level ${cmd.option('to')} (or already current)',
          1,
        );
      }
      stdout.writeln(
        cmd.flag('json') ? _encoder.convert(plan.toJson()) : plan.toMarkdown(),
      );
    case 'poll':
      final statePath = cmd.option('state');
      final stateFile = statePath == null ? null : File(statePath);
      final state = stateFile != null && stateFile.existsSync()
          ? PollState.fromJson(
              (jsonDecode(stateFile.readAsStringSync()) as Map)
                  .cast<String, Object?>(),
            )
          : PollState();
      final metrics = cmd.option('metrics');
      final Map<String, Scaler> scalers;
      if (metrics != null) {
        final file = FileScaler.load(metrics);
        // Dry run: every trigger reads from the metrics file.
        scalers = {for (final t in scalerTypes) t: file};
      } else {
        scalers = liveScalers(d);
      }
      final result = await poll(d, state, scalers);
      if (stateFile != null) {
        stateFile
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(_encoder.convert(state.toJson()));
      }
      final summary = cmd.option('summary');
      if (summary != null) File(summary).writeAsStringSync(result.toMarkdown());
      stdout.writeln(
        cmd.flag('json')
            ? _encoder.convert(result.toJson())
            : result.toMarkdown(),
      );
    case 'env':
      stdout.write(
        renderEnv(
          d,
          EnvFormat.values.byName(cmd.option('format')!),
          channel: channel,
        ),
      );
  }
}

/// deploy/instance.yaml at the repository root (found by walking up), so
/// the CLI works from the repo root and from the package directory.
String _defaultManifest() {
  var dir = Directory.current;
  while (true) {
    final candidate = File('${dir.path}/deploy/instance.yaml');
    if (candidate.existsSync()) return candidate.path;
    if (dir.parent.path == dir.path) return 'deploy/instance.yaml';
    dir = dir.parent;
  }
}

void _report(String manifest, List<String> errors, List<String> warnings) {
  for (final w in warnings) {
    stderr.writeln('$manifest: warning: $w');
  }
  for (final e in errors) {
    stderr.writeln('$manifest: error: $e');
  }
}

Never _die(String message, int code) {
  stderr.writeln(message);
  exit(code);
}
