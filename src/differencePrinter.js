import { log, spinner } from '@clack/prompts';
import { DELETION, INSERTION, MODIFICATION } from './differenceChecker.js';

const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));

const PrintDiff = async (differences) => {
  const spin = spinner();
  spin.start('Processing differences...');
  await wait(1000);
  spin.stop("Displaying differences:");
  log.message('');
  if (differences.length === 0) {
    log.success('No differences found between the selected versions.');
    return;
  }
  for (const diff of differences) {
    let func = null;
    switch (diff.type) {
      case INSERTION:
        func = log.info;
        break;
      case DELETION:
        func = log.error;
        break;
      case MODIFICATION:
        func = log.warn;
        break;
    }
    func(diff.info);
    await wait(100);
  }
  log.message('');
  log.success('Differences displayed successfully');
  await wait(1000);
}

export default PrintDiff;