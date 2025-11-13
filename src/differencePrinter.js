import { log, spinner } from '@clack/prompts';

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
    if (diff.startsWith('+')) {
      log.info(diff.slice(1));
    } else if (diff.startsWith('-')) {
      log.error(diff.slice(1));
    } else {
      log.warn(diff.slice(1));
    }

    await wait(500);
  }
  log.message('');
  log.success('Differences displayed successfully');
  await wait(1000);
}

export default PrintDiff;