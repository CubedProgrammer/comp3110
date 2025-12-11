import fs from 'fs';

const DiffChecker = (filePath1, filePath2) => {
  const oldFile = readFileLines(filePath1);
  const newFile = readFileLines(filePath2);

  return parseDifferences(oldFile, newFile);
}

const readFileLines = (filePath) => {
  const fileContents = fs.readFileSync(filePath, 'utf-8');
  return fileContents.split(/\r?\n/);
}

const parseDifferences = (oldFile, newFile) => {
  const differences = [];
  var output = "";
  let currOldIndex = 0;
  let currNewIndex = 0;

  while (currOldIndex < oldFile.length && currNewIndex < newFile.length) {
    if (oldFile[currOldIndex].trim() === '') {
      currOldIndex++;
      continue;
    }

    // Check for split lines
    if (currOldIndex < oldFile.length && currNewIndex < newFile.length) {
      var splits = [];
  
      while (oldFile[currOldIndex].trim().includes(newFile[currNewIndex].trim())) {
        if (newFile[currNewIndex].trim() === '')
          break;
        
        splits.push(currNewIndex + 1);
        currNewIndex++;

        if (currNewIndex >= newFile.length) break;
      }
  
      if (splits.length > 1) {
        differences.push("/Line " + (currOldIndex + 1) + " of old file has been split to lines " + splits.join(", ") + " of new file");
        output += `old: ${currOldIndex + 1} new: ${splits.join(", ")}\n`;
        currOldIndex += 1;
        continue;
      }
      else if (splits.length == 1) {
        currNewIndex--;
      }
    }

    // Check for removed lines
    if (isNotPresentIn(oldFile[currOldIndex], newFile, currNewIndex) && currOldIndex < oldFile.length)
    {
      while(isNotPresentIn(oldFile[currOldIndex], newFile, currNewIndex) && currOldIndex < oldFile.length) {
        differences.push("-Line " + (currOldIndex + 1) + " of old file has been removed");
        output += `old: ${currOldIndex + 1} new: -1\n`;
        currOldIndex++;
      }
      continue;
    }

    // Check for same lines
    if (oldFile[currOldIndex] == newFile[currNewIndex] && currOldIndex === currNewIndex) {
      currOldIndex++;
      currNewIndex++;
    }
    else { // Modified or moved lines
      var similarity = 0
      var idx = currNewIndex
      for (let index = currNewIndex; index < newFile.length; index++) {
        var sim = getSimilarity(oldFile[currOldIndex], newFile[index]);
        if (sim > similarity) {
          similarity = sim;
          idx = index;
        }
      }

      var index = idx;
      if (currOldIndex != index) {
        differences.push("/Line " + (currOldIndex + 1) + " of old file has been changed/moved to line " + (index + 1) + " of new file");
        output += `old: ${currOldIndex + 1} new: ${index + 1}\n`;
      } 
      else {
        differences.push("/Line " + (currOldIndex + 1) + " has been modified");
        output += `old: ${currOldIndex + 1} new: ${index + 1}\n`;
      } 
      currOldIndex++;
    }
  }

  fs.writeFileSync('outputs/diffOutput.txt', output);

  return differences;
}

const isNotPresentIn = (line, file, startingIndex) => {
  if (line === null || line === undefined) return true;

  for (let i = startingIndex || 0; i < file.length; i++) {
    const fLine = file[i];
    if (isSimilar(line, fLine)) {
      return false;
    }
  }
  return true;
}

const isSimilar = (line1, line2) => {
  if (line1 === null || line1 === undefined) return false;
  if (line1 === line2) return true;

  const len1 = line1.length;
  const len2 = line2.length;

  if (len1 === 0 && len2 === 0) return true;
  if (len1 === 0 || len2 === 0) return false;

  const dp = Array.from({ length: len1 + 1 }, () => new Array(len2 + 1).fill(0));

  for (let i = 0; i <= len1; i++) dp[i][0] = i;
  for (let j = 0; j <= len2; j++) dp[0][j] = j;

  for (let i = 1; i <= len1; i++) {
    for (let j = 1; j <= len2; j++) {
      const cost = line1[i - 1] === line2[j - 1] ? 0 : 1;
      dp[i][j] = Math.min(
        dp[i - 1][j] + 1,      
        dp[i][j - 1] + 1,       
        dp[i - 1][j - 1] + cost 
      );
    }
  }

  const distance = dp[len1][len2];
  const maxLen = Math.max(len1, len2);
  const similarity = 1 - distance / maxLen;

  return similarity >= 0.50;
};

const getSimilarity = (line1, line2) => {
  if (line1 === null || line1 === undefined) return 0.0;
  if (line1 === line2) return 1.0;

  const len1 = line1.length;
  const len2 = line2.length;

  if (len1 === 0 && len2 === 0) return 1.0;
  if (len1 === 0 || len2 === 0) return 0.0;

  const dp = Array.from({ length: len1 + 1 }, () => new Array(len2 + 1).fill(0));

  for (let i = 0; i <= len1; i++) dp[i][0] = i;
  for (let j = 0; j <= len2; j++) dp[0][j] = j;

  for (let i = 1; i <= len1; i++) {
    for (let j = 1; j <= len2; j++) {
      const cost = line1[i - 1] === line2[j - 1] ? 0 : 1;
      dp[i][j] = Math.min(
        dp[i - 1][j] + 1,      
        dp[i][j - 1] + 1,       
        dp[i - 1][j - 1] + cost 
      );
    }
  }

  const distance = dp[len1][len2];
  const maxLen = Math.max(len1, len2);
  const similarity = 1 - distance / maxLen;

  return similarity;
};

export default DiffChecker;