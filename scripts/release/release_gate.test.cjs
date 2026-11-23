const {test} = require('node:test');
const assert = require('node:assert/strict');
const {decision} = require('./release_gate.cjs');
const paths = ['ci', 'validation', 'android'];
const run = (path, extra = {}) => ({
  path, id: 1, run_attempt: 1, event: 'push', head_branch: 'stable',
  status: 'completed', conclusion: 'success', ...extra,
});

test('requires every check, including validation', () => {
  assert.equal(decision(paths.map(path => run(path)), paths), 'ready');
  assert.equal(decision([run('ci'), run('android')], paths), 'waiting');
});
test('does not use PR or non-release checks to authorize a release', () => {
  assert.equal(decision(paths.map(path => run(path, {event: 'pull_request'})), paths), 'waiting');
  assert.equal(decision(paths.map(path => run(path, {head_branch: 'feature'})), paths), 'waiting');
});
test('failed, cancelled and skipped checks block release', () => {
  for (const conclusion of ['failure', 'cancelled', 'skipped', 'timed_out']) {
    assert.equal(decision([run('ci'), run('android'), run('validation', {conclusion})], paths), 'blocked');
  }
});
test('newer failing or pending runs supersede earlier successes', () => {
  const runs = paths.map(path => run(path));
  assert.equal(decision([...runs, run('validation', {id: 2, conclusion: 'failure'})], paths), 'blocked');
  assert.equal(decision([...runs, run('validation', {run_attempt: 2, status: 'in_progress', conclusion: null})], paths), 'waiting');
});
