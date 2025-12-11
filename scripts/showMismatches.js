import fs from 'fs';
import path from 'path';
import {
  computeMapping,
  decodeTextFile,
  mappingOptsFromEnv,
  readDiffOutputMapping
} from './scoreUtils.js';

const DATASET = (process.argv[2] || 'prof').toLowerCase(); // 'prof' | 'answers'
const FILTER = process.argv[3] || null; // test name filter
const VERSION_FILTER = process.argv[4] ? parseInt(process.argv[4], 10) : null; // prof version number
const LIMIT = process.argv[5] ? parseInt(process.argv[5], 10) : 20;
const THRESHOLD = process.env.THRESHOLD ? parseFloat(process.env.THRESHOLD) : 0.75;
const OUTPUT_MAPPING_PATH = process.env.MAPPING_PATH || path.join(process.cwd(), 'outputs', 'diffOutput.txt');
const USE_DIFF_OUTPUT = process.env.USE_DIFF_OUTPUT === '1';

if (!['prof', 'answers'].includes(DATASET)) {
  console.error("Usage: node scripts/showMismatches.js <prof|answers> [testName] [versionNumberForProf] [limit]");
  process.exit(1);
}

if (DATASET === 'prof') {
  showProfMismatches();
} else {
  showAnswerKeyMismatches();
}

function showProfMismatches() {
  const PROF_DIR = path.join(process.cwd(), 'files', 'prof');
  if (!fs.existsSync(PROF_DIR)) {
    console.warn(`Skipping prof mismatches: missing directory ${PROF_DIR}`);
    return;
  }
  const xmlFiles = fs.readdirSync(PROF_DIR).filter((file) => file.endsWith('.xml') && !file.endsWith('.xml~'));
  const mappingOpts = mappingOptsFromEnv();
  const mappedFromOutput = USE_DIFF_OUTPUT ? readDiffOutputMapping(OUTPUT_MAPPING_PATH) : null;

  for (const xmlFile of xmlFiles) {
    const baseName = path.basename(xmlFile, '.xml');
    if (FILTER && baseName !== FILTER && xmlFile !== FILTER) continue;

    const parsed = parseProfTest(path.join(PROF_DIR, xmlFile));
    if (!parsed) continue;

    const { baseName: testName, extension, versions } = parsed;
    const baseVersion = Math.min(...versions.map((v) => v.number));
    const basePath = path.join(PROF_DIR, `${testName}_${baseVersion}${extension}`);
    if (!fs.existsSync(basePath)) {
      console.warn(`Missing base file ${basePath} for ${xmlFile}`);
      continue;
    }

    for (const version of versions) {
      if (version.number === baseVersion) continue;
      if (VERSION_FILTER !== null && version.number !== VERSION_FILTER) continue;

      const targetPath = path.join(PROF_DIR, `${testName}_${version.number}${extension}`);
      if (!fs.existsSync(targetPath)) {
        console.warn(`Missing version file ${targetPath} for ${xmlFile}`);
        continue;
      }

      let mapping = mappedFromOutput;
      if (!mapping) {
        mapping = computeMapping(basePath, targetPath, { threshold: THRESHOLD, ...mappingOpts });
      }
      const mismatches = collectMismatches(mapping, version.locations);
      printMismatches(`${testName}_${version.number}`, mismatches);
    }
  }
}

function parseProfTest(xmlPath) {
  const xml = fs.readFileSync(xmlPath, 'utf-8');
  const testMatch = /<TEST[^>]*NAME="[^"]+"[^>]*FILE="([^"]+)"[^>]*>/i.exec(xml);
  if (!testMatch) return null;

  const fileName = testMatch[1];
  const extension = path.extname(fileName) || '.java';
  const baseName = path.basename(fileName, extension);

  const versions = [];
  const versionRegex = /<VERSION[^>]*NUMBER="(\d+)"[^>]*>([\s\S]*?)<\/VERSION>/gi;
  let versionMatch;
  while ((versionMatch = versionRegex.exec(xml)) !== null) {
    const number = parseInt(versionMatch[1], 10);
    const body = versionMatch[2];
    const locations = [];

    const locationRegex = /<LOCATION[^>]*ORIG="(-?\d+)"[^>]*NEW="(-?\d+)"[^>]*\/>/gi;
    let locMatch;
    while ((locMatch = locationRegex.exec(body)) !== null) {
      locations.push({
        orig: parseInt(locMatch[1], 10),
        newLine: parseInt(locMatch[2], 10),
      });
    }

    versions.push({ number, locations });
  }

  if (!versions.length) return null;
  return { baseName, extension, versions };
}

function showAnswerKeyMismatches() {
  const ANSWER_DIR = path.join(process.cwd(), 'answer_keys');
  const FILES_DIR = path.join(process.cwd(), 'files');
  if (!fs.existsSync(ANSWER_DIR)) {
    console.warn(`Skipping answers mismatches: missing directory ${ANSWER_DIR}`);
    return;
  }
  if (!fs.existsSync(FILES_DIR)) {
    console.warn(`Skipping answers mismatches: missing directory ${FILES_DIR}`);
    return;
  }
  const answerFiles = fs.readdirSync(ANSWER_DIR).filter((file) => /^test-\d+-diff\.txt$/.test(file));
  answerFiles.sort();
  const mappingOpts = mappingOptsFromEnv();
  const mappedFromOutput = USE_DIFF_OUTPUT ? readDiffOutputMapping(OUTPUT_MAPPING_PATH) : null;

  for (const ansFile of answerFiles) {
    const testName = ansFile.replace(/-diff\.txt$/, '');
    if (FILTER && FILTER !== testName && FILTER !== ansFile) continue;

    const testDir = path.join(FILES_DIR, testName);
    const files = fs.readdirSync(testDir).filter((f) => fs.statSync(path.join(testDir, f)).isFile()).sort();
    if (files.length < 2) {
      console.warn(`Skipping ${ansFile}: expected at least two files in ${testDir}`);
      continue;
    }

    const [oldPath, newPath] = [path.join(testDir, files[0]), path.join(testDir, files[1])];
    const locations = parseAnswerKey(path.join(ANSWER_DIR, ansFile)).filter((loc) => loc.orig > 0);
    if (!locations.length) {
      console.warn(`Skipping ${ansFile}: no parsable locations`);
      continue;
    }

    let mapping = mappedFromOutput;
    if (!mapping) {
      mapping = computeMapping(oldPath, newPath, { threshold: THRESHOLD, ...mappingOpts });
    }
    const mismatches = collectMismatches(mapping, locations);
    printMismatches(testName, mismatches);
  }
}

function parseAnswerKey(filePath) {
  const text = decodeTextFile(filePath);
  const lines = text.split(/\r?\n/);
  const locations = [];

  for (const rawLine of lines) {
    const line = rawLine.replace(/^\uFEFF/, '').trim();
    if (!line.length) continue;
    let match = /old\s*:?\s*(-?\d+)\s+new\s*:?\s*(-?\d+)/i.exec(line);
    if (!match) match = /(-?\d+)\s+(-?\d+)/.exec(line);
    if (!match) continue;
    locations.push({
      orig: parseInt(match[1], 10),
      newLine: parseInt(match[2], 10),
    });
  }
  return locations;
}

function collectMismatches(mapping, expectedLocations) {
  const mismatches = [];
  for (const { orig, newLine } of expectedLocations) {
    const predicted = mapping.get(orig) ?? -1;
    if (newLine === predicted) continue;
    if (newLine === -1 && predicted !== -1) {
      mismatches.push(`spurious: old ${orig} expected deleted, mapped to ${predicted}`);
    } else if (newLine !== -1 && predicted === -1) {
      mismatches.push(`elim: old ${orig} expected ${newLine}, mapped to -1`);
    } else {
      mismatches.push(`change: old ${orig} expected ${newLine}, mapped to ${predicted}`);
    }
  }
  return mismatches;
}

function printMismatches(label, mismatches) {
  const total = mismatches.length;
  console.log(`\n${label}: mismatches=${total}${total > 0 ? ` (showing up to ${LIMIT})` : ''}`);
  if (!total) return;
  mismatches.slice(0, LIMIT).forEach((m) => console.log(`  ${m}`));
}
