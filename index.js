import { intro, outro, confirm } from '@clack/prompts';
import { ChooseFile, ChooseBranch } from './src/getOptions.js';
import ChooseVersions from './src/getVersions.js';
import { DiffChecker } from './src/differenceChecker.js';
import PrintDiff from './src/differencePrinter.js';
import { changeBranchAA } from './src/repositoryInformation.js';

intro("Welcome to our COMP-3110 project!");

async function RunApp() {
  var shouldContinue = true;

  while (shouldContinue){
    const [old, current] = await ChooseBranch();
    const file = await ChooseFile(current);
    await changeBranchAA(current);
    const [first, second] = await ChooseVersions(file);
    await PrintDiff(DiffChecker(first, second));
    await changeBranchAA(old);

    shouldContinue = await confirm({
      message: 'Would you like to process another file?',
    });
  }

  outro("Thank you for your time.");
  process.exit(0);
}

RunApp();