import fs from 'fs';
import path from 'path';
import {
  computeMapping,
  decodeTextFile,
  scoreMapping,
  printSummaries,
  mappingOptsFromEnv,
  readDiffOutputMapping,
  writeSummaries
} from './scoreUtils.js';

const ANSWER_DIR = path.join(process.cwd(), 'answer_keys');
const FILES_DIR = path.join(process.cwd(), 'files');
const OUTPUT_MAPPING_PATH = process.env.MAPPING_PATH || path.join(process.cwd(), 'outputs', 'diffOutput.txt');
const USE_DIFF_OUTPUT = process.env.USE_DIFF_OUTPUT === '1';
const OUTPUT_RESULTS_PATH = process.env.OUTPUT_RESULTS || path.join(process.cwd(), 'outputs', 'answers_scores.txt');

const main = () => {
  if (!fs.existsSync(ANSWER_DIR)) {
    console.error(`Missing answer key directory: ${ANSWER_DIR}`);
    return;
  }
  if (!fs.existsSync(FILES_DIR)) {
    console.error(`Missing files directory: ${FILES_DIR}`);
    return;
  }

  const answerFiles = fs.readdirSync(ANSWER_DIR).filter((file) => /^test-\d+-diff\.txt$/.test(file));
  answerFiles.sort();
  const summaries = [];
  const mappingOpts = mappingOptsFromEnv();

  for (const ansFile of answerFiles) {
    const testName = ansFile.replace(/-diff\.txt$/, '');
    const testDir = path.join(FILES_DIR, testName);
    if (!fs.existsSync(testDir)) {
      console.warn(`Skipping ${ansFile}: missing directory ${testDir}`);
      continue;
    }
    const files = fs.readdirSync(testDir).filter((f) => fs.statSync(path.join(testDir, f)).isFile()).sort();

    if (files.length < 2) {
      console.warn(`Skipping ${ansFile}: expected at least two files in ${testDir}`);
      continue;
    }

    const [oldPath, newPath] = [
      path.join(testDir, files[0]),
      path.join(testDir, files[1])
    ];

    const locations = parseAnswerKey(path.join(ANSWER_DIR, ansFile));
    const expected = locations.filter((loc) => loc.orig > 0);
    if (!expected.length) {
      console.warn(`Skipping ${ansFile}: no parsable locations`);
      continue;
    }

    let mapping = null;
    if (USE_DIFF_OUTPUT) {
      mapping = readDiffOutputMapping(OUTPUT_MAPPING_PATH);
      if (!mapping) {
        console.warn(`USE_DIFF_OUTPUT=1 but no mapping at ${OUTPUT_MAPPING_PATH}; falling back to computeMapping`);
      }
    }

    if (!mapping) {
      mapping = computeMapping(oldPath, newPath, mappingOpts);
    }

    const score = scoreMapping(mapping, expected);

    summaries.push({
      test: testName,
      file: ansFile,
      base: files[0],
      version: files[1],
      ...score,
    });
  }

  printSummaries(summaries);
  writeSummaries(OUTPUT_RESULTS_PATH, summaries);
};

const parseAnswerKey = (filePath) => {
  const text = decodeTextFile(filePath);
  const lines = text.split(/\r?\n/);
  const locations = [];

  for (const rawLine of lines) {
    const line = rawLine.replace(/^\uFEFF/, '').trim();
    if (!line.length) continue;

    // Expected format: "old:X new:Y"
    let match = /old\s*:?\s*(-?\d+)\s+new\s*:?\s*(-?\d+)/i.exec(line);

    // Fallback: two integers on the line
    if (!match) {
      match = /(-?\d+)\s+(-?\d+)/.exec(line);
    }

    if (!match) continue;
    locations.push({
      orig: parseInt(match[1], 10),
      newLine: parseInt(match[2], 10),
    });
  }

  return locations;
};

main();
