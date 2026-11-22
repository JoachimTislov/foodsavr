// Only the latest push run for the exact source commit can authorize release.
function latestRun(runs, path) {
  return runs
    .filter(run => run.path === path && run.event === 'push' && run.head_branch === 'main')
    .sort((a, b) => b.id - a.id || b.run_attempt - a.run_attempt)[0];
}

function decision(runs, paths) {
  const selected = paths.map(path => latestRun(runs, path));
  if (selected.some(run => run?.status === 'completed' && run.conclusion !== 'success')) {
    return 'blocked';
  }
  return selected.every(run => run?.status === 'completed' && run.conclusion === 'success')
    ? 'ready' : 'waiting';
}

async function evaluate({github, context, core}) {
  const trigger = context.payload.workflow_run;
  const android = trigger.name === 'Android Build';
  const paths = ['.github/workflows/ci-checks.yml', '.github/workflows/validation.yml',
    android ? '.github/workflows/build-android.yml' : '.github/workflows/build-web.yml'];
  // Android integration can take an hour after smoke testing finishes.
  const deadline = Date.now() + 110 * 60 * 1000;
  while (Date.now() < deadline) {
    const runs = await github.paginate(github.rest.actions.listWorkflowRunsForRepo, {
      ...context.repo, head_sha: trigger.head_sha, event: 'push', per_page: 100,
    });
    const state = decision(runs, paths);
    if (state === 'blocked') {
      core.setFailed('A required check failed for the source commit; release blocked.');
      return;
    }
    if (state === 'ready') {
      core.setOutput('release_android', String(android));
      core.setOutput('release_web', String(!android));
      return;
    }
    core.info('Waiting for CI and Validation on ' + trigger.head_sha);
    await new Promise(resolve => setTimeout(resolve, 30000));
  }
  core.setFailed('Timed out waiting for CI and Validation; release blocked.');
}

module.exports = {decision, evaluate};
