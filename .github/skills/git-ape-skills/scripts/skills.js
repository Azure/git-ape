#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');

const REPOSITORY = 'Azure/git-ape';
const NAME_RE = /^[a-z][a-z0-9]*(-[a-z0-9]+)*$/;
const REVISION_RE = /^[a-f0-9]{40}$/;

function githubApi(endpoint) {
  return JSON.parse(execFileSync('gh', ['api', `repos/${REPOSITORY}/${endpoint}`], {
    encoding: 'utf8',
    maxBuffer: 32 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
  }));
}

function searchSkills(registry, query = '') {
  const terms = query.toLowerCase().split(/\s+/).filter(Boolean);
  return registry.skills.filter((skill) => {
    const text = `${skill.name} ${skill.description} ${skill.author} ${skill.tier}`.toLowerCase();
    return terms.every((term) => text.includes(term));
  });
}

function assertPlainDirectory(directory) {
  const resolved = path.resolve(directory);
  let current = path.parse(resolved).root;
  for (const part of resolved.slice(current.length).split(path.sep).filter(Boolean)) {
    current = path.join(current, part);
    if (fs.existsSync(current)) {
      const stat = fs.lstatSync(current);
      if (stat.isSymbolicLink() || !stat.isDirectory()) {
        throw new Error(`Installation path must contain only real directories: ${current}`);
      }
    }
  }
}

function installSkill(name, workspace, { revision, approved = false, api = githubApi } = {}) {
  if (!approved) throw new Error('Installation requires explicit approval (--yes).');
  if (!NAME_RE.test(name) || /^(con|prn|aux|nul|com[1-9]|lpt[1-9])$/i.test(name)) {
    throw new Error('Skill name must use a portable kebab-case directory name.');
  }
  if (revision !== undefined && !REVISION_RE.test(revision)) {
    throw new Error('Revision must be a full 40-character lowercase commit SHA.');
  }
  const root = path.resolve(workspace);
  assertPlainDirectory(root);
  if (!fs.existsSync(root)) throw new Error(`Workspace does not exist: ${root}`);
  const destination = path.join(root, '.github', 'skills', name);
  assertPlainDirectory(path.dirname(destination));
  if (fs.existsSync(destination)) throw new Error(`Refusing to overwrite ${destination}`);

  const commit = revision || api('commits/main').sha;
  if (!REVISION_RE.test(commit)) throw new Error('GitHub did not return a valid commit SHA.');
  const registryResponse = api(`contents/.github/skills/registry.json?ref=${commit}`);
  if (registryResponse.encoding !== 'base64' || typeof registryResponse.content !== 'string') {
    throw new Error('GitHub returned an invalid registry response.');
  }
  const registry = JSON.parse(Buffer.from(registryResponse.content, 'base64').toString('utf8'));
  const skill = registry.skills.find((entry) => entry.name === name && entry.tier === 'community');
  if (!skill || skill.path !== `.github/community-skills/${name}`) {
    throw new Error(`No installable community skill '${name}' in ${REPOSITORY}@${commit}`);
  }

  const tree = api(`git/trees/${commit}?recursive=1`);
  if (tree.truncated || !Array.isArray(tree.tree)) throw new Error('GitHub returned an incomplete source tree.');
  const prefix = `${skill.path}/`;
  const entries = tree.tree.filter((entry) => entry.path.startsWith(prefix) && entry.type !== 'tree');
  if (!entries.some((entry) => entry.path === `${prefix}SKILL.md`)) {
    throw new Error('Selected skill is missing SKILL.md.');
  }
  const filenames = new Set();
  for (const entry of entries) {
    const relative = entry.path.slice(prefix.length);
    const parts = relative.split('/');
    if (entry.type !== 'blob' || !['100644', '100755'].includes(entry.mode) ||
        parts.some((part) => !part || part === '.' || part === '..' ||
          part.toLowerCase() === '.git' ||
          /[\\:<>"|?*\x00-\x1f]/.test(part) || /[. ]$/.test(part) ||
          /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(part)) ||
        filenames.has(relative.toLowerCase()) || relative.toLowerCase() === '.git-ape-provenance.json') {
      throw new Error(`Unsupported or unsafe skill file: ${entry.path}`);
    }
    filenames.add(relative.toLowerCase());
  }

  const staging = fs.mkdtempSync(path.join(os.tmpdir(), 'git-ape-skill-'));
  let destinationCreated = false;
  try {
    for (const entry of entries) {
      const blob = api(`git/blobs/${entry.sha}`);
      if (blob.encoding !== 'base64' || typeof blob.content !== 'string') {
        throw new Error(`Invalid blob response: ${entry.path}`);
      }
      const content = Buffer.from(blob.content, 'base64');
      const hash = crypto.createHash('sha1')
        .update(`blob ${content.length}\0`).update(content).digest('hex');
      if (hash !== entry.sha) throw new Error(`Blob integrity check failed: ${entry.path}`);
      const output = path.join(staging, ...entry.path.slice(prefix.length).split('/'));
      fs.mkdirSync(path.dirname(output), { recursive: true });
      fs.writeFileSync(output, content, { flag: 'wx', mode: entry.mode === '100755' ? 0o755 : 0o644 });
    }
    fs.writeFileSync(path.join(staging, '.git-ape-provenance.json'), JSON.stringify({
      repository: REPOSITORY, revision: commit, skill: name, sourcePath: skill.path,
    }, null, 2) + '\n');
    assertPlainDirectory(path.dirname(destination));
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.mkdirSync(destination);
    destinationCreated = true;
    fs.cpSync(staging, destination, { recursive: true, errorOnExist: true, force: false });
    return { destination, revision: commit };
  } catch (error) {
    if (destinationCreated) fs.rmSync(destination, { recursive: true, force: true });
    throw error;
  } finally {
    fs.rmSync(staging, { recursive: true, force: true });
  }
}

function main(args) {
  const [command, ...rest] = args;
  if (command === 'search') {
    const registryPath = path.resolve(__dirname, '..', '..', 'registry.json');
    const registry = JSON.parse(fs.readFileSync(registryPath, 'utf8'));
    const matches = searchSkills(registry, rest.join(' '));
    console.log(JSON.stringify(matches, null, 2));
    return;
  }
  if (command === 'install') {
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
      }
      else if (options[i] === '--yes') approved = true;
      else throw new Error(`Unknown option: ${options[i]}`);
    }
    if (!name || !workspace) throw new Error('Install requires a skill name and --workspace <directory>.');
    console.log(JSON.stringify(installSkill(name, workspace, { revision, approved }), null, 2));
    return;
  }
  throw new Error('Usage: skills.js search [query] | install <name> --workspace <directory> [--revision <sha>] --yes');
}

if (require.main === module) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    console.error(`Git-Ape skills: ${error.message}`);
    process.exitCode = 1;
  }
}

module.exports = { searchSkills, installSkill };
