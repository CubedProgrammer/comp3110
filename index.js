import { intro, outro, confirm } from '@clack/prompts';
import ChooseFile from './src/getOptions.js';
import ChooseVersions from './src/getVersions.js';
import DiffChecker from './src/differenceChecker.js';
import PrintDiff from './src/differencePrinter.js';

intro("Welcome to our COMP-3110 project!");

async function RunApp() {
  var shouldContinue = true;

  while (shouldContinue){
    const file = await ChooseFile();
    const versions = await ChooseVersions(file);
    PrintDiff(DiffChecker(versions[0], versions[1]));
    
    shouldContinue = await confirm({
      message: 'Would you like to process another file?',
    });
  }

  outro("Thank you for your time.");
  process.exit(0);
}

RunApp();