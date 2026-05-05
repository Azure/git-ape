#!/usr/bin/env node
/**
 * run-eval.js
 *
 * Minimal eval harness for Git-Ape agent/skill behavioral validation.
 * Validates that eval scenarios reference valid agents and skills
 * from the actual repository definitions.
 *
 * Usage: node evals/run-eval.js
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const WEBSITE_DIR = path.join(ROOT, 'website');
const matter = require(path.join(WEBSITE_DIR, 'node_modules', 'gray-matter'));

const AGENTS_DIR = path.join(ROOT, '.github', 'agents');
const SKILLS_DIR = path.join(ROOT, '.github', 'skills');
const SCENARIOS_DIR = path.join(__dirname, 'scenarios');

// ---------------------------------------------------------------------------
// Load repository definitions
// ---------------------------------------------------------------------------

function loadSkillNames() {
  return fs.readdirSync(SKILLS_DIR).filter((d) =>
    fs.statSync(path.join(SKILLS_DIR, d)).isDirectory()
  );
}

function loadAgentNames() {
  const files = fs.readdirSync(AGENTS_DIR).filter((f) => f.endsWith('.agent.md'));
  const names = [];
  for (const file of files) {
    const parsed = matter(fs.readFileSync(path.join(AGENTS_DIR, file), 'utf-8'));
    if (parsed.data.name) names.push(parsed.data.name);
  }
  return names;
}

// ---------------------------------------------------------------------------
// Eval runner
// ---------------------------------------------------------------------------

function runScenario(scenario, skillNames, agentNames) {
  const results = [];
  const scenarioId = scenario.id;

  // Check expected_agent exists
  if (scenario.expected_agent) {
    const pass = agentNames.includes(scenario.expected_agent);
    results.push({
      check: `Agent '${scenario.expected_agent}' exists`,
      pass,
    });
  }

  // Check expected_sub_agents exist
  if (scenario.expected_sub_agents) {
    for (const agent of scenario.expected_sub_agents) {
      const pass = agentNames.includes(agent);
      results.push({
        check: `Sub-agent '${agent}' exists`,
        pass,
      });
    }
  }

  // Check expected_skill_sequence references valid skills
  if (scenario.expected_skill_sequence) {
    for (const skill of scenario.expected_skill_sequence) {
      const pass = skillNames.includes(skill);
      results.push({
        check: `Skill '${skill}' exists`,
        pass,
      });
    }
  }

  // Check assertions reference valid entities
  if (scenario.assertions) {
    for (const assertion of scenario.assertions) {
      if (assertion.type === 'skill_invoked') {
        const pass = skillNames.includes(assertion.skill);
        results.push({
          check: `Assertion: skill '${assertion.skill}' exists`,
          pass,
        });
      }
      if (assertion.type === 'skill_order') {
        const passBefore = skillNames.includes(assertion.before);
        const passAfter = skillNames.includes(assertion.after);
        results.push({
          check: `Assertion: skills '${assertion.before}' → '${assertion.after}' exist`,
          pass: passBefore && passAfter,
        });
      }
      if (assertion.type === 'agent_delegates') {
        const passFrom = agentNames.includes(assertion.from);
        const passTo = agentNames.includes(assertion.to);
        results.push({
          check: `Assertion: agents '${assertion.from}' → '${assertion.to}' exist`,
          pass: passFrom && passTo,
        });
      }
    }
  }

  return { scenarioId, description: scenario.description, results };
}

function main() {
  console.log('🧪 Git-Ape Eval Runner\n');

  const skillNames = loadSkillNames();
  const agentNames = loadAgentNames();

  console.log(`   Skills: ${skillNames.length} found`);
  console.log(`   Agents: ${agentNames.length} found`);

  const scenarioFiles = fs.readdirSync(SCENARIOS_DIR).filter((f) => f.endsWith('.json'));
  console.log(`   Scenarios: ${scenarioFiles.length} found\n`);

  let totalPass = 0;
  let totalFail = 0;

  for (const file of scenarioFiles) {
    const scenario = JSON.parse(fs.readFileSync(path.join(SCENARIOS_DIR, file), 'utf-8'));
    const { scenarioId, description, results } = runScenario(scenario, skillNames, agentNames);

    console.log(`📋 Scenario: ${scenarioId}`);
    console.log(`   ${description}\n`);

    for (const r of results) {
      if (r.pass) {
        console.log(`   ✅ ${r.check}`);
        totalPass++;
      } else {
        console.log(`   ❌ ${r.check}`);
        totalFail++;
      }
    }
    console.log('');
  }

  console.log('─'.repeat(60));
  console.log(`\n📊 Results: ${totalPass} passed, ${totalFail} failed`);

  if (totalFail > 0) {
    console.log('\n❌ Evals FAILED\n');
    process.exit(1);
  } else {
    console.log('\n✅ All evals PASSED\n');
    process.exit(0);
  }
}

main();
