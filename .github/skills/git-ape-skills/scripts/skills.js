#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');

const REPOSITORY = 'Azure/git-ape';
const NAME_RE = /^[a-z][a-z0-9]*(-[a-z0-9]+)*$/;
const REVISION_RE = /^[a-f0-9]{40}$/;

function githubApi(endpoint) {
  return JSON.parse(execFileSync('gh', ['api', `repos/${REPOSITORY}/${endpoint}`], {
    encoding: 'utf8', maxBuffer: 32 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'],
  }));
}

function assertName(name) {
  if (typeof name !== 'string' || name.length > 100 || !NAME_RE.test(name) ||
      /^(con|prn|aux|nul|com[1-9]|lpt[1-9])$/i.test(name)) {
    throw new Error('Skill or pack name must use a portable kebab-case directory name (at most 100 characters).');
  }
}

function validatePacks(packs = [], skills) {
  if (!Array.isArray(packs) || !Array.isArray(skills)) throw new Error('Malformed skill registry.');
  const names = new Set();
  for (const pack of packs) {
    if (!pack || typeof pack !== 'object' || Array.isArray(pack)) throw new Error('Malformed pack manifest.');
    if (Object.keys(pack).some((key) => !['name', 'description', 'author', 'skills'].includes(key))) {
      throw new Error('Unknown pack manifest metadata.');
    }
    assertName(pack.name);
    if (names.has(pack.name)) throw new Error(`Duplicate pack name: ${pack.name}`);
    names.add(pack.name);
    for (const field of ['description', 'author']) {
      if (typeof pack[field] !== 'string' || !pack[field].trim() || /[\x00-\x1f]/.test(pack[field])) {
        throw new Error(`Pack ${pack.name} requires non-empty ${field} metadata without control characters.`);
      }
    }
    if (!Array.isArray(pack.skills) || !pack.skills.length) throw new Error(`Pack ${pack.name} must have members.`);
    const members = new Set();
    for (const name of pack.skills) {
      assertName(name);
      if (members.has(name)) throw new Error(`Duplicate member ${name} in pack ${pack.name}`);
      members.add(name);
      const matches = skills.filter((skill) => skill && skill.name === name);
      if (matches.length !== 1 || matches[0].tier !== 'community') {
        throw new Error(`Pack ${pack.name} member ${name} must identify one community skill.`);
      }
    }
  }
  return packs;
}

function searchSkills(registry, query = '') {
  const packs = validatePacks(registry.packs, registry.skills);
  const terms = query.toLowerCase().split(/\s+/).filter(Boolean);
  return [...registry.skills, ...packs.map((pack) => ({ ...pack, kind: 'pack' }))].filter((entry) => {
    const text = `${entry.name} ${entry.description} ${entry.author} ${entry.tier || 'pack'} ${(entry.skills || []).join(' ')}`.toLowerCase();
    return terms.every((term) => text.includes(term));
  });
}

function lstat(file) {
  try { return fs.lstatSync(file); }
  catch (error) { if (error.code === 'ENOENT') return undefined; throw error; }
}

function assertPlainDirectory(directory) {
  const resolved = path.resolve(directory);
  let current = path.parse(resolved).root;
  for (const part of resolved.slice(current.length).split(path.sep).filter(Boolean)) {
    if (lstat(current)?.isDirectory()) {
      const collision = fs.readdirSync(current).find((name) => name !== part && name.toLowerCase() === part.toLowerCase());
      if (collision) throw new Error(`Case collision in installation path: ${path.join(current, collision)}`);
    }
    current = path.join(current, part);
    const stat = lstat(current);
    if (stat && (stat.isSymbolicLink() || !stat.isDirectory())) {
      throw new Error(`Installation path must contain only real directories: ${current}`);
    }
  }
}

function destinationConflict(destination) {
  try {
    assertPlainDirectory(path.dirname(destination));
    if (lstat(destination)) return `Refusing to overwrite ${destination}`;
    if (lstat(path.dirname(destination))) {
      const name = path.basename(destination);
      if (fs.readdirSync(path.dirname(destination)).some((entry) => entry.toLowerCase() === name.toLowerCase())) {
        return `Case collision at ${destination}`;
      }
    }
  } catch (error) { return error.message; }
}

function sourceFiles(skill, tree) {
  const prefix = `${skill.path}/`;
  const entries = tree.filter((entry) => typeof entry.path === 'string' && entry.path.startsWith(prefix));
  const nodes = new Map();
  const explicit = new Set();
  for (const entry of entries) {
    const relative = entry.path.slice(prefix.length);
    const parts = relative.split('/');
    if ((entry.type !== 'blob' && entry.type !== 'tree') ||
        (entry.type === 'blob' && (!['100644', '100755'].includes(entry.mode) || !REVISION_RE.test(entry.sha))) ||
        (entry.type === 'tree' && entry.mode !== '040000') ||
        parts.some((part) => !part || part === '.' || part === '..' || part.toLowerCase() === '.git' ||
          /[\\:<>"|?*\x00-\x1f]/.test(part) || /[. ]$/.test(part) ||
          /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(part)) ||
        parts[0].toLowerCase() === '.git-ape-provenance.json' || explicit.has(relative.toLowerCase())) {
      throw new Error(`Unsupported or unsafe skill file: ${entry.path}`);
    }
    explicit.add(relative.toLowerCase());
    for (let i = 1; i <= parts.length; i++) {
      const name = parts.slice(0, i).join('/');
      const type = i === parts.length ? entry.type : 'tree';
      const previous = nodes.get(name.toLowerCase());
      if (previous && (previous.name !== name || previous.type !== type)) {
        throw new Error(`Unsupported or unsafe skill file (case or file/directory collision): ${entry.path}`);
      }
      nodes.set(name.toLowerCase(), { name, type });
    }
  }
  const files = entries.filter((entry) => entry.type === 'blob');
  if (!files.some((entry) => entry.path === `${prefix}SKILL.md`)) throw new Error('Selected skill is missing SKILL.md.');
  return files.map((entry) => ({ ...entry, relative: entry.path.slice(prefix.length) }));
}

function readBlob(entry, api) {
  const blob = api(`git/blobs/${entry.sha}`);
  if (!blob || blob.encoding !== 'base64' || typeof blob.content !== 'string') throw new Error(`Invalid blob response: ${entry.path}`);
  const content = Buffer.from(blob.content, 'base64');
  const hash = crypto.createHash('sha1').update(`blob ${content.length}\0`).update(content).digest('hex');
  if (hash !== entry.sha) throw new Error(`Blob integrity check failed: ${entry.path}`);
  return content;
}

function prepare(name, workspace, { revision, api = githubApi } = {}, isPack = false) {
  assertName(name);
  if (revision !== undefined && !REVISION_RE.test(revision)) throw new Error('Revision must be a full 40-character lowercase commit SHA.');
  const root = path.resolve(workspace);
  assertPlainDirectory(root);
  if (!lstat(root)) throw new Error(`Workspace does not exist: ${root}`);
  const commit = revision || api('commits/main').sha;
  if (!REVISION_RE.test(commit)) throw new Error('GitHub did not return a valid commit SHA.');
  const response = api(`contents/.github/skills/registry.json?ref=${commit}`);
  if (response.encoding !== 'base64' || typeof response.content !== 'string') throw new Error('GitHub returned an invalid registry response.');
  const registry = JSON.parse(Buffer.from(response.content, 'base64').toString('utf8'));
  const packs = validatePacks(registry.packs, registry.skills);
  const pack = isPack ? packs.find((entry) => entry.name === name) : undefined;
  if (isPack && !pack) throw new Error(`No installable pack '${name}' in ${REPOSITORY}@${commit}`);
  const members = (pack ? pack.skills : [name]).map((member) => {
    const matches = registry.skills.filter((entry) => entry && entry.name === member && entry.tier === 'community');
    const skill = matches[0];
    if (matches.length !== 1 || skill.path !== `.github/community-skills/${member}`) {
      throw new Error(`No installable community skill '${member}' in ${REPOSITORY}@${commit}`);
    }
    return { skill, destination: path.join(root, '.github', 'skills', member) };
  });
  const tree = api(`git/trees/${commit}?recursive=1`);
  if (tree.truncated || !Array.isArray(tree.tree)) throw new Error('GitHub returned an incomplete source tree.');
  for (const member of members) member.files = sourceFiles(member.skill, tree.tree);
  if (pack) {
    const manifestPath = `.github/skill-packs/${name}/pack.json`;
    const entries = tree.tree.filter((entry) => entry.path === manifestPath);
    const entry = entries[0];
    if (entries.length !== 1 || entry.type !== 'blob' || !['100644', '100755'].includes(entry.mode) || !REVISION_RE.test(entry.sha)) {
      throw new Error(`Missing or unsafe pack manifest: ${manifestPath}`);
    }
    const manifest = JSON.parse(readBlob(entry, api).toString('utf8'));
    validatePacks([manifest], registry.skills);
    if (['name', 'description', 'author', 'skills'].some((field) => JSON.stringify(manifest[field]) !== JSON.stringify(pack[field]))) {
      throw new Error(`Pack manifest does not match pinned registry: ${manifestPath}`);
    }
  }
  const conflicts = members.map((member) => destinationConflict(member.destination)).filter(Boolean);
  return { root, revision: commit, pack, members, conflicts };
}

function planPack(name, workspace, options) {
  const plan = prepare(name, workspace, options, true);
  return {
    repository: REPOSITORY, revision: plan.revision, pack: plan.pack, conflicts: plan.conflicts,
    members: plan.members.map(({ skill, destination, files }) => ({
      name: skill.name, sourcePath: skill.path, destination,
      files: files.map(({ relative, sha, mode }) => ({ path: relative, sha, mode, destination: path.join(destination, ...relative.split('/')) })),
      provenanceFile: path.join(destination, '.git-ape-provenance.json'),
    })),
  };
}

function executeInstall(plan, api) {
  if (plan.conflicts.length) throw new Error(plan.conflicts.join('\n'));
  // Stage inside the selected workspace, never in a global temporary directory.
  const staging = fs.mkdtempSync(path.join(plan.root, '.git-ape-stage-'));
  const created = [];
  let failure;
  let result;
  const cleanupErrors = [];
  try {
    for (const { skill, files } of plan.members) {
      const directory = path.join(staging, skill.name);
      fs.mkdirSync(directory);
      for (const entry of files) {
        const content = readBlob(entry, api);
        const output = path.join(directory, ...entry.relative.split('/'));
        fs.mkdirSync(path.dirname(output), { recursive: true });
        fs.writeFileSync(output, content, { flag: 'wx', mode: entry.mode === '100755' ? 0o755 : 0o644 });
      }
      fs.writeFileSync(path.join(directory, '.git-ape-provenance.json'), JSON.stringify({
        repository: REPOSITORY, revision: plan.revision, skill: skill.name, sourcePath: skill.path,
        ...(plan.pack ? { pack: plan.pack.name, packSourcePath: `.github/skill-packs/${plan.pack.name}/pack.json` } : {}),
      }, null, 2) + '\n', { flag: 'wx' });
    }
    // Recheck the entire destination set after downloads, before any final copy.
    for (const member of plan.members) {
      const conflict = destinationConflict(member.destination);
      if (conflict) throw new Error(conflict);
    }
    for (const { skill, destination } of plan.members) {
      const conflict = destinationConflict(destination);
      if (conflict) throw new Error(conflict);
      fs.mkdirSync(path.dirname(destination), { recursive: true });
      fs.mkdirSync(destination);
      created.push({ destination, stat: fs.lstatSync(destination) });
      fs.cpSync(path.join(staging, skill.name), destination, { recursive: true, errorOnExist: true, force: false });
    }
    result = { revision: plan.revision, destinations: plan.members.map((member) => member.destination) };
  } catch (error) {
    failure = error;
    for (const { destination, stat } of created.reverse()) {
      try {
        const current = lstat(destination);
        if (current && (current.isSymbolicLink() || current.ino !== stat.ino || current.dev !== stat.dev)) {
          throw new Error(`Owned directory was replaced: ${destination}`);
        }
        fs.rmSync(destination, { recursive: true, force: true });
      } catch (cleanup) { cleanupErrors.push(`${destination}: ${cleanup.message}`); }
    }
  }
  try { fs.rmSync(staging, { recursive: true, force: true }); }
  catch (cleanup) { cleanupErrors.push(`${staging}: ${cleanup.message}`); }
  if (cleanupErrors.length) throw new Error(`${failure?.message || 'Installation completed'}; cleanup failed: ${cleanupErrors.join('; ')}`);
  if (failure) throw failure;
  return result;
}

function installSkill(name, workspace, { revision, approved = false, api = githubApi } = {}) {
  if (!approved) throw new Error('Installation requires explicit approval (--yes).');
  const result = executeInstall(prepare(name, workspace, { revision, api }), api);
  return { destination: result.destinations[0], revision: result.revision };
}

function installPack(name, workspace, { revision, approved = false, api = githubApi } = {}) {
  if (!approved) throw new Error('Installation requires explicit approval (--yes).');
  if (!revision || !REVISION_RE.test(revision)) throw new Error('Pack installation requires a pinned full 40-character lowercase commit SHA.');
  const plan = prepare(name, workspace, { revision, api }, true);
  return { pack: name, ...executeInstall(plan, api) };
}

function main(args) {
  const [command, ...rest] = args;
  if (command === 'search') {
    const registry = JSON.parse(fs.readFileSync(path.resolve(__dirname, '..', '..', 'registry.json'), 'utf8'));
    console.log(JSON.stringify(searchSkills(registry, rest.join(' ')), null, 2));
    return;
  }
  if (['install', 'plan-pack', 'install-pack'].includes(command)) {
    const [name, ...options] = rest;
    let workspace;
    let revision;
    let approved = false;
    for (let i = 0; i < options.length; i++) {
      if (options[i] === '--workspace' || options[i] === '--revision') {
        const option = options[i];
        const value = options[++i];
        if (!value || value.startsWith('--')) throw new Error(`${option} requires a value.`);
        if (option === '--workspace') workspace = value;
        else revision = value;
      } else if (options[i] === '--yes' && command !== 'plan-pack') approved = true;
      else throw new Error(`Unknown option: ${options[i]}`);
    }
    if (!name || !workspace) throw new Error(`${command} requires a name and --workspace <directory>.`);
    const action = command === 'plan-pack' ? planPack : command === 'install-pack' ? installPack : installSkill;
    console.log(JSON.stringify(action(name, workspace, { revision, approved }), null, 2));
    return;
  }
  throw new Error('Usage: skills.js search [query] | install|plan-pack|install-pack <name> --workspace <directory> [--revision <sha>] [--yes]');
}

if (require.main === module) {
  try { main(process.argv.slice(2)); }
  catch (error) { console.error(`Git-Ape skills: ${error.message}`); process.exitCode = 1; }
}

module.exports = { searchSkills, installSkill, planPack, installPack, validatePacks };
