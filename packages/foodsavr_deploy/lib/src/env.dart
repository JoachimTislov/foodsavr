import 'deployment.dart';

enum EnvFormat { dotenv, github, tfvars }

/// Suffix for per-environment GitHub Actions variables: production uses the
/// plain names (`GCP_DEPLOY_SERVICE_ACCOUNT`), others `_STAGING` etc.
String varSuffix(String flavor) =>
    flavor == 'production' ? '' : '_${flavor.toUpperCase()}';

/// Instance identity and environment config as key/value pairs: the
/// bootstrap seam that replaces hard-coded project ids in scripts.
Map<String, String> envValues(Deployment d) {
  final id = d.identity;
  final env = d.environment;
  final fb = d.firebase;
  final budget = d.current.budget;
  // Shared projects: the environment listed in sharedWith owns the infra.
  final owner = env.sharedWith.isEmpty ? env.name : env.sharedWith.first;
  return {
    'FLAVOR': d.flavor,
    'INSTANCE_NAME': id.name,
    'DEPLOYMENT_LEVEL': d.currentLevel,
    'EMULATOR': '${env.emulator}',
    'GITHUB_REPOSITORY': id.githubRepository,
    'GH_ENVIRONMENT': ?env.githubEnvironment,
    'VAR_SUFFIX': varSuffix(d.flavor),
    'INFRA_OWNER': owner,
    'REGION': id.region,
    if (fb != null) ...{
      'PROJECT_ID': fb.projectId,
      'WEB_APP_ID': fb.webAppId,
      'WEB_API_KEY_ID': ?fb.webApiKeyId,
      'SITE_ID': fb.siteId,
      'TF_STATE_BUCKET': '${fb.projectId}-tfstate',
      // Production keeps the original prefix so existing state stays put.
      'TF_STATE_PREFIX': d.flavor == 'production'
          ? 'firebase'
          : 'firebase-${d.flavor}',
    },
    if (budget != null) 'MONTHLY_BUDGET_USD': '${budget.monthlyUsd}',
  };
}

/// Terraform variables for infra/terraform.
Map<String, Object> tfVars(Deployment d) {
  final fb = d.firebase;
  final budget = d.current.budget;
  return {
    'level': d.currentLevel,
    if (d.current.provider == 'firebase') 'firebase_plan': d.current.plan,
    'region': d.identity.region,
    'github_repository': d.identity.githubRepository,
    if (fb != null) ...{
      'project_id': fb.projectId,
      'web_app_id': fb.webAppId,
      'web_api_key_id': ?fb.webApiKeyId,
    },
    if (budget != null) 'monthly_budget_usd': budget.monthlyUsd,
  };
}

String renderEnv(Deployment d, EnvFormat format) {
  final b = StringBuffer();
  switch (format) {
    case EnvFormat.dotenv:
      // Single-quoted: valid dotenv and safe to `source` from bash.
      envValues(d).forEach((k, v) {
        b.writeln("$k='${v.replaceAll("'", r"'\''")}'");
      });
    case EnvFormat.github:
      // For $GITHUB_ENV / $GITHUB_OUTPUT; GITHUB_* names are reserved there.
      envValues(d).forEach((k, v) {
        if (!k.startsWith('GITHUB_')) b.writeln('$k=$v');
      });
    case EnvFormat.tfvars:
      tfVars(d).forEach((k, v) {
        final value = v is num
            ? '$v'
            : '"${'$v'.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll(r'${', r'$${')}"';
        b.writeln('$k = $value');
      });
  }
  return b.toString();
}
