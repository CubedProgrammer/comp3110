import { readFile } from 'fs/promises';
import { select } from '@clack/prompts';
import { changeBranchAA, getCommitsAA } from './repositoryInformation.js';

const ChooseVersions = async (file) => {
  const selectedOptions = [];
  const readOptions = { encoding: 'utf8' };

  const options = await getCommitsAA();
  var selectOptions = options.map((option) => {
    return { label: option.hash + ' ' + option.msg, value: option.hash };
  });

  selectedOptions.push(await select({
    message: 'Pick a version',
    options: selectOptions,
  }));

  await changeBranchAA(selectedOptions[0]);
  const firstVersion = await readFile(file, readOptions);
  selectOptions = selectOptions.filter(opt => opt.value != selectedOptions[0]);

  selectedOptions.push(await select({
    message: 'Pick another version to compare with',
    options: selectOptions,
  }));

  await changeBranchAA(selectedOptions[1]);
  const secondVersion = await readFile(file, readOptions);
  return [firstVersion, secondVersion];

};

export default ChooseVersions;
