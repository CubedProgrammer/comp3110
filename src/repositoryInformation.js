import {exec} from 'child_process';

export function getBranches(ret) {
  const callback = (stdout) => {
    const lines = stdout.split(/\\s+/);
    let currentBranchIndex = lines.length;
    for(let i = 0; i < lines.length; ++i) {
      if (lines[i].charAt(0) === '*') {
        currentBranchIndex = i;
        lines[i] = lines[i].substring(1).trim();
      } else {
        lines[i] = lines[i].trim();
      }
    }

    ret(null, [lines, currentBranchIndex]);
  }
  exec('git branch', getExecCallback(callback, ret));
}

export function getCommits(ret) {
  const callback = (stdout) => {
    const lns = stdout.split('\n')
    .filter((ln) => ln.length)
    .map((ln) => {
      return{hash: ln.substring(0, 7), msg: ln.substring(8)};
    });
    ret(null, lns);
  }
  exec('git log --oneline', getExecCallback(callback, ret));
}

export function getFiles(br, ret) {
  const callback = (stdout) => {
    const lns = stdout.split('\n').filter((ln) => ln.length);
    ret(null, lns.sort());
  }
  exec('git ls-tree -r --name-only ' + br, getExecCallback(callback, ret));
}

export function changeBranch(br, cb) {
  exec('git checkout ' + br, () => cb())
}

export const getBranchesAA = getAA(getBranches);
export const getCommitsAA = getAA(getCommits);
export const getFilesAA = getAA(getFiles);
export const changeBranchAA = getAA(changeBranch);

function getExecCallback(callback, ret) {
  function r(e, stdout, stderr) {
    if (e) {
      ret(e);
    } else {
      if (stderr.length > 0) {
        console.error(stderr);
      }
      callback(stdout);
    }
  }
  return r;
}

function getAA(f) {
  return (...args) => {
    const g = (resolve) => {
      const ret = (e, stdout) => {
        resolve(stdout);
      }
      f(...args, ret);
    }
    return new Promise(g);
  };
}
