import { select } from '@clack/prompts';
import { readdirSync, statSync } from 'fs';
import { join } from 'path';

const ChooseFile = async () => {
  const dirPath = process.cwd() + '/files';
  const options =  readdirSync(dirPath).filter(file => statSync(join(dirPath, file)).isDirectory());

  const selectOptions = options.map((option) => {
    return { value: option, label: option };
  });

  return await select({
    message: 'Pick a file',
    options: selectOptions,
  });
};

export default ChooseFile;
