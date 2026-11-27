// Only the latest push run for the exact source commit can authorize release.
function latestRun(runs, path, branch) {
  return runs
    .filter(run => run.path.split('@')[0] === path && run.event === 'push' && run.head_branch === branch)
    .sort((a, b) => b.id - a.id || b.run_attempt - a.run_attempt)[0];
}

function decision(runs, paths, branch) {
  const selected = paths.map(path => latestRun(runs, path, branch));
  if (selected.some(run => run?.status === 'completed' && run.conclusion !== 'success')) {
    return 'blocked';
  }
  return selected.every(run => run?.status === 'completed' && run.conclusion === 'success')
    ? 'ready' : 'waiting';
}

// The pushed commit's verification (Check & Test and Validation) runs in
// pull-request.yml; release.yml calls this after its own web build succeeded.
const PATHS = ['.github/workflows/pull-request.yml'];

async function evaluate({github, context, core, sha = context.sha, branch = context.ref.replace('refs/heads/', '')}) {
  // Android integration can take an hour after smoke testing finishes.
  const deadline = Date.now() + 110 * 60 * 1000;
  while (Date.now() < deadline) {
    const runs = await github.paginate(github.rest.actions.listWorkflowRunsForRepo, {
      ...context.repo, head_sha: sha, event: 'push', per_page: 100,
    });
    const state = decision(runs, PATHS, branch);
    if (state === 'blocked') {
      core.setFailed('A required check failed for the source commit; release blocked.');
      return;
    }
    if (state === 'ready') {
      core.setOutput('release_web', 'true');
      return;
    }
    core.info('Waiting for CI and Validation on ' + sha);
    await new Promise(resolve => setTimeout(resolve, 30000));
  }
  core.setFailed('Timed out waiting for CI and Validation; release blocked.');
}

module.exports = {PATHS, decision, evaluate};
