import fs from 'fs';
import path from 'path';
import {
  computeMapping,
  scoreMapping,
  printSummaries,
  mappingOptsFromEnv,
  readDiffOutputMapping,
  writeSummaries
} from './scoreUtils.js';

const PROF_DIR = path.join(process.cwd(), 'files', 'prof');
const OUTPUT_MAPPING_PATH = process.env.MAPPING_PATH || path.join(process.cwd(), 'outputs', 'diffOutput.txt');
const USE_DIFF_OUTPUT = process.env.USE_DIFF_OUTPUT === '1';
const OUTPUT_RESULTS_PATH = process.env.OUTPUT_RESULTS || path.join(process.cwd(), 'outputs', 'prof_scores.txt');

const main = () => {
  if (!fs.existsSync(PROF_DIR)) {
    console.warn(`Skipping professor scoring: missing directory ${PROF_DIR}`);
    return;
  }

  const xmlFiles = fs.readdirSync(PROF_DIR).filter((file) => file.endsWith('.xml') && !file.endsWith('.xml~'));
  const summaries = [];
  const mappingOpts = mappingOptsFromEnv();

  for (const xmlFile of xmlFiles) {
    const parsed = parseTestCase(path.join(PROF_DIR, xmlFile));
    if (!parsed) continue;

    const { baseName, extension, versions } = parsed;
    const baseVersionNumber = Math.min(...versions.map((v) => v.number));
    const basePath = path.join(PROF_DIR, `${baseName}_${baseVersionNumber}${extension}`);

    if (!fs.existsSync(basePath)) {
      console.warn(`Skipping ${xmlFile}: missing base file ${basePath}`);
      continue;
    }

    for (const version of versions) {
      if (version.number === baseVersionNumber) continue;

      const targetPath = path.join(PROF_DIR, `${baseName}_${version.number}${extension}`);
      if (!fs.existsSync(targetPath)) {
        console.warn(`Skipping ${xmlFile} version ${version.number}: missing file ${targetPath}`);
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
        mapping = computeMapping(basePath, targetPath, mappingOpts);
      }

      const score = scoreMapping(mapping, version.locations);

      summaries.push({
        test: `${baseName}_${version.number}`,
        file: xmlFile,
        base: baseVersionNumber,
        version: version.number,
        ...score,
      });
    }
  }

  printSummaries(summaries);
  writeSummaries(OUTPUT_RESULTS_PATH, summaries);
};

const parseTestCase = (xmlPath) => {
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
};

main();
