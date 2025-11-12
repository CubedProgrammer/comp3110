import { select } from '@clack/prompts';
import { readdirSync, statSync } from 'fs';
import { join } from 'path';

const ChooseVersions = async (folderName) => {
  const selectedOptions = [];
  const dirPath = process.cwd() + '/files/' + folderName;
  const options =  readdirSync(dirPath).filter(file => statSync(join(dirPath, file)).isFile());

  var selectOptions = options.map((option) => {
    return { value: option, label: option };
  });

  selectedOptions.push(await select({
    message: 'Pick a version',
    options: selectOptions,
  }));

  selectOptions = selectOptions.filter(opt => opt.value != selectedOptions[0]);

  selectedOptions.push(await select({
    message: 'Pick another version to compare with',
    options: selectOptions,
  }));

  return selectedOptions.sort((a, b) => a.localeCompare(b)).map(opt => dirPath + '/' + opt);
};

export default ChooseVersions;
