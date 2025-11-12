import { log } from '@clack/prompts';

const PrintDiff = (differences) => {
  log.step('Displaying differences:');

  differences.forEach(diff => {
    if (diff.startsWith('+')) {
      log.info(diff.slice(1));
    } else if (diff.startsWith('-')) {
      log.error(diff.slice(1));
    } else {
      log.warn(diff.slice(1));
    }
  });

  log.success('Differences displayed successfully');
}

export default PrintDiff;