import { exec } from 'child_process';
import { promisify } from 'util';

// Minimal SZZ-style helper: given a fix commit hash, find likely bug-introducing commits
// by blaming lines deleted in the fix. This does not touch core diff logic.
const execAsync = promisify(exec);

const FIX_PATTERNS = [
  /\bfix(?:es|ed|ing)?\b/i,
  /\bbug\b/i,
  /\bregression\b/i,
  /\bhotfix\b/i,
  /\bpatch\b/i,
  /(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#\d+/i
];

const main = async () => {
  const [, , maybeHash] = process.argv;
  if (!maybeHash) {
    const fixes = await listFixCommits();
    if (!fixes.length) {
      console.log('No fix-like commits found.');
      return;
    }
    console.log('Recent fix-like commits (hash message):');
    fixes.slice(0, 10).forEach((c) => console.log(`${c.hash} ${c.message}`));
    console.log('\nRun: node scripts/bugIntro.js <fixHash>');
    return;
  }

  const fixHash = maybeHash;
  console.log(`Analyzing fix commit ${fixHash} ...`);
  const candidates = await findBugIntroducingCommits(fixHash);
  if (!candidates.length) {
    console.log('No candidate bug-introducing commits found.');
    return;
  }

  console.log('\nLikely bug-introducing commits (ranked by overlap):');
  candidates
    .sort((a, b) => b.score - a.score)
    .slice(0, 10)
    .forEach((c) => {
      console.log(`${c.hash} (${c.score}) ${c.message}`);
      Object.entries(c.files).forEach(([file, lines]) => {
        console.log(`  ${file}: ${lines.join(',')}`);
      });
    });
};

const listFixCommits = async () => {
  try {
    const { stdout } = await execAsync('git log --oneline');
    return stdout
      .trim()
      .split('\n')
      .map((line) => {
        const space = line.indexOf(' ');
        if (space === -1) return null;
        const hash = line.slice(0, space);
        const message = line.slice(space + 1);
        return FIX_PATTERNS.some((re) => re.test(message)) ? { hash, message } : null;
      })
      .filter(Boolean);
  } catch {
    return [];
  }
};

const findBugIntroducingCommits = async (fixHash) => {
  let diff = '';
  try {
    const { stdout } = await execAsync(`git diff --unified=0 --no-prefix ${fixHash}^ ${fixHash}`);
    diff = stdout;
  } catch {
    return [];
  }

  const deletions = parseDeletions(diff);
  const introMap = new Map();

  for (const { file, lines } of deletions) {
    for (const { start, end } of compressToRanges(lines)) {
      let blameOut = '';
      try {
        const { stdout } = await execAsync(`git blame ${fixHash}^ -L ${start},${end} -- ${file}`);
        blameOut = stdout;
      } catch {
        continue;
      }
      const blamed = parseBlame(blameOut);
      for (const { hash, line } of blamed) {
        if (!introMap.has(hash)) introMap.set(hash, { hash, files: new Map(), score: 0 });
        const entry = introMap.get(hash);
        if (!entry.files.has(file)) entry.files.set(file, new Set());
        entry.files.get(file).add(line);
        entry.score += 1;
      }
    }
  }

  const results = [];
  for (const entry of introMap.values()) {
    const files = {};
    for (const [file, set] of entry.files.entries()) {
      files[file] = Array.from(set).sort((a, b) => a - b);
    }
    const message = await getSubject(entry.hash);
    results.push({ hash: entry.hash, message, files, score: entry.score });
  }
  return results;
};

const getSubject = async (hash) => {
  try {
    const { stdout } = await execAsync(`git show -s --format=%s ${hash}`);
    return stdout.trim();
  } catch {
    return '';
  }
};

const parseDeletions = (diffText) => {
  const files = new Map();
  let currentFile = null;
  let oldLine = 0;

  for (const line of diffText.split('\n')) {
    if (line.startsWith('diff --git ')) {
      currentFile = null;
      continue;
    }
    if (line.startsWith('+++ ')) continue;
    if (line.startsWith('--- ')) {
      const filePath = line.slice(4).trim();
      currentFile = filePath === '/dev/null' ? null : filePath;
      continue;
    }
    if (!currentFile) continue;

    const hunkMatch = /@@ -(\d+),?(\d*) \+(\d+),?(\d*) @@/.exec(line);
    if (hunkMatch) {
      oldLine = parseInt(hunkMatch[1], 10);
      continue;
    }

    if (line.startsWith('-') && !line.startsWith('---')) {
      if (!files.has(currentFile)) files.set(currentFile, []);
      files.get(currentFile).push(oldLine);
      oldLine += 1;
      continue;
    }

    if (line.startsWith(' ') || line === '') {
      oldLine += 1;
    }
  }

  return Array.from(files.entries()).map(([file, lines]) => ({
    file,
    lines: Array.from(new Set(lines)).sort((a, b) => a - b),
  }));
};

const compressToRanges = (lines) => {
  if (!lines.length) return [];
  const sorted = Array.from(new Set(lines)).sort((a, b) => a - b);
  const ranges = [];
  let start = sorted[0];
  let prev = sorted[0];
  for (let i = 1; i < sorted.length; i++) {
    const curr = sorted[i];
    if (curr === prev + 1) {
      prev = curr;
      continue;
    }
    ranges.push({ start, end: prev });
    start = curr;
    prev = curr;
  }
  ranges.push({ start, end: prev });
  return ranges;
};

const parseBlame = (blameOutput) => {
  const blamed = [];
  for (const line of blameOutput.split('\n')) {
    const match = /^([0-9a-f]{7,40})\s+\([^\)]*\s+(\d+)\)/.exec(line);
    if (!match) continue;
    blamed.push({ hash: match[1], line: parseInt(match[2], 10) });
  }
  return blamed;
};

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
