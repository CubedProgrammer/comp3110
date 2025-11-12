const DiffChecker = (filePath1, filePath2) => {
  const differeces = [];
  differeces.push(
    "-Sample line removed from file 1",
    "+Sample line added in file 2",
    "/Sample line changed/moved between files"
  );
  return differeces;
}

// need to implement the actual diff logic it should return an array of strings with +, - or / at the start
// + for additions, - for deletions, / for changes

export default DiffChecker;