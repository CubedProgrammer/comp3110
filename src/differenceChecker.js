export const DiffChecker = (filePath1, filePath2) => {
  const oldFile = readFileLines(filePath1);
  const newFile = readFileLines(filePath2);

  return parseDifferences(oldFile, newFile);
}

const readFileLines = (dat) => {
  return dat.split(/\r?\n/);
}

export const INSERTION = 97;
export const DELETION = 98;
export const MODIFICATION = 99;

const makeDiff = (t, msg) => {
  return { type: t, info: msg };
}

const parseDifferences = (oldFile, newFile) => {
  const differences = [];
  let currOldIndex = 0;
  let currNewIndex = 0;

  while (currOldIndex < oldFile.length || currNewIndex < newFile.length) {
    if (currOldIndex < oldFile.length && currNewIndex < newFile.length) {
      var line_split = oldFile[currOldIndex].includes(newFile[currNewIndex])
      var splits = [];
  
      var newStr = newFile[currNewIndex].trim()
  
      while (oldFile[currOldIndex].trim().includes(newFile[currNewIndex].trim())) {
        splits.push(currNewIndex + 1);
        currNewIndex++;

        if (currNewIndex >= newFile.length) break;
      }
  
      if (line_split && splits.length > 1) {
        differences.push(makeDiff(MODIFICATION, "Line " + (currOldIndex + 1) + " of old file has been split to lines " + splits.join(", ") + " of new file"));
        currOldIndex = currNewIndex;
        continue;
      }
      else if (line_split && splits.length == 1) {
        currNewIndex--;
      }
    }

    while(isNotPresentIn(oldFile[currOldIndex], newFile, currNewIndex) && currOldIndex < oldFile.length) {
      differences.push(makeDiff(DELETION, "Line " + (currOldIndex + 1) + " of old file has been removed"));
      currOldIndex++;
    }

    while(isNotPresentIn(newFile[currNewIndex], oldFile, currOldIndex) && currNewIndex < newFile.length) {
      differences.push(makeDiff(INSERTION, "Line " + (currNewIndex + 1) + " of new file has been added"));
      currNewIndex++;
    }

    if (oldFile[currOldIndex] == newFile[currNewIndex]) {
      currOldIndex++;
      currNewIndex++;
    }
    else {
      for (let index = currNewIndex; index < newFile.length; index++) {
        if (isSimilar(oldFile[currOldIndex], newFile[index])) {
          if (currOldIndex != index) differences.push(makeDiff(MODIFICATION, "Line " + (currOldIndex + 1) + " of old file has been changed/moved to line " + (index + 1) + " of new file"));
          else differences.push(makeDiff(MODIFICATION, "Line " + (currOldIndex + 1) + " has been modified"));
          break;
        }
      }
      currOldIndex++;
      currNewIndex++;
    }
  }

  return differences;
}

const isNotPresentIn = (line, file, startingIndex) => {
  if (!line) return true;

  for (let i = startingIndex || 0; i < file.length; i++) {
    const fLine = file[i];
    if (isSimilar(line, fLine)) {
      return false;
    }
  }
  return true;
}

const isSimilar = (line1, line2) => {
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

  return similarity >= 0.75;
};
