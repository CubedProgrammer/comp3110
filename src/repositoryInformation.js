import {exec} from 'child_process';

export function getBranches(ret) {
	const callback = (e, stdout, stderr) => {
		if (e) {
			ret(e);
		} else {

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

			ret(null, lines, currentBranchIndex);

		}
	}
	exec('git branch', callback);
}

export function getCommits(ret) {
	const callback = (e, stdout, stderr) => {
		if (e) {
			ret(e);
		} else {
			
			const lns = stdout.split('\n')
			.filter((ln) => ln.length)
			.map((ln) => {
				return{hash: ln.substring(0, 7), msg: ln.substring(8)};
			});
			ret(null, lns);

		}
	}
	exec('git log --oneline', callback);
}

export function changeBranch(br, cb) {
	exec('git checkout ' + br, () => cb())
}
