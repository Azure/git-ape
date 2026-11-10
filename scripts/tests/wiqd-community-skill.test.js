const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { searchSkills } = require('../../.github/skills/git-ape-skills/scripts/skills');
const matter = require('../../website/node_modules/gray-matter');

const root = path.resolve(__dirname, '..', '..');
const skillRoot = path.join(root, '.github', 'community-skills', 'wiqd');
const skill = fs.readFileSync(path.join(skillRoot, 'SKILL.md'), 'utf8');
const lifecycle = fs.readFileSync(path.join(skillRoot, 'references', 'lifecycle.md'), 'utf8');
const validation = fs.readFileSync(path.join(skillRoot, 'references', 'validation.md'), 'utf8');
const registry = JSON.parse(fs.readFileSync(path.join(root, '.github', 'skills', 'registry.json'), 'utf8'));

test('WIQD follows the community template with experimental author attribution', () => {
  const { data } = matter(skill);
  assert.equal(data.name, 'wiqd');
  assert.equal(data.license, 'MIT');
  assert.equal(data['user-invocable'], true);
  assert.equal(data.metadata.author, 'dawright22');
  assert.equal(data.metadata.source, 'https://github.com/dawright22/wiqd-skill');
  assert.equal(data.metadata.maturity, 'experimental');
  assert.match(data.metadata.version, /^\d+\.\d+\.\d+$/);
  for (const section of ['When to Use', 'Procedure', 'Outputs', 'Constraints', 'Attribution']) {
    assert.ok(skill.includes(`## ${section}`), `Missing community section: ${section}`);
  }
  assert.doesNotMatch(skill, /\bTODO\b|<!--/);
});

test('WIQD searches return one unbundled community skill with generated documentation', () => {
  for (const query of ['wiqd', 'Work IQ', 'Microsoft 365', 'offline packaging']) {
    const matches = searchSkills(registry, query).filter(entry => entry.name === 'wiqd');
    assert.equal(matches.length, 1, `Missing or duplicated WIQD result for ${query}`);
    const [entry] = matches;
    assert.equal(entry.tier, 'community');
    assert.equal(entry.bundled, false);
    assert.equal(entry.author, 'dawright22');
    assert.equal(entry.source, 'https://github.com/dawright22/wiqd-skill');
    assert.equal(entry.path, '.github/community-skills/wiqd');
    assert.equal(entry.maturity, 'experimental');
    assert.equal(entry.docsUrl, 'https://azure.github.io/git-ape/docs/skills/community/wiqd');
  }
  assert.equal(fs.existsSync(path.join(root, '.github', 'skills', 'wiqd')), false);
  const docs = fs.readFileSync(path.join(root, 'website', 'docs', 'skills', 'community', 'wiqd.md'), 'utf8');
  assert.match(docs, /Third-party community skill/);
  for (const reference of ['lifecycle.md', 'validation.md']) {
    assert.ok(docs.includes(`https://github.com/Azure/git-ape/blob/main/.github/community-skills/wiqd/references/${reference}`));
  }
});

test('WIQD supporting links remain inside the installable skill directory', () => {
  for (const [file, text] of [
    [path.join(skillRoot, 'SKILL.md'), skill],
    [path.join(skillRoot, 'references', 'lifecycle.md'), lifecycle],
    [path.join(skillRoot, 'references', 'validation.md'), validation],
  ]) {
    for (const [, target] of text.matchAll(/\[[^\]]*\]\(([^)]+)\)/g)) {
      if (/^https:\/\//.test(target) || target.startsWith('#')) continue;
      const resolved = path.resolve(path.dirname(file), target.split('#')[0]);
      assert.ok(resolved.startsWith(`${skillRoot}${path.sep}`), `External dependency: ${target}`);
      assert.ok(fs.statSync(resolved).isFile(), `Missing reference: ${target}`);
    }
  }
});

test('WIQD keeps authentication, uploads and mutations behind explicit instruction safeguards', () => {
  const prose = skill.replace(/\s+/g, ' ');
  for (const clause of [
    'Source validation is the default',
    'Never invoke `wiqd auth login`',
    'Installation approval is not EULA acceptance',
    'Deletion requires a separate destructive-action approval',
    'Tenant-wide sharing requires explicit tenant-wide audience confirmation',
    'obtain explicit upload approval',
    'Never provision automatically',
    'Do not retry ambiguous tenant mutations automatically',
    'Do not delete successful resources as automatic compensation',
    'Sharing is not catalogue publication',
    'Submission is not administrator approval',
    "Write Microsoft 365 lifecycle state into Git-Ape's Azure",
    'Do not persist a report containing tenant data without',
    'not an executable access-control boundary',
  ]) {
    assert.ok(prose.includes(clause), `Missing safeguard: ${clause}`);
  }
});

test('WIQD offline preview cannot silently replace provisioned packaging', () => {
  const prose = skill.replace(/\s+/g, ' ');
  assert.match(prose, /Obtain preview opt-in before changing the source manifest/);
  assert.match(prose, /Never silently substitute offline preview for standard packaging/);
  assert.match(prose, /`--env` is an output label, not a deployment context/);
  assert.match(lifecycle, /manifestVersion": "devPreview"/);
  assert.match(lifecycle, /vDevPreview\/MicrosoftTeams\.schema\.json/);
  assert.match(lifecycle, /Do not populate\s+`TEAMS_APP_ID` manually/);
  assert.match(lifecycle, /Cowork\/AVL acceptance and runtime behaviour remain unverified/);
});

test('WIQD documents coverage limits rather than claiming tenant or behavioural validation', () => {
  assert.match(skill, /not full plugin validation/);
  assert.match(skill, /source or ZIP changes/);
  assert.match(lifecycle, /Tenant operations were not tested/);
  assert.match(lifecycle, /does\s+not build a ZIP or authenticate automatically/);
  assert.match(lifecycle, /no `plugin provision --scope shared` option/);
  assert.match(validation, /remain unexecuted with an assistant evaluator/);
  assert.match(validation, /Structured rubber-duck review/);
  assert.match(validation, /No tenant test resources were created/);
});
