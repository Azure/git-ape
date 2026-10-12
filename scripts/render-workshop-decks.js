#!/usr/bin/env node
/**
 * render-workshop-decks.js
 *
 * Renders Marp workshop decks (workshops/track-*\/<N>_<name>_deck.md) to
 * HTML, PDF, and PPTX. Pre-flight lints each deck against the workshop deck
 * quality rules (L1, L11, L15) captured in the marp-deck-playbook.
 *
 * Usage:
 *   node scripts/render-workshop-decks.js              # render all decks
 *   node scripts/render-workshop-decks.js --only T2,T3 # render only specific tracks
 *   node scripts/render-workshop-decks.js --verbose
 *
 * Exit codes:
 *   0  all decks rendered successfully
 *   2  lint failure (caller must fix the deck.md, not retry)
 *   3  render failure (caller may retry; usually a tooling issue)
 *
 * This script is idempotent. It NEVER modifies deck.md; if a deck.md fails
 * lint (e.g., trailing ---) the script fails fast so a human can fix it and
 * the auto-PR workflow doesn't trigger an infinite rebuild loop.
 *
 * See: workshops/AUTO-GENERATION.md
 * Lessons referenced: L1 (external SVG), L8 (render all 3 formats), L11
 * (separate comment blocks), L15 (no trailing ---).
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const WORKSHOPS_DIR = path.join(ROOT, 'workshops');
// Pinned to an exact version (not a caret range) so deck renders are
// reproducible — a Marp minor/patch release cannot silently change output.
const MARP_VERSION = '@marp-team/marp-cli@4.4.0';

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const args = { only: null, verbose: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--only' && argv[i + 1]) {
      args.only = argv[++i].split(',').map((s) => s.trim().toUpperCase());
    } else if (a.startsWith('--only=')) {
      args.only = a.slice('--only='.length).split(',').map((s) => s.trim().toUpperCase());
    } else if (a === '--verbose' || a === '-v') {
      args.verbose = true;
    } else if (a === '--help' || a === '-h') {
      console.log('Usage: node scripts/render-workshop-decks.js [--only T1,T2] [--verbose]');
      process.exit(0);
    }
  }
  return args;
}

// ---------------------------------------------------------------------------
// Deck discovery
// ---------------------------------------------------------------------------

function discoverDecks(onlyFilter) {
  if (!fs.existsSync(WORKSHOPS_DIR)) {
    throw new Error(`workshops directory not found at ${WORKSHOPS_DIR}`);
  }
  const decks = [];
  const trackDirs = fs
    .readdirSync(WORKSHOPS_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory() && d.name.startsWith('track-'))
    .map((d) => path.join(WORKSHOPS_DIR, d.name));

  for (const trackDir of trackDirs) {
    // Match <N>_<name>_deck.md, where N is 1-9
    const candidates = fs
      .readdirSync(trackDir)
      .filter((f) => /^[1-9]_[a-z0-9-]+_deck\.md$/.test(f));
    if (candidates.length === 0) continue;
    if (candidates.length > 1) {
      throw new Error(
        `Multiple deck source files in ${trackDir}: ${candidates.join(', ')}. Expected exactly one.`
      );
    }
    const deckFile = candidates[0];
    const match = /^(\d+)_([a-z0-9-]+)_deck\.md$/.exec(deckFile);
    const trackNum = match[1];
    const trackSlug = match[2];
    const trackId = `T${trackNum}`;
    if (onlyFilter && !onlyFilter.includes(trackId)) continue;
    decks.push({
      trackId,
      trackNum,
      trackSlug,
      trackDir,
      deckPath: path.join(trackDir, deckFile),
      deckBaseName: deckFile.replace(/\.md$/, ''),
    });
  }
  decks.sort((a, b) => a.trackNum.localeCompare(b.trackNum));
  return decks;
}

// ---------------------------------------------------------------------------
// Lint pass (fail-fast before render)
// ---------------------------------------------------------------------------

function lintDeck(deck) {
  const text = fs.readFileSync(deck.deckPath, 'utf8');
  const issues = [];

  // Strip fenced code blocks and inline-code spans so lint rules don't
  // misfire on documentation about HTML/SVG inside the deck.
  const noCode = text
    .replace(/```[\s\S]*?```/g, '')
    .replace(/`[^`\n]*`/g, '');

  // L15: trailing `---` at end of file creates an empty extra slide.
  // Match a `---` line at the very end (allowing trailing whitespace).
  if (/(?:^|\r?\n)---[ \t]*\r?\n?\s*$/.test(text)) {
    issues.push({
      rule: 'L15',
      message: 'Trailing "---" at end of deck.md creates an empty extra slide. Remove it.',
    });
  }

  // L1: inline <svg> blocks are forbidden outside fenced code. SVGs must be
  // externalised to workshops/shared/img/*.svg and referenced via <img src=...>.
  if (/<svg\b[^>]*>/.test(noCode)) {
    issues.push({
      rule: 'L1',
      message:
        'Inline <svg> blocks found in deck.md. Externalise to workshops/shared/img/<name>.svg and reference via <img src="../shared/img/...">.',
    });
  }

  // L11: a Marp class directive (<!-- _class: ... -->) on the same comment
  // block as speaker-note prose causes the directive to be eaten. Heuristic:
  // a comment body that begins with `_class:` and also contains a sentence-ish
  // word run (5+ consecutive letters/spaces) after the directive token.
  const commentBodies = (noCode.match(/<!--[\s\S]*?-->/g) || []).map((c) =>
    c.replace(/^<!--/, '').replace(/-->$/, '').trim()
  );
  for (const body of commentBodies) {
    if (/^_class:\s*\S+/.test(body)) {
      const afterDirective = body.replace(/^_class:\s*\S+\s*/, '');
      // Real prose after the directive (long word run, not just whitespace/punct)
      if (/[A-Za-z]{5,}(\s+[A-Za-z]{3,}){2,}/.test(afterDirective)) {
        issues.push({
          rule: 'L11',
          message:
            'A Marp directive (<!-- _class: ... -->) is combined with speaker-note prose in the same comment block. Put the directive on its own <!-- _class: ... --> line and the notes on a separate <!-- ... --> block.',
        });
        break;
      }
    }
  }

  return issues;
}

// ---------------------------------------------------------------------------
// Render one deck (all three formats)
// ---------------------------------------------------------------------------

function runMarp(deck, format, log) {
  // We invoke marp via npx so CI has a clean dependency-free entry point.
  // The version is pinned (MARP_VERSION) to prevent CI drift across releases.
  const args = [
    '--yes',
    '-p',
    MARP_VERSION,
    'marp',
    deck.deckPath,
    `--${format}`,
    '--allow-local-files',
  ];
  log(`  marp --${format}  ${path.relative(ROOT, deck.deckPath)}`);
  const result = spawnSync('npx', args, {
    cwd: deck.trackDir,
    stdio: ['ignore', 'pipe', 'pipe'],
    encoding: 'utf8',
  });
  if (result.status !== 0) {
    process.stderr.write(result.stdout || '');
    process.stderr.write(result.stderr || '');
    throw new Error(`marp --${format} failed for ${deck.deckPath} (exit ${result.status})`);
  }
}

function renderDeck(deck, log) {
  log(`▶ ${deck.trackId}  ${path.relative(ROOT, deck.deckPath)}`);
  for (const fmt of ['html', 'pdf', 'pptx']) {
    runMarp(deck, fmt, log);
  }
  // Sanity-check outputs exist and are non-empty
  for (const ext of ['html', 'pdf', 'pptx']) {
    const out = path.join(deck.trackDir, `${deck.deckBaseName}.${ext}`);
    if (!fs.existsSync(out) || fs.statSync(out).size === 0) {
      throw new Error(`Expected output missing or empty: ${out}`);
    }
  }
  log(`✓ ${deck.trackId}  rendered html + pdf + pptx`);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  const args = parseArgs(process.argv.slice(2));
  const log = args.verbose ? (m) => console.log(m) : () => {};

  const decks = discoverDecks(args.only);
  if (decks.length === 0) {
    console.log('No matching decks found.');
    process.exit(0);
  }

  console.log(`Found ${decks.length} deck(s) to render: ${decks.map((d) => d.trackId).join(', ')}`);

  // ── Pre-flight lint pass — fail fast, do not modify any files ───────────
  let totalIssues = 0;
  for (const deck of decks) {
    const issues = lintDeck(deck);
    if (issues.length > 0) {
      console.error(`\n✗ ${deck.trackId}  lint failed (${path.relative(ROOT, deck.deckPath)}):`);
      for (const issue of issues) {
        console.error(`    [${issue.rule}] ${issue.message}`);
      }
      totalIssues += issues.length;
    }
  }
  if (totalIssues > 0) {
    console.error(`\nFix ${totalIssues} lint issue(s) above and re-run.`);
    process.exit(2);
  }

  // ── Render pass ─────────────────────────────────────────────────────────
  for (const deck of decks) {
    try {
      renderDeck(deck, log);
    } catch (err) {
      console.error(`\n✗ ${deck.trackId}  render failed: ${err.message}`);
      process.exit(3);
    }
  }

  console.log(`\nAll ${decks.length} deck(s) rendered.`);
}

if (require.main === module) {
  main();
}

module.exports = { discoverDecks, lintDeck };
