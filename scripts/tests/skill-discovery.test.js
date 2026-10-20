const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const { searchSkills, planSkill, installSkill } = require('../../.github/skills/git-ape-skills/scripts/skills');
const { buildSkillRegistry } = require('../generate-docs');

const REVISION = 'a'.repeat(40);
const community = {
  name: 'aws-example', tier: 'community', description: 'AWS deployment example',
  author: 'Example Author', path: '.github/community-skills/aws-example', bundled: false,
};
const registry = { skills: [
  { name: 'azure-example', tier: 'first-party', description: 'Azure example', bundled: true },
  community,
] };

function workspace(t) {
  const root = fs.mkdtempSync(path.join(__dirname, '.git-ape-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  return root;
}

function mockApi({ unsafeEntry, failBlob = false } = {}) {
  const blobs = new Map();
  const tree = ['SKILL.md', 'scripts/check.js', 'references/example.md'].map((file) => {
    const content = Buffer.from(`fixture ${file}`);
    const sha = crypto.createHash('sha1').update(`blob ${content.length}\0`).update(content).digest('hex');
    blobs.set(sha, { encoding: 'base64', content: content.toString('base64') });
    return { path: `${community.path}/${file}`, type: 'blob', mode: '100644', sha };
  });
  if (unsafeEntry) tree.push(unsafeEntry);
  const calls = [];
  const api = (endpoint) => {
    calls.push(endpoint);
    if (endpoint === 'commits/main') return { sha: REVISION };
    if (endpoint === `contents/.github/skills/registry.json?ref=${REVISION}`) {
      return { encoding: 'base64', content: Buffer.from(JSON.stringify(registry)).toString('base64') };
    }
    if (endpoint === `git/trees/${REVISION}?recursive=1`) return { tree, truncated: false };
    if (endpoint.startsWith('git/blobs/')) {
      if (failBlob) throw new Error('Network failure');
      return blobs.get(endpoint.slice('git/blobs/'.length));
    }
    throw new Error(`Unexpected API request: ${endpoint}`);
  };
  return { api, calls };
}

test('AWS search returns an opt-in community result without changing the workspace', (t) => {
  const root = workspace(t);
  assert.deepEqual(searchSkills(registry, 'AWS'), [community]);
  assert.equal(community.bundled, false);
  assert.deepEqual(fs.readdirSync(root), []);
});

test('generator records community discovery metadata outside core and marks it unbundled', () => {
  const generated = buildSkillRegistry([
    { ...community, slug: community.name, dir: community.name },
    { name: 'azure-example', tier: 'first-party', slug: 'azure-example', dir: 'azure-example' },
  ]);
  const match = searchSkills(generated, 'aws')[0];
  assert.equal(match.path, '.github/community-skills/aws-example');
  assert.equal(match.bundled, false);
  assert.equal(generated.skills.find((skill) => skill.tier === 'first-party').bundled, true);
  assert.throws(() => buildSkillRegistry([
    { ...community, slug: community.name, dir: community.name },
    { ...community, tier: 'first-party' },
  ]), /unique names/);
});

test('install copies supporting files from one pinned Git-Ape commit and records provenance', (t) => {
  const root = workspace(t);
  const { api, calls } = mockApi();
  const result = installSkill('aws-example', root, { api, approved: true });
  assert.equal(result.revision, REVISION);
  assert.ok(fs.existsSync(path.join(result.destination, 'SKILL.md')));
  assert.ok(fs.existsSync(path.join(result.destination, 'scripts', 'check.js')));
  assert.ok(fs.existsSync(path.join(result.destination, 'references', 'example.md')));
  const provenance = JSON.parse(fs.readFileSync(path.join(result.destination, '.git-ape-provenance.json')));
  assert.equal(provenance.repository, 'Azure/git-ape');
  assert.equal(provenance.revision, REVISION);
  assert.ok(calls.includes(`git/trees/${REVISION}?recursive=1`));
});

test('install refuses unapproved requests, traversal names, core skills, and overwrites', (t) => {
  const root = workspace(t);
  const { api } = mockApi();
  assert.throws(() => installSkill('aws-example', root, { api }), /explicit approval/);
  assert.throws(() => installSkill('../escape', root, { api, approved: true }), /kebab-case/);
  assert.throws(() => installSkill('aws-example', root, { api, approved: true, revision: 'main' }), /commit SHA/);
  assert.throws(() => installSkill('azure-example', root, { api, approved: true }), /No installable/);
  fs.mkdirSync(path.join(root, '.github', 'skills', 'aws-example'), { recursive: true });
  assert.throws(() => installSkill('aws-example', root, { api, approved: true }), /overwrite/);
});

test('install rejects symlinks, traversal, and truncated trees', (t) => {
  const root = workspace(t);
  for (const entry of [
    { path: `${community.path}/evil`, type: 'blob', mode: '120000', sha: 'b'.repeat(40) },
    { path: `${community.path}/../evil`, type: 'blob', mode: '100644', sha: 'b'.repeat(40) },
  ]) {
    const { api } = mockApi({ unsafeEntry: entry });
    assert.throws(() => installSkill('aws-example', root, { api, approved: true }), /unsafe skill file/);
  }
  const { api } = mockApi();
  assert.throws(() => installSkill('aws-example', root, {
    approved: true,
    api: (endpoint) => endpoint.startsWith('git/trees/')
      ? { tree: [], truncated: true } : api(endpoint),
  }), /incomplete source tree/);
  assert.equal(fs.existsSync(path.join(root, '.github')), false);
});

test('failed download leaves no installed skill', (t) => {
  const root = workspace(t);
  const { api } = mockApi({ failBlob: true });
  assert.throws(() => installSkill('aws-example', root, { api, approved: true }), /Network failure/);
  assert.equal(fs.existsSync(path.join(root, '.github')), false);
});

test('corrupt blob data fails integrity checks without writing the destination', (t) => {
  const root = workspace(t);
  const { api } = mockApi();
  assert.throws(() => installSkill('aws-example', root, {
    approved: true,
    api: (endpoint) => endpoint.startsWith('git/blobs/')
      ? { encoding: 'base64', content: Buffer.from('corrupt').toString('base64') }
      : api(endpoint),
  }), /integrity check/);
  assert.equal(fs.existsSync(path.join(root, '.github')), false);
});

test('core plugin and VSIX do not expose community source as executable skills', () => {
  const root = path.resolve(__dirname, '..', '..');
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'plugin.json')));
  assert.equal(manifest.skills, '.github/skills/');
  assert.equal(fs.existsSync(path.join(root, '.github', 'skills', 'community')), false);
  const extension = JSON.parse(fs.readFileSync(path.join(root, 'extension', 'package.template.json')));
  assert.ok(extension.contributes.chatSkills.some((skill) => skill.path.includes('/git-ape-skills/')));
  assert.ok(extension.contributes.chatSkills.every((skill) => !skill.path.includes('community-skills')));
  assert.match(fs.readFileSync(path.join(root, 'extension', '.vscodeignore'), 'utf8'),
    /^\.github\/community-skills\/\*\*$/m);
});

test('single preview defaults to workspace, supports explicit workspace, and requires an existing project', (t) => {
  const root = workspace(t);
  const { api } = mockApi();
  const implicit = planSkill(community.name, root, { api });
  assert.deepEqual(planSkill(community.name, root, { api, scope: 'workspace' }), implicit);
  assert.equal(implicit.scope, 'workspace');
  assert.equal(implicit.destinationRoot, path.join(root, '.github', 'skills'));
  assert.equal(implicit.members[0].destination, path.join(implicit.destinationRoot, community.name));
  assert.deepEqual(fs.readdirSync(root), []);
  const offline = () => { throw new Error('Unexpected network'); };
  assert.throws(() => planSkill(community.name, undefined, { api: offline }), /requires --workspace/);
  assert.throws(() => planSkill(community.name, path.join(root, 'missing'), { api: offline }), /Workspace does not exist/);
  assert.throws(() => installSkill(community.name, path.join(root, 'missing'), {
    api: offline, approved: true,
  }), /Workspace does not exist/);
});

test('personal single preview uses os.homedir without a project and makes no writes to a missing root', (t) => {
  const home = workspace(t);
  t.mock.method(os, 'homedir', () => home);
  const { api, calls } = mockApi();
  const result = planSkill(community.name, undefined, { scope: 'personal', api });
  assert.equal(result.scope, 'personal');
  assert.equal(result.destinationRoot, path.join(home, '.copilot', 'skills'));
  const member = result.members[0];
  assert.equal(member.destination, path.join(result.destinationRoot, community.name));
  assert.equal(member.files.length, 3);
  assert.equal(member.files[0].destination, path.join(member.destination, 'SKILL.md'));
  assert.equal(member.provenanceFile, path.join(member.destination, '.git-ape-provenance.json'));
  assert.equal(calls.some((call) => call.startsWith('git/blobs/')), false);
  assert.deepEqual(fs.readdirSync(home), []);
});

test('personal single installation creates its root only after approval and records scope and destination', (t) => {
  const home = workspace(t);
  const options = { scope: 'personal', homedir: () => home, ...mockApi() };
  assert.throws(() => installSkill(community.name, undefined, options), /explicit approval/);
  assert.deepEqual(fs.readdirSync(home), []);
  const result = installSkill(community.name, undefined, { ...options, approved: true, revision: REVISION });
  assert.equal(result.scope, 'personal');
  assert.equal(result.destinationRoot, path.join(home, '.copilot', 'skills'));
  assert.equal(result.destination, path.join(result.destinationRoot, community.name));
  assert.ok(fs.existsSync(path.join(result.destination, 'scripts', 'check.js')));
  const provenance = JSON.parse(fs.readFileSync(path.join(result.destination, '.git-ape-provenance.json')));
  assert.equal(provenance.scope, 'personal');
  assert.equal(provenance.destination, result.destination);
  assert.equal(provenance.revision, REVISION);
  assert.deepEqual(fs.readdirSync(result.destinationRoot), [community.name]);
  assert.throws(() => installSkill(community.name, undefined, { ...options, approved: true }), /overwrite/);
});

test('scope validation rejects invalid and ambiguous single targets before network access or writes', (t) => {
  const home = workspace(t);
  const api = () => { throw new Error('Unexpected network'); };
  for (const action of [planSkill, installSkill]) {
    for (const scope of ['', 'global', 'PERSONAL', null]) {
      assert.throws(() => action(community.name, home, { scope, api, approved: true }), /Scope must be/);
    }
    for (const project of [home, '']) {
      assert.throws(() => action(community.name, project, {
        scope: 'personal', homedir: () => home, api, approved: true,
      }), /cannot be combined/);
    }
  }
  assert.deepEqual(fs.readdirSync(home), []);
});

test('CLI parses scope for previews and installs and rejects bad options without networking', (t) => {
  const home = workspace(t);
  const helper = path.resolve(__dirname, '../../.github/skills/git-ape-skills/scripts/skills.js');
  for (const command of ['plan', 'install', 'plan-pack', 'install-pack']) {
    const approval = command.startsWith('install') ? ['--yes', '--revision', REVISION] : [];
    for (const [options, message] of [
      [['--scope', 'personal', '--workspace', home], /cannot be combined/],
      [['--scope', 'global'], /Scope must be/],
      [['--scope', 'personal', '--scope', 'workspace', '--workspace', home], /--scope must only be specified once/],
      [['--scope', 'workspace'], /requires --workspace/],
      [[], /requires --workspace/],
      [['--scope'], /--scope requires a value/],
    ]) {
      const result = spawnSync(process.execPath, [helper, command, community.name, ...options, ...approval], {
        encoding: 'utf8', env: { ...process.env, HOME: home, USERPROFILE: home },
      });
      assert.equal(result.status, 1, result.stderr);
      assert.match(result.stderr, message);
    }
  }
  assert.deepEqual(fs.readdirSync(home), []);
});

test('personal single download failure cleans staging without installing files', (t) => {
  const home = workspace(t);
  const root = path.join(home, '.copilot', 'skills');
  assert.throws(() => installSkill(community.name, undefined, {
    scope: 'personal', homedir: () => home, approved: true, ...mockApi({ failBlob: true }),
  }), /Network failure/);
  assert.deepEqual(fs.readdirSync(root), []);
});

test('personal root and parent symlinks, files and case collisions are rejected', (t) => {
  for (const obstacle of ['symlink', 'file', 'case']) {
    const home = workspace(t);
    const parent = path.join(home, '.copilot');
    if (obstacle === 'symlink') {
      const outside = path.join(home, 'outside');
      fs.mkdirSync(outside);
      fs.symlinkSync(outside, parent, process.platform === 'win32' ? 'junction' : 'dir');
    } else if (obstacle === 'file') fs.writeFileSync(parent, 'keep');
    else fs.mkdirSync(path.join(home, '.Copilot'));
    const api = () => { throw new Error('Unexpected network'); };
    for (const action of [planSkill, installSkill]) {
      assert.throws(() => action(community.name, undefined, {
        scope: 'personal', homedir: () => home, api, approved: true,
      }), /real directories|Case collision/);
    }
    if (obstacle === 'symlink') fs.unlinkSync(parent);
  }
});
