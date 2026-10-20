const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const test = require('node:test');
const { validatePacks, searchSkills, planPack, installPack } = require('../../.github/skills/git-ape-skills/scripts/skills');
const { buildSkillRegistry, loadPackManifests, renderPackCatalog } = require('../generate-docs');

const revision = 'a'.repeat(40);
const pack = { name: 'example-pack', description: 'Cloud deployment toolkit', author: 'Example Author', skills: ['member-one', 'member-two'] };
const skills = pack.skills.map((name) => ({ name, tier: 'community', path: `.github/community-skills/${name}` }));
const registry = { skills, packs: [pack] };

function directory(t) {
  const root = fs.mkdtempSync(path.join(__dirname, '.pack-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  return root;
}

function fixture({ catalog = registry, manifest = pack, modifyTree = (tree) => tree, blobResponse, beforeBlob } = {}) {
  const blobs = new Map();
  const tree = skills.flatMap((skill) => ['SKILL.md', 'scripts/check.js', 'references/info.md'].map((file) => {
    const content = Buffer.from(`${skill.name} ${file}`);
    const sha = crypto.createHash('sha1').update(`blob ${content.length}\0`).update(content).digest('hex');
    blobs.set(sha, { encoding: 'base64', content: content.toString('base64') });
    return { path: `${skill.path}/${file}`, type: 'blob', mode: '100644', sha };
  }));
  const manifestContent = Buffer.from(typeof manifest === 'string' ? manifest : JSON.stringify(manifest));
  const manifestSha = crypto.createHash('sha1').update(`blob ${manifestContent.length}\0`).update(manifestContent).digest('hex');
  blobs.set(manifestSha, { encoding: 'base64', content: manifestContent.toString('base64') });
  tree.push({ path: `.github/skill-packs/${pack.name}/pack.json`, type: 'blob', mode: '100644', sha: manifestSha });
  const calls = [];
  const api = (endpoint) => {
    calls.push(endpoint);
    if (endpoint === 'commits/main') return { sha: revision };
    if (endpoint === `contents/.github/skills/registry.json?ref=${revision}`) {
      return { encoding: 'base64', content: Buffer.from(JSON.stringify(catalog)).toString('base64') };
    }
    if (endpoint === `git/trees/${revision}?recursive=1`) return { tree: modifyTree(tree), truncated: false };
    if (endpoint.startsWith('git/blobs/')) {
      beforeBlob?.(calls.filter((call) => call.startsWith('git/blobs/')).length);
      return blobResponse ? blobResponse(endpoint, blobs) : blobs.get(endpoint.slice('git/blobs/'.length));
    }
    throw new Error(`Unexpected request: ${endpoint}`);
  };
  return { api, calls };
}

function install(root, options = {}) {
  return installPack(pack.name, root, { approved: true, revision, ...fixture(), ...options });
}

test('pack validation rejects malformed metadata, names, membership and duplicates', () => {
  for (const bad of [
    null, [], {}, { ...pack, name: '../pack' }, { ...pack, name: 'CON' },
    { ...pack, name: 'a'.repeat(101) }, { ...pack, name: 'not_portable' },
    { ...pack, description: '' }, { ...pack, author: '  ' }, { ...pack, author: 7 },
    { ...pack, description: 'line\nbreak' }, { ...pack, extra: true }, { ...pack, skills: [] },
    { ...pack, skills: 'member-one' }, { ...pack, skills: ['member-one', 'member-one'] },
    { ...pack, skills: ['missing'] }, { ...pack, skills: ['../member'] },
  ]) assert.throws(() => validatePacks([bad], skills));
  assert.throws(() => validatePacks([pack, pack], skills), /Duplicate pack name/);
  assert.throws(() => validatePacks([pack], skills.map((skill) => ({ ...skill, tier: 'first-party' }))), /community skill/);
  assert.throws(() => validatePacks([pack], [...skills, skills[0]]), /one community skill/);
  assert.throws(() => validatePacks({}, skills), /Malformed/);
  assert.deepEqual(validatePacks([pack], skills), [pack]);
});

test('search includes packs by name, description, author and member without changing skill results', () => {
  for (const query of ['example-pack', 'toolkit', 'Example Author', 'member-one']) {
    assert.ok(searchSkills(registry, query).some((match) => match.kind === 'pack' && match.name === pack.name));
  }
  assert.deepEqual(searchSkills({ skills }, 'member-one'), [skills[0]]);
  assert.deepEqual(searchSkills({ skills }, ''), skills);
  assert.deepEqual(buildSkillRegistry(skills).packs, []);
  assert.deepEqual(buildSkillRegistry(skills, [pack]).packs, [pack]);
  const catalog = renderPackCatalog(buildSkillRegistry(skills, [pack]).packs);
  assert.match(catalog, /## example-pack/);
  assert.match(catalog, /Example Author/);
  assert.match(catalog, /\[member-one\]\(\.\/community\/member-one\)/);
  assert.match(catalog, /\[member-two\]\(\.\/community\/member-two\)/);
  assert.match(renderPackCatalog([]), /No packs have been contributed/);
});

test('manifest loading enforces directory/name, metadata schema, JSON and membership', (t) => {
  const root = directory(t);
  assert.deepEqual(loadPackManifests(path.join(root, 'absent'), skills), []);
  const folder = path.join(root, pack.name);
  fs.mkdirSync(folder);
  const file = path.join(folder, 'pack.json');
  assert.throws(() => loadPackManifests(root, skills), /pack.json/);
  for (const value of ['{', JSON.stringify({ ...pack, name: 'other-pack' }), JSON.stringify({ ...pack, extra: true }), JSON.stringify({ ...pack, skills: ['missing'] })]) {
    fs.writeFileSync(file, value);
    assert.throws(() => loadPackManifests(root, skills));
  }
  fs.writeFileSync(file, JSON.stringify(pack));
  assert.deepEqual(loadPackManifests(root, skills), [pack]);
});

test('preview resolves one commit, exposes exact files and destinations and makes no writes', (t) => {
  const root = directory(t);
  const { api, calls } = fixture();
  const result = planPack(pack.name, root, { api });
  assert.equal(result.revision, revision);
  assert.deepEqual(result.pack, pack);
  assert.deepEqual(result.conflicts, []);
  assert.equal(result.members.length, 2);
  assert.equal(result.members[0].files.length, 3);
  assert.equal(result.members[0].files[0].path, 'SKILL.md');
  assert.equal(result.members[0].files[0].destination, path.join(root, '.github', 'skills', 'member-one', 'SKILL.md'));
  assert.match(result.members[0].files[0].sha, /^[a-f0-9]{40}$/);
  assert.equal(calls.filter((call) => call === 'commits/main').length, 1);
  assert.equal(calls.filter((call) => call.startsWith('git/blobs/')).length, 1); // Pinned manifest only.
  assert.deepEqual(fs.readdirSync(root), []);
});

test('successful installation stages all files before final writes and records member pack provenance', (t) => {
  const root = directory(t);
  const { api, calls } = fixture({
    beforeBlob: () => assert.equal(fs.existsSync(path.join(root, '.github')), false),
  });
  const result = install(root, { api });
  assert.equal(result.revision, revision);
  assert.deepEqual(result.destinations, skills.map((skill) => path.join(root, '.github', 'skills', skill.name)));
  for (const [index, destination] of result.destinations.entries()) {
    assert.ok(fs.existsSync(path.join(destination, 'scripts', 'check.js')));
    assert.ok(fs.existsSync(path.join(destination, 'references', 'info.md')));
    const provenance = JSON.parse(fs.readFileSync(path.join(destination, '.git-ape-provenance.json')));
    assert.deepEqual(provenance, {
      repository: 'Azure/git-ape', revision, skill: skills[index].name, sourcePath: skills[index].path,
      scope: 'workspace', destination,
      pack: pack.name, packSourcePath: `.github/skill-packs/${pack.name}/pack.json`,
    });
  }
  assert.equal(calls.includes('commits/main'), false);
  assert.equal(calls.filter((call) => call.startsWith('git/trees/')).length, 1);
  assert.deepEqual(fs.readdirSync(root), ['.github']);
});

test('install requires approval and an explicit pinned SHA before accessing network', (t) => {
  const root = directory(t);
  const api = () => { throw new Error('Network should not be used'); };
  assert.throws(() => installPack(pack.name, root, { api, revision }), /explicit approval/);
  for (const invalid of [undefined, '', 'main', 'a'.repeat(39), 'A'.repeat(40)]) {
    assert.throws(() => install(root, { api, revision: invalid }), /pinned full/);
  }
  assert.deepEqual(fs.readdirSync(root), []);
});

test('old registries, missing packs, member source paths and registry errors fail without writes', (t) => {
  const root = directory(t);
  for (const catalog of [
    { skills }, { ...registry, packs: [] }, { ...registry, packs: null },
    { ...registry, skills: [] }, { ...registry, skills: [{ ...skills[0], path: '../unsafe' }, skills[1]] },
  ]) {
    assert.throws(() => install(root, fixture({ catalog })));
    assert.deepEqual(fs.readdirSync(root), []);
  }
});

test('pinned source manifest must exist, validate, and match the registry', (t) => {
  const root = directory(t);
  for (const manifest of ['{', { ...pack, skills: [] }, { ...pack, description: 'stale catalog' }]) {
    assert.throws(() => install(root, fixture({ manifest })));
  }
  assert.throws(() => install(root, fixture({
    modifyTree: (tree) => tree.filter((entry) => !entry.path.endsWith('/pack.json')),
  })), /Missing or unsafe pack manifest/);
  assert.throws(() => install(root, fixture({
    modifyTree: (tree) => tree.map((entry) => entry.path.endsWith('/pack.json') ? { ...entry, mode: '120000' } : entry),
  })), /Missing or unsafe pack manifest/);
  assert.deepEqual(fs.readdirSync(root), []);
});

test('preflight rejects incomplete trees, missing SKILL.md, unsafe paths, symlinks and case/file collisions', (t) => {
  const root = directory(t);
  const base = `${skills[1].path}/`;
  for (const relative of ['../escape', '/absolute', 'scripts\\evil', '.git/config', 'NUL.txt', 'trailing.', 'colon:file', '.git-ape-provenance.json/child', 'SKILL.MD', 'Scripts/other.js', 'scripts']) {
    const { api } = fixture({
      modifyTree: (tree) => [...tree, { ...tree[0], path: base + relative }],
    });
    assert.throws(() => install(root, { api }), /unsafe skill file/);
  }
  for (const mode of ['120000', '160000']) {
    const { api } = fixture({ modifyTree: (tree) => [...tree, { ...tree[0], path: base + 'link', mode }] });
    assert.throws(() => install(root, { api }), /unsafe skill file/);
  }
  const { api } = fixture({ modifyTree: (tree) => tree.filter((entry) => entry.path !== base + 'SKILL.md') });
  assert.throws(() => install(root, { api }), /missing SKILL.md/);
  const complete = fixture();
  assert.throws(() => install(root, { api: (endpoint) => endpoint.startsWith('git/trees/')
    ? { tree: [], truncated: true } : complete.api(endpoint) }), /incomplete source tree/);
  assert.deepEqual(fs.readdirSync(root), []);
});

test('all member destinations preflight before downloads and preview reports conflicts', (t) => {
  const root = directory(t);
  const existing = path.join(root, '.github', 'skills', 'member-two');
  fs.mkdirSync(existing, { recursive: true });
  fs.writeFileSync(path.join(existing, 'keep'), 'untouched');
  const { api, calls } = fixture();
  const plan = planPack(pack.name, root, { api, revision });
  assert.match(plan.conflicts.join(), /overwrite/);
  assert.throws(() => install(root, { api }), /overwrite/);
  assert.equal(calls.filter((call) => call.startsWith('git/blobs/')).length, 2); // Each invocation verifies only the manifest.
  assert.equal(fs.existsSync(path.join(root, '.github', 'skills', 'member-one')), false);
  assert.equal(fs.readFileSync(path.join(existing, 'keep'), 'utf8'), 'untouched');
});

test('destination case collisions, non-directory parents and dangling symlinks are not overwritten', (t) => {
  const root = directory(t);
  const parent = path.join(root, '.github', 'skills');
  fs.mkdirSync(parent, { recursive: true });
  fs.mkdirSync(path.join(parent, 'Member-One'));
  assert.throws(() => install(root), /collision|overwrite/);
  fs.rmdirSync(path.join(parent, 'Member-One'));
  fs.writeFileSync(path.join(parent, 'member-one'), 'keep');
  assert.throws(() => install(root), /overwrite/);
  fs.unlinkSync(path.join(parent, 'member-one'));
  const destination = path.join(parent, 'member-one');
  // Directory junctions can be created on Windows without symlink privileges.
  fs.symlinkSync(path.join(root, 'missing-target'), destination, process.platform === 'win32' ? 'junction' : 'dir');
  assert.throws(() => install(root), /overwrite/);
  fs.unlinkSync(destination);
  fs.rmdirSync(parent);
  fs.writeFileSync(parent, 'not a directory');
  assert.throws(() => install(root), /real directories/);
});

test('corrupt, missing and failed later downloads leave no final writes or staging', (t) => {
  for (const outcome of ['corrupt', 'missing', 'network']) {
    const root = directory(t);
    let count = 0;
    const { api } = fixture({
      blobResponse: (endpoint, blobs) => {
        if (++count < 5) return blobs.get(endpoint.slice('git/blobs/'.length));
        if (outcome === 'network') throw new Error('Network failure');
        if (outcome === 'missing') return undefined;
        return { encoding: 'base64', content: Buffer.from('corrupt').toString('base64') };
      },
    });
    assert.throws(() => install(root, { api }), /integrity|Invalid blob|Network failure/);
    assert.deepEqual(fs.readdirSync(root), []);
  }
});

test('destination introduced during downloads is preserved and prevents all final writes', (t) => {
  const root = directory(t);
  const destination = path.join(root, '.github', 'skills', 'member-two');
  const { api } = fixture({
    beforeBlob: (count) => { if (count === 6) fs.mkdirSync(destination, { recursive: true }); },
  });
  assert.throws(() => install(root, { api }), /overwrite/);
  assert.ok(fs.existsSync(destination));
  assert.equal(fs.existsSync(path.join(path.dirname(destination), 'member-one')), false);
  assert.equal(fs.readdirSync(root).some((entry) => entry.startsWith('.git-ape-stage-')), false);
});

test('final-copy failure rolls back only owned member directories', (t) => {
  const root = directory(t);
  const unrelated = path.join(root, '.github', 'skills', 'unrelated');
  fs.mkdirSync(unrelated, { recursive: true });
  fs.writeFileSync(path.join(unrelated, 'keep'), 'keep');
  const original = fs.cpSync;
  let copies = 0;
  t.mock.method(fs, 'cpSync', (...args) => {
    if (++copies === 2) throw new Error('Final copy failed');
    return original(...args);
  });
  assert.throws(() => install(root), /Final copy failed/);
  assert.deepEqual(fs.readdirSync(path.dirname(unrelated)), ['unrelated']);
  assert.equal(fs.readFileSync(path.join(unrelated, 'keep'), 'utf8'), 'keep');
});

test('rollback cleanup errors are surfaced instead of hiding partial installation', (t) => {
  const root = directory(t);
  const remove = fs.rmSync;
  t.mock.method(fs, 'cpSync', () => { throw new Error('Copy failed'); });
  const mocked = t.mock.method(fs, 'rmSync', (file, options) => {
    if (file.endsWith(`${path.sep}member-one`)) throw new Error('Access denied');
    return remove(file, options);
  });
  assert.throws(() => install(root), /Copy failed; cleanup failed:.*Access denied/);
  mocked.mock.restore();
});

test('personal pack preview resolves all members without a workspace or writes to a missing root', (t) => {
  const home = directory(t);
  const { api } = fixture();
  const result = planPack(pack.name, undefined, { scope: 'personal', homedir: () => home, api });
  assert.equal(result.scope, 'personal');
  assert.equal(result.destinationRoot, path.join(home, '.copilot', 'skills'));
  assert.equal(result.revision, revision);
  assert.deepEqual(result.pack.skills, pack.skills);
  assert.deepEqual(result.members.map((member) => member.destination),
    skills.map((skill) => path.join(result.destinationRoot, skill.name)));
  assert.ok(result.members.every((member) => member.files.length === 3));
  assert.deepEqual(result.conflicts, []);
  assert.deepEqual(fs.readdirSync(home), []);
});

test('personal pack install stages all members before final writes and records personal pack provenance', (t) => {
  const home = directory(t);
  const root = path.join(home, '.copilot', 'skills');
  const { api } = fixture({
    beforeBlob: () => {
      for (const skill of skills) assert.equal(fs.existsSync(path.join(root, skill.name)), false);
    },
  });
  const result = installPack(pack.name, undefined, {
    scope: 'personal', homedir: () => home, api, approved: true, revision,
  });
  assert.equal(result.scope, 'personal');
  assert.equal(result.destinationRoot, root);
  assert.deepEqual(result.destinations, skills.map((skill) => path.join(root, skill.name)));
  for (const destination of result.destinations) {
    const provenance = JSON.parse(fs.readFileSync(path.join(destination, '.git-ape-provenance.json')));
    assert.equal(provenance.scope, 'personal');
    assert.equal(provenance.destination, destination);
    assert.equal(provenance.pack, pack.name);
    assert.equal(provenance.revision, revision);
    assert.ok(fs.existsSync(path.join(destination, 'scripts', 'check.js')));
  }
  assert.deepEqual(fs.readdirSync(root).sort(), pack.skills);
});

test('pack scope defaults to workspace and rejects invalid, ambiguous or missing workspace targets before networking', (t) => {
  const home = directory(t);
  const { api } = fixture();
  const implicit = planPack(pack.name, home, { api });
  assert.equal(implicit.scope, 'workspace');
  assert.equal(implicit.destinationRoot, path.join(home, '.github', 'skills'));
  assert.deepEqual(planPack(pack.name, home, { scope: 'workspace', api }), implicit);
  const offline = () => { throw new Error('Unexpected network'); };
  for (const action of [planPack, installPack]) {
    const options = { api: offline, approved: true, revision, homedir: () => home };
    for (const scope of ['', 'global', null]) {
      assert.throws(() => action(pack.name, home, { ...options, scope }), /Scope must be/);
    }
    assert.throws(() => action(pack.name, home, { ...options, scope: 'personal' }), /cannot be combined/);
    assert.throws(() => action(pack.name, undefined, options), /requires --workspace/);
    assert.throws(() => action(pack.name, path.join(home, 'absent'), options), /Workspace does not exist/);
  }
  assert.deepEqual(fs.readdirSync(home), []);
});

test('personal packs still require approval and a pinned full SHA without creating the root', (t) => {
  const home = directory(t);
  const options = { scope: 'personal', homedir: () => home, api: () => { throw new Error('Unexpected network'); } };
  assert.throws(() => installPack(pack.name, undefined, { ...options, revision }), /explicit approval/);
  for (const invalid of [undefined, '', 'main', 'a'.repeat(39), 'A'.repeat(40)]) {
    assert.throws(() => installPack(pack.name, undefined, {
      ...options, approved: true, revision: invalid,
    }), /pinned full/);
  }
  assert.deepEqual(fs.readdirSync(home), []);
});

test('personal pack conflicts preserve existing skills and prevent all final member writes', (t) => {
  for (const obstacle of ['existing', 'case', 'symlink']) {
    const home = directory(t);
    const root = path.join(home, '.copilot', 'skills');
    const destination = path.join(root, obstacle === 'case' ? 'Member-Two' : 'member-two');
    fs.mkdirSync(root, { recursive: true });
    if (obstacle === 'symlink') {
      fs.symlinkSync(path.join(home, 'missing-target'), destination, process.platform === 'win32' ? 'junction' : 'dir');
    } else {
      fs.mkdirSync(destination);
      fs.writeFileSync(path.join(destination, 'keep'), 'keep');
    }
    const options = { scope: 'personal', homedir: () => home, ...fixture(), revision };
    assert.match(planPack(pack.name, undefined, options).conflicts.join(), /collision|overwrite/);
    assert.throws(() => installPack(pack.name, undefined, { ...options, approved: true }), /collision|overwrite/);
    assert.equal(fs.existsSync(path.join(root, 'member-one')), false);
    assert.deepEqual(fs.readdirSync(root), [path.basename(destination)]);
    if (obstacle === 'symlink') fs.unlinkSync(destination);
    else assert.equal(fs.readFileSync(path.join(destination, 'keep'), 'utf8'), 'keep');
  }
});

test('personal pack failed or corrupt later download leaves no final members or staging', (t) => {
  for (const outcome of ['network', 'corrupt']) {
    const home = directory(t);
    const root = path.join(home, '.copilot', 'skills');
    let count = 0;
    const { api } = fixture({
      blobResponse: (endpoint, blobs) => {
        if (++count < 5) return blobs.get(endpoint.slice('git/blobs/'.length));
        if (outcome === 'network') throw new Error('Network failure');
        return { encoding: 'base64', content: Buffer.from('corrupt').toString('base64') };
      },
    });
    assert.throws(() => installPack(pack.name, undefined, {
      scope: 'personal', homedir: () => home, api, revision, approved: true,
    }), /Network failure|integrity check/);
    assert.deepEqual(fs.readdirSync(root), []);
  }
});

test('personal pack final-copy failure rolls back only owned directories and keeps unrelated content', (t) => {
  const home = directory(t);
  const root = path.join(home, '.copilot', 'skills');
  const unrelated = path.join(root, 'unrelated');
  fs.mkdirSync(unrelated, { recursive: true });
  fs.writeFileSync(path.join(unrelated, 'keep'), 'keep');
  const copy = fs.cpSync;
  let count = 0;
  t.mock.method(fs, 'cpSync', (...args) => {
    if (++count === 2) throw new Error('Final copy failed');
    return copy(...args);
  });
  assert.throws(() => installPack(pack.name, undefined, {
    scope: 'personal', homedir: () => home, ...fixture(), revision, approved: true,
  }), /Final copy failed/);
  assert.deepEqual(fs.readdirSync(root), ['unrelated']);
  assert.equal(fs.readFileSync(path.join(unrelated, 'keep'), 'utf8'), 'keep');
});
