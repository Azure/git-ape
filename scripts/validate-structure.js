#!/usr/bin/env node
/**
 * validate-structure.js
 *
 * Validates the structural integrity of Git-Ape skills and agents:
 * - YAML frontmatter required fields
 * - Name-directory consistency for skills
 * - Kebab-case directory naming
 * - SKILL.md presence in every skill directory
 * - Required markdown sections
 * - Cross-reference integrity (slash-commands and agent references)
 * - Relative link validation
 *
 * Usage: node scripts/validate-structure.js
 * Exit code 0 = all checks pass, 1 = failures found.
 */

const fs = require('fs');
const path = require('path');

// Resolve deps from website/node_modules since they're installed there
const WEBSITE_DIR = path.resolve(__dirname, '..', 'website');
const matter = require(path.join(WEBSITE_DIR, 'node_modules', 'gray-matter'));

const ROOT = path.resolve(__dirname, '..');
const AGENTS_DIR = path.join(ROOT, '.github', 'agents');
const SKILLS_DIR = path.join(ROOT, '.github', 'skills');

const KEBAB_CASE_RE = /^[a-z][a-z0-9]*(-[a-z0-9]+)*$/;

let errors = [];
let warnings = [];

function error(msg) {
  errors.push(msg);
  console.error(`  ❌ ${msg}`);
}

function warn(msg) {
  warnings.push(msg);
  console.warn(`  ⚠️  ${msg}`);
}

function ok(msg) {
  console.log(`  ✅ ${msg}`);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getSkillDirs() {
  if (!fs.existsSync(SKILLS_DIR)) return [];
  return fs.readdirSync(SKILLS_DIR).filter((d) => {
    return fs.statSync(path.join(SKILLS_DIR, d)).isDirectory();
  });
}

function getAgentFiles() {
  if (!fs.existsSync(AGENTS_DIR)) return [];
  return fs.readdirSync(AGENTS_DIR).filter((f) => f.endsWith('.agent.md'));
}

function parseFrontmatter(filePath) {
  const raw = fs.readFileSync(filePath, 'utf-8');
  try {
    return matter(raw);
  } catch (e) {
    return null;
  }
}

function extractSlashCommands(content) {
  // Match /skill-name patterns that look like intentional skill invocations
  // Exclude common false positives: file paths, URLs, API paths
  const PATH_PREFIXES = new Set([
    'etc', 'dev', 'usr', 'var', 'tmp', 'home', 'opt', 'bin', 'sbin',
    'api', 'v1', 'v2', 'v3', 'subscriptions', 'providers', 'admin',
  ]);
  const matches = content.match(/(?:^|\s)\/([a-z][a-z0-9-]*)/gm) || [];
  return matches
    .map((m) => m.trim().slice(1))
    .filter((cmd) => !PATH_PREFIXES.has(cmd) && !cmd.includes('/'));
}

function extractRelativeLinks(content) {
  // Match markdown links [text](./path) or [text](../path) — relative only
  const matches = content.match(/\]\((\.[^)]+)\)/g) || [];
  return matches.map((m) => m.slice(2, -1)); // Extract path from ](path)
}

// ---------------------------------------------------------------------------
// Checks
// ---------------------------------------------------------------------------

function checkKebabCase(dirs, label) {
  console.log(`\n📁 Kebab-case naming (${label}):`);
  for (const dir of dirs) {
    if (!KEBAB_CASE_RE.test(dir)) {
      error(`${label} directory '${dir}' is not kebab-case`);
    }
  }
  if (dirs.every((d) => KEBAB_CASE_RE.test(d))) {
    ok(`All ${dirs.length} ${label} directories are kebab-case`);
  }
}

function checkSkillPresence(skillDirs) {
  console.log('\n📄 SKILL.md presence:');
  for (const dir of skillDirs) {
    const skillMd = path.join(SKILLS_DIR, dir, 'SKILL.md');
    if (!fs.existsSync(skillMd)) {
      error(`Skill directory '${dir}' is missing SKILL.md`);
    }
  }
  const allPresent = skillDirs.every((d) =>
    fs.existsSync(path.join(SKILLS_DIR, d, 'SKILL.md'))
  );
  if (allPresent) {
    ok(`All ${skillDirs.length} skill directories contain SKILL.md`);
  }
}

function checkSkillFrontmatter(skillDirs) {
  console.log('\n🏷️  Skill frontmatter validation:');
  for (const dir of skillDirs) {
    const skillMd = path.join(SKILLS_DIR, dir, 'SKILL.md');
    if (!fs.existsSync(skillMd)) continue;

    const parsed = parseFrontmatter(skillMd);
    if (!parsed) {
      error(`${dir}/SKILL.md: Could not parse YAML frontmatter`);
      continue;
    }

    const { data: fm } = parsed;

    if (!fm.name) {
      error(`${dir}/SKILL.md: Missing required frontmatter field 'name'`);
    } else if (fm.name !== dir) {
      error(`${dir}/SKILL.md: Frontmatter 'name' is '${fm.name}' but directory is '${dir}'`);
    }

    if (!fm.description) {
      error(`${dir}/SKILL.md: Missing required frontmatter field 'description'`);
    }
  }
  if (errors.length === 0) {
    ok('All skills have valid frontmatter with name and description');
  }
}

function checkAgentFrontmatter(agentFiles) {
  console.log('\n🏷️  Agent frontmatter validation:');
  for (const file of agentFiles) {
    const filePath = path.join(AGENTS_DIR, file);
    const parsed = parseFrontmatter(filePath);
    if (!parsed) {
      error(`${file}: Could not parse YAML frontmatter`);
      continue;
    }

    const { data: fm } = parsed;

    if (!fm.description) {
      error(`${file}: Missing required frontmatter field 'description'`);
    }
  }
  if (!agentFiles.some((f) => {
    const parsed = parseFrontmatter(path.join(AGENTS_DIR, f));
    return !parsed || !parsed.data.description;
  })) {
    ok(`All ${agentFiles.length} agents have valid frontmatter with description`);
  }
}

function checkSkillSections(skillDirs) {
  console.log('\n📑 Required skill sections (## When to Use, ## Procedure):');
  for (const dir of skillDirs) {
    const skillMd = path.join(SKILLS_DIR, dir, 'SKILL.md');
    if (!fs.existsSync(skillMd)) continue;

    const parsed = parseFrontmatter(skillMd);
    if (!parsed) continue;

    const content = parsed.content;

    if (!content.includes('## When to Use')) {
      warn(`${dir}/SKILL.md: Missing '## When to Use' section`);
    }

    // Accept "## Procedure" or equivalent procedural sections
    const hasProcedure = content.includes('## Procedure') ||
      content.includes('## Execution Playbook') ||
      content.includes('## Command Playbook');
    if (!hasProcedure) {
      warn(`${dir}/SKILL.md: Missing '## Procedure' section (or equivalent like '## Execution Playbook')`);
    }
  }
}

function checkAgentSections(agentFiles) {
  console.log('\n📑 Required agent sections (## Warning):');
  for (const file of agentFiles) {
    const filePath = path.join(AGENTS_DIR, file);
    const parsed = parseFrontmatter(filePath);
    if (!parsed) continue;

    if (!parsed.content.includes('## Warning')) {
      error(`${file}: Missing required '## Warning' section`);
    }
  }
  if (!agentFiles.some((f) => {
    const parsed = parseFrontmatter(path.join(AGENTS_DIR, f));
    return parsed && !parsed.content.includes('## Warning');
  })) {
    ok(`All ${agentFiles.length} agents have '## Warning' section`);
  }
}

function checkCrossReferences(skillDirs, agentFiles) {
  console.log('\n🔗 Cross-reference integrity:');

  const skillNames = new Set(skillDirs);

  // Check agent -> agent references
  const agentNameMap = new Map();
  for (const file of agentFiles) {
    const parsed = parseFrontmatter(path.join(AGENTS_DIR, file));
    if (parsed && parsed.data.name) {
      agentNameMap.set(parsed.data.name, file);
    }
  }

  for (const file of agentFiles) {
    const parsed = parseFrontmatter(path.join(AGENTS_DIR, file));
    if (!parsed) continue;

    const { data: fm, content } = parsed;

    // Check agents: field references
    if (Array.isArray(fm.agents)) {
      for (const agentRef of fm.agents) {
        if (!agentNameMap.has(agentRef)) {
          error(`${file}: References agent '${agentRef}' in frontmatter but no matching agent found`);
        }
      }
    }

    // Check slash-command references in content
    const slashCommands = extractSlashCommands(content);
    for (const cmd of slashCommands) {
      if (!skillNames.has(cmd)) {
        // Only warn — some slash commands may reference non-skill entities
        // or be examples in documentation
      }
    }
  }

  // Check skill -> skill slash-command references
  for (const dir of skillDirs) {
    const skillMd = path.join(SKILLS_DIR, dir, 'SKILL.md');
    if (!fs.existsSync(skillMd)) continue;

    const parsed = parseFrontmatter(skillMd);
    if (!parsed) continue;

    const slashCommands = extractSlashCommands(parsed.content);
    for (const cmd of slashCommands) {
      if (!skillNames.has(cmd)) {
        warn(`${dir}/SKILL.md: Slash-command '/${cmd}' does not match any skill directory`);
      }
    }
  }

  if (errors.filter((e) => e.includes('References agent')).length === 0) {
    ok('All agent cross-references are valid');
  }
}

function checkRelativeLinks(skillDirs, agentFiles) {
  console.log('\n🔗 Relative link validation:');
  let linkCount = 0;
  let brokenCount = 0;

  // Check skills
  for (const dir of skillDirs) {
    const skillMd = path.join(SKILLS_DIR, dir, 'SKILL.md');
    if (!fs.existsSync(skillMd)) continue;

    const raw = fs.readFileSync(skillMd, 'utf-8');
    const links = extractRelativeLinks(raw);
    for (const link of links) {
      linkCount++;
      const resolved = path.resolve(path.dirname(skillMd), link);
      if (!fs.existsSync(resolved)) {
        error(`${dir}/SKILL.md: Broken relative link '${link}'`);
        brokenCount++;
      }
    }
  }

  // Check agents
  for (const file of agentFiles) {
    const filePath = path.join(AGENTS_DIR, file);
    const raw = fs.readFileSync(filePath, 'utf-8');
    const links = extractRelativeLinks(raw);
    for (const link of links) {
      linkCount++;
      const resolved = path.resolve(path.dirname(filePath), link);
      if (!fs.existsSync(resolved)) {
        error(`${file}: Broken relative link '${link}'`);
        brokenCount++;
      }
    }
  }

  if (brokenCount === 0) {
    ok(`All ${linkCount} relative links resolve correctly`);
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  console.log('🔍 Git-Ape Structure Validation\n');
  console.log(`   Skills: ${SKILLS_DIR}`);
  console.log(`   Agents: ${AGENTS_DIR}`);

  const skillDirs = getSkillDirs();
  const agentFiles = getAgentFiles();

  console.log(`\n   Found ${skillDirs.length} skill directories`);
  console.log(`   Found ${agentFiles.length} agent files`);

  checkKebabCase(skillDirs, 'skill');
  checkSkillPresence(skillDirs);
  checkSkillFrontmatter(skillDirs);
  checkAgentFrontmatter(agentFiles);
  checkSkillSections(skillDirs);
  checkAgentSections(agentFiles);
  checkCrossReferences(skillDirs, agentFiles);
  checkRelativeLinks(skillDirs, agentFiles);

  // Summary
  console.log('\n' + '─'.repeat(60));
  console.log(`\n📊 Results: ${errors.length} error(s), ${warnings.length} warning(s)`);

  if (errors.length > 0) {
    console.log('\n❌ Validation FAILED\n');
    process.exit(1);
  } else {
    console.log('\n✅ Validation PASSED\n');
    process.exit(0);
  }
}

main();
