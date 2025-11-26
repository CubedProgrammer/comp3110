import {exec} from 'child_process';

function getBranches(ret) {
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
