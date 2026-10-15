const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const test = require('node:test');
const { searchSkills, installSkill } = require('../../.github/skills/git-ape-skills/scripts/skills');
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
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'git-ape-test-'));
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
