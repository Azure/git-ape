const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const workflow = fs.readFileSync(path.join(__dirname, '../../.github/workflows/git-ape-deck-build.yml'), 'utf8');
const prStep = workflow.slice(workflow.indexOf('          # Open or update PR (idempotent)'))
  .split('\n').map((line) => line.slice(10)).join('\n');

function runPrStep(t, { existing = '', status = 0, message = '' } = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'git-ape-deck-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const body = path.join(root, 'body');
  const summary = path.join(root, 'summary');
  fs.writeFileSync(body, 'Deck review body\nCloses #123\n');
  const result = spawnSync('bash', ['-c', `
    set -euo pipefail
    gh() {
      case "$1 $2" in
        "pr list") printf '%s' "$EXISTING" ;;
        "pr create") printf '%s' "$MESSAGE" >&2; return "$STATUS" ;;
        "pr edit") echo "edited PR $3"; return "$STATUS" ;;
        *) return 99 ;;
      esac
    }
    ${prStep}
  `], {
    encoding: 'utf8',
    env: {
      ...process.env,
      AUTO_BRANCH: 'auto/deck-rebuild',
      REPO: 'Azure/git-ape',
      ONLY: '',
      BODY_FILE: body,
      GITHUB_STEP_SUMMARY: summary,
      EXISTING: existing,
      STATUS: String(status),
      MESSAGE: message,
    },
  });
  return { ...result, summary: fs.existsSync(summary) ? fs.readFileSync(summary, 'utf8') : '' };
}

test('successful PR creation does not require a manual fallback', (t) => {
  const result = runPrStep(t, { message: 'https://github.com/Azure/git-ape/pull/123' });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /https:\/\/github.com\/Azure\/git-ape\/pull\/123/);
  assert.equal(result.summary, '');
});

test('repository policy denial produces a warning and actionable summary', (t) => {
  const result = runPrStep(t, {
    status: 1,
    message: 'pull request create failed: GraphQL: GitHub Actions is not permitted to create or approve pull requests (createPullRequest)',
  });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /::warning::Repository policy blocks automatic PR creation/);
  assert.match(result.summary, /https:\/\/github.com\/Azure\/git-ape\/compare\/main\.\.\.auto\/deck-rebuild\?expand=1/);
  assert.match(result.summary, /Allow GitHub Actions to create and approve pull requests/);
  assert.match(result.summary, /Deck review body\nCloses #123/);
});

test('unrelated PR creation errors still fail with the original exit code', (t) => {
  const result = runPrStep(t, { status: 4, message: 'authentication failed' });
  assert.equal(result.status, 4);
  assert.match(result.stderr, /authentication failed/);
  assert.equal(result.summary, '');
});

test('an existing PR is updated without creating a manual fallback', (t) => {
  const result = runPrStep(t, { existing: '123' });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /edited PR 123/);
  assert.doesNotMatch(result.stdout, /Opening new PR/);
  assert.equal(result.summary, '');
});

test('existing PR update failures remain fatal', (t) => {
  const result = runPrStep(t, { existing: '123', status: 1 });
  assert.equal(result.status, 1);
  assert.equal(result.summary, '');
});
