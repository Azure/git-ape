#!/usr/bin/env node
/**
 * verify-workshop-decks.js
 *
 * Rasterizes each rendered workshop deck (PDF + PPTX) to per-slide PNGs so a
 * reviewer can visually verify the build before merge (L9: file size is NOT a
 * quality signal — only visual inspection catches contrast/overflow issues).
 *
 * Outputs go to .deck-screenshots/<trackId>/{pdf,pptx}/slide-NN.png.
 * A manifest .deck-screenshots/manifest.json maps every PNG to its source.
 *
 * Usage:
 *   node scripts/verify-workshop-decks.js              # all decks
 *   node scripts/verify-workshop-decks.js --only T2,T3
 *
 * Exit codes:
 *   0  rasterization completed for all decks
 *   3  tooling failure (ImageMagick or LibreOffice missing or errored)
 *
 * Required tooling:
 *   - ImageMagick (`magick`) with PDF delegate (Ghostscript)
 *   - LibreOffice (`soffice`) for PPTX -> PDF conversion
 *
 * Rendering quality is NOT a build failure here — the screenshots are the
 * reviewer's surface. This script only fails on tooling or I/O errors.
 *
 * See: workshops/AUTO-GENERATION.md
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const SCREENSHOT_DIR = path.join(ROOT, '.deck-screenshots');
const PDF_DENSITY = 110;

// Reuse deck discovery from the render script so both stay in lockstep.
const { discoverDecks } = require('./render-workshop-decks.js');

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
      console.log('Usage: node scripts/verify-workshop-decks.js [--only T1,T2] [--verbose]');
      process.exit(0);
    }
  }
  return args;
}

function which(cmd) {
  const r = spawnSync('which', [cmd], { encoding: 'utf8' });
  return r.status === 0 ? r.stdout.trim() : null;
}

function preflight() {
  const issues = [];
  if (!which('magick') && !which('convert')) {
    issues.push(
      'ImageMagick (`magick` or `convert`) is not installed. On macOS: `brew install imagemagick ghostscript`. On Ubuntu: `sudo apt install -y imagemagick ghostscript`.'
    );
  }
  if (!which('soffice') && !which('libreoffice')) {
    issues.push(
      'LibreOffice (`soffice` or `libreoffice`) is not installed. On macOS: `brew install --cask libreoffice`. On Ubuntu: `sudo apt install -y libreoffice`.'
    );
  }
  if (issues.length > 0) {
    for (const i of issues) console.error(`✗ ${i}`);
    process.exit(3);
  }
}

function magickCmd() {
  return which('magick') ? 'magick' : 'convert';
}

function sofficeCmd() {
  return which('soffice') ? 'soffice' : 'libreoffice';
}

// ---------------------------------------------------------------------------

function rmrf(p) {
  if (fs.existsSync(p)) fs.rmSync(p, { recursive: true, force: true });
}

function rasterizePdf(pdfPath, outDir, log) {
  fs.mkdirSync(outDir, { recursive: true });
  // `magick -density 110 deck.pdf slide-%02d.png` produces slide-00.png, slide-01.png, ...
  const args = ['-density', String(PDF_DENSITY), pdfPath, path.join(outDir, 'slide-%02d.png')];
  log(`  ${magickCmd()} ${args.join(' ')}`);
  const r = spawnSync(magickCmd(), args, { stdio: ['ignore', 'pipe', 'pipe'], encoding: 'utf8' });
  if (r.status !== 0) {
    process.stderr.write(r.stdout || '');
    process.stderr.write(r.stderr || '');
    throw new Error(`magick failed for ${pdfPath}`);
  }
  return collectSlidePngs(outDir);
}

function convertPptxToPdf(pptxPath, outDir, log) {
  fs.mkdirSync(outDir, { recursive: true });
  const args = ['--headless', '--convert-to', 'pdf', '--outdir', outDir, pptxPath];
  log(`  ${sofficeCmd()} ${args.join(' ')}`);
  const r = spawnSync(sofficeCmd(), args, { stdio: ['ignore', 'pipe', 'pipe'], encoding: 'utf8' });
  if (r.status !== 0) {
    process.stderr.write(r.stdout || '');
    process.stderr.write(r.stderr || '');
    throw new Error(`soffice failed for ${pptxPath}`);
  }
  // The output PDF has the same basename as the input pptx
  const baseName = path.basename(pptxPath, '.pptx');
  const pdfOut = path.join(outDir, `${baseName}.pdf`);
  if (!fs.existsSync(pdfOut)) throw new Error(`Expected PDF not produced: ${pdfOut}`);
  return pdfOut;
}

function collectSlidePngs(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((f) => /^slide-\d{2}\.png$/.test(f))
    .sort()
    .map((f) => path.join(dir, f));
}

// ---------------------------------------------------------------------------

function verifyDeck(deck, log) {
  const pdfPath = path.join(deck.trackDir, `${deck.deckBaseName}.pdf`);
  const pptxPath = path.join(deck.trackDir, `${deck.deckBaseName}.pptx`);
  if (!fs.existsSync(pdfPath) || !fs.existsSync(pptxPath)) {
    throw new Error(`Rendered files missing for ${deck.trackId}. Run render-workshop-decks.js first.`);
  }

  const trackOutDir = path.join(SCREENSHOT_DIR, deck.trackId);
  rmrf(trackOutDir); // Idempotent: clear stale screenshots from previous runs

  const pdfPngDir = path.join(trackOutDir, 'pdf');
  const pptxPngDir = path.join(trackOutDir, 'pptx');
  const pptxPdfDir = path.join(trackOutDir, '_pptx-as-pdf');

  console.log(`▶ ${deck.trackId}  rasterizing PDF`);
  const pdfSlides = rasterizePdf(pdfPath, pdfPngDir, log);

  console.log(`▶ ${deck.trackId}  converting PPTX → PDF → PNG`);
  const intermediatePdf = convertPptxToPdf(pptxPath, pptxPdfDir, log);
  const pptxSlides = rasterizePdf(intermediatePdf, pptxPngDir, log);
  rmrf(pptxPdfDir); // Don't litter the artifact with intermediate PDFs

  console.log(`✓ ${deck.trackId}  pdf=${pdfSlides.length} slides, pptx=${pptxSlides.length} slides`);

  return {
    trackId: deck.trackId,
    trackSlug: deck.trackSlug,
    deckBaseName: deck.deckBaseName,
    pdf: {
      source: path.relative(ROOT, pdfPath),
      slides: pdfSlides.map((p, i) => ({
        index: i,
        path: path.relative(ROOT, p),
      })),
    },
    pptx: {
      source: path.relative(ROOT, pptxPath),
      slides: pptxSlides.map((p, i) => ({
        index: i,
        path: path.relative(ROOT, p),
      })),
    },
  };
}

// ---------------------------------------------------------------------------

function main() {
  const args = parseArgs(process.argv.slice(2));
  const log = args.verbose ? (m) => console.log(m) : () => {};

  preflight();

  const decks = discoverDecks(args.only);
  if (decks.length === 0) {
    console.log('No matching decks found.');
    process.exit(0);
  }

  console.log(`Verifying ${decks.length} deck(s): ${decks.map((d) => d.trackId).join(', ')}`);

  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

  const entries = [];
  for (const deck of decks) {
    try {
      entries.push(verifyDeck(deck, log));
    } catch (err) {
      console.error(`\n✗ ${deck.trackId}  verification failed: ${err.message}`);
      process.exit(3);
    }
  }

  const manifest = {
    generated_at: new Date().toISOString(),
    pdf_density: PDF_DENSITY,
    decks: entries,
  };
  const manifestPath = path.join(SCREENSHOT_DIR, 'manifest.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2), 'utf8');

  console.log(`\nManifest written to ${path.relative(ROOT, manifestPath)}`);
  console.log(
    `Total PNGs: ${entries.reduce((sum, e) => sum + e.pdf.slides.length + e.pptx.slides.length, 0)}`
  );
}

if (require.main === module) {
  main();
}

module.exports = { verifyDeck };
