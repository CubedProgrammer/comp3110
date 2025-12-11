import fs from 'fs';
import path from 'path';

export const decodeTextFile = (filePath) => {
  const buf = fs.readFileSync(filePath);
  const hasNulls = buf.includes(0);
  return buf.toString(hasNulls ? 'utf16le' : 'utf8');
};

// Parse a mapping file emitted by differenceChecker (format: "old: X new: Y" per line).
export const readDiffOutputMapping = (filePath) => {
  if (!fs.existsSync(filePath)) return null;
  const text = decodeTextFile(filePath);
  const mapping = new Map();
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line) continue;
    const match = /old\s*:?\s*(-?\d+)\s+new\s*:?\s*(-?\d+)/i.exec(line);
    if (!match) continue;
    const orig = parseInt(match[1], 10);
    const dest = parseInt(match[2], 10);
    if (Number.isNaN(orig) || Number.isNaN(dest)) continue;
    mapping.set(orig, dest);
  }
  return mapping.size ? mapping : null;
};

// Read mapping parameters from environment so scoring/mismatch scripts can be tuned without code edits.
export const mappingOptsFromEnv = () => {
  const readNum = (key) => {
    if (!(key in process.env)) return undefined;
    const v = parseFloat(process.env[key]);
    return Number.isFinite(v) ? v : undefined;
  };
  const readInt = (key) => {
    if (!(key in process.env)) return undefined;
    const v = parseInt(process.env[key], 10);
    return Number.isInteger(v) ? v : undefined;
  };

  const opts = {
    threshold: readNum('THRESHOLD'),
    gapPenalty: readNum('GAP_PENALTY'),
    diagBonus: readNum('DIAG_BONUS'),
    offsetPenalty: readNum('OFFSET_PENALTY'),
    tinyPenalty: readNum('TINY_PENALTY'),
    maxTinyLength: readInt('MAX_TINY_LENGTH'),
    band: readInt('BAND'),
  };

  // Strip undefined to avoid overriding defaults.
  return Object.fromEntries(Object.entries(opts).filter(([, v]) => v !== undefined));
};

export const readFileLines = (filePath) => decodeTextFile(filePath).split(/\r?\n/);

export const isSimilar = (line1, line2, threshold = 0.65) => similarityScore(line1, line2) >= threshold;

export const findMatchIndex = (line, file, usedIndices = new Set(), opts = {}, preferIndex = 0) => {
  if (!line) return -1;

  const trimmed = line.trim();
  const isTiny = trimmed.length <= 1 || /^[{}()[\\];]+$/.test(trimmed);
  const nearThreshold = opts.threshold ?? 0.6;
  const farThreshold = opts.farThreshold ?? 0.5;
  const window = opts.window ?? 5;
  const maxDistance = opts.maxDistance ?? 80;

  const start = Math.max(0, preferIndex - window);
  const end = Math.min(file.length - 1, preferIndex + window);

  let bestIndex = -1;
  let bestScore = 0;

  const consider = (i, threshold) => {
    if (usedIndices.has(i)) return;
    const score = similarityScore(line, file[i]);
    if (score >= threshold && score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  };

  // Exact in small window
  for (let i = start; i <= end; i++) {
    if (usedIndices.has(i)) continue;
    if (line === file[i]) return i;
  }

  // Similar in small window
  for (let i = start; i <= end; i++) consider(i, nearThreshold);
  if (bestIndex !== -1) return bestIndex;

  // Tiny lines should not be matched far away
  if (isTiny) return -1;

  // Exact match anywhere (safe)
  for (let i = 0; i < file.length; i++) {
    if (usedIndices.has(i)) continue;
    if (line === file[i]) return i;
  }

  // Similar within a bounded window
  const farStart = Math.max(0, preferIndex - maxDistance);
  const farEnd = Math.min(file.length - 1, preferIndex + maxDistance);
  for (let i = farStart; i <= farEnd; i++) {
    if (i >= start && i <= end) continue;
    consider(i, farThreshold);
  }

  return bestIndex;
};

export const computeMapping = (oldPath, newPath, opts = {}) => {
  const oldFile = readFileLines(oldPath);
  const newFile = readFileLines(newPath);

  const threshold = opts.threshold ?? 0.6;
  const gapPenalty = opts.gapPenalty ?? 0.25;
  const diagBonus = opts.diagBonus ?? 0.3; // encourage near-diagonal matches
  const offsetPenalty = opts.offsetPenalty ?? 0.01; // discourage far jumps
  const tinyPenalty = opts.tinyPenalty ?? 0.2; // discourage matching braces/empties
  const maxTinyLength = opts.maxTinyLength ?? 2;
  const band = opts.band ?? 200; // only compute similarities within this offset

  const n = oldFile.length;
  const m = newFile.length;
  const NEG = -1e9;

  const oldNorm = oldFile.map(normalizeLine);
  const newNorm = newFile.map(normalizeLine);
  const oldTiny = oldFile.map((l) => isTinyLine(l, maxTinyLength));
  const newTiny = newFile.map((l) => isTinyLine(l, maxTinyLength));
  const oldPrefix = oldFile.map(getPrefix);
  const newPrefix = newFile.map(getPrefix);
  const simCache = new Map();

  const scoreMatch = (i, j) => {
    const key = `${i},${j}`;
    if (simCache.has(key)) return simCache.get(key);

    const rawLine = oldFile[i];
    const newLine = newFile[j];

    let sim = 0;
    if (rawLine === newLine) {
      sim = 1;
    } else if (oldPrefix[i] && oldPrefix[i] === newPrefix[j]) {
      sim = 0.9;
    } else if (oldNorm[i] === newNorm[j] && oldNorm[i].length > 0) {
      sim = 0.95;
    } else {
      const normSim = levenshteinSim(oldNorm[i], newNorm[j]);
      sim = normSim;
    }

    if (sim < threshold) {
      simCache.set(key, NEG);
      return NEG;
    }

    const tiny = oldTiny[i] || newTiny[j];
    const positionalBonus = Math.max(diagBonus - offsetPenalty * Math.abs(i - j), 0);
    let score = sim + positionalBonus - (tiny ? tinyPenalty : 0);
    // If the penalties drop it below threshold, treat as unusable.
    if (score < threshold - 0.1) score = NEG;
    simCache.set(key, score);
    return score;
  };

  const dp = Array.from({ length: n + 1 }, () => new Array(m + 1).fill(NEG));
  const move = Array.from({ length: n + 1 }, () => new Array(m + 1).fill(null));
  dp[0][0] = 0;

  for (let i = 1; i <= n; i++) {
    dp[i][0] = dp[i - 1][0] - gapPenalty;
    move[i][0] = 'up';
  }
  for (let j = 1; j <= m; j++) {
    dp[0][j] = dp[0][j - 1] - gapPenalty;
    move[0][j] = 'left';
  }

  for (let i = 1; i <= n; i++) {
    for (let j = 1; j <= m; j++) {
      let bestScore = dp[i - 1][j] - gapPenalty;
      let bestMove = 'up';

      const leftScore = dp[i][j - 1] - gapPenalty;
      if (leftScore > bestScore) {
        bestScore = leftScore;
        bestMove = 'left';
      }

      let matchScore = NEG;
      if (Math.abs(i - j) <= band) {
        matchScore = scoreMatch(i - 1, j - 1);
        if (matchScore > NEG / 2) {
          const diagScore = dp[i - 1][j - 1] + matchScore;
          if (diagScore >= bestScore) {
            bestScore = diagScore;
            bestMove = 'diag';
          }
        }
      }

      dp[i][j] = bestScore;
      move[i][j] = bestMove;
    }
  }

  const mapping = new Map();
  let i = n;
  let j = m;

  while (i > 0 || j > 0) {
    const step = move[i][j];
    if (step === 'diag') {
      mapping.set(i, j);
      i -= 1;
      j -= 1;
    } else if (step === 'up') {
      mapping.set(i, -1);
      i -= 1;
    } else {
      j -= 1;
    }
  }

  for (let line = 1; line <= n; line++) {
    if (!mapping.has(line)) mapping.set(line, -1);
  }

  return mapping;
};

export const scoreMapping = (mapping, expectedLocations) => {
  let change = 0;
  let spurious = 0;
  let elim = 0;
  let correct = 0;

  for (const { orig, newLine } of expectedLocations) {
    const predicted = mapping.get(orig) ?? -1;

    if (newLine === -1 && predicted !== -1) {
      spurious += 1;
    } else if (newLine !== -1 && predicted === -1) {
      elim += 1;
    } else if (newLine !== -1 && predicted !== newLine) {
      change += 1;
    } else {
      correct += 1;
    }
  }

  const total = expectedLocations.length;
  return { change, spurious, elim, correct, total };
};

export const printSummaries = (summaries) => {
  const lines = formatSummaries(summaries);
  for (const line of lines) console.log(line);
};

export const writeSummaries = (outPath, summaries) => {
  const lines = formatSummaries(summaries);
  const dir = path.dirname(outPath);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(outPath, lines.join('\n'), 'utf8');
};

export const formatSummaries = (summaries) => {
  const lines = [];
  let totalChange = 0;
  let totalSpurious = 0;
  let totalElim = 0;
  let totalCorrect = 0;
  let total = 0;

  for (const s of summaries) {
    totalChange += s.change;
    totalSpurious += s.spurious;
    totalElim += s.elim;
    totalCorrect += s.correct;
    total += s.total;
    const accuracy = s.total ? ((s.correct / s.total) * 100).toFixed(1) : '0.0';
    lines.push(
      `${s.test}: correct=${s.correct}/${s.total}, change=${s.change}, spurious=${s.spurious}, elim=${s.elim}, accuracy=${accuracy}%`
    );
  }

  if (summaries.length) {
    const accuracy = total ? ((totalCorrect / total) * 100).toFixed(1) : '0.0';
    lines.push(
      '',
      `Overall: correct=${totalCorrect}/${total}, change=${totalChange}, spurious=${totalSpurious}, elim=${totalElim}, accuracy=${accuracy}%`
    );
  } else {
    lines.push('No test cases processed.');
  }

  return lines;
};

const normalizeLine = (line) => {
  if (!line) return '';
  return line
    .replace(/"[^"]*"/g, ' STR ')
    .replace(/'[^']*'/g, ' CHR ')
    .replace(/[^\w\.]+/g, ' ')
    .replace(/\./g, ' ')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
};

const isTinyLine = (line, maxTinyLength = 2) => {
  if (!line) return true;
  const trimmed = line.trim();
  return (
    trimmed.length === 0 ||
    trimmed.length <= maxTinyLength ||
    /^[{}()[\\];]+$/.test(trimmed)
  );
};

const similarityScore = (line1, line2) => {
  if (line1 === line2) return 1;

  const prefix1 = getPrefix(line1);
  const prefix2 = getPrefix(line2);
  if (prefix1 && prefix1 === prefix2) return 0.9;

  const raw = levenshteinSim(line1, line2);
  const norm = levenshteinSim(normalizeLine(line1), normalizeLine(line2));
  return Math.max(raw, norm);
};

const getPrefix = (line) => {
  const idx = line.indexOf('(');
  if (idx === -1) return '';
  return line.slice(0, idx).trim();
};

const levenshteinSim = (line1, line2) => {
  const len1 = line1.length;
  const len2 = line2.length;
  if (len1 === 0 && len2 === 0) return 1;
  if (len1 === 0 || len2 === 0) return 0;
  const dp = Array.from({ length: len1 + 1 }, () => new Array(len2 + 1).fill(0));
  for (let i = 0; i <= len1; i++) dp[i][0] = i;
  for (let j = 0; j <= len2; j++) dp[0][j] = j;
  for (let i = 1; i <= len1; i++) {
    for (let j = 1; j <= len2; j++) {
      const cost = line1[i - 1] === line2[j - 1] ? 0 : 1;
      dp[i][j] = Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost);
    }
  }
  const distance = dp[len1][len2];
  const maxLen = Math.max(len1, len2);
  return 1 - distance / maxLen;
};
