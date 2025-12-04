import { select } from '@clack/prompts';
import { getBranchesAA, getFilesAA } from 'repositoryInformation';

export const ChooseBranch = async () => {
  const [options, current] = await getBranchesAA();
  for(let i = current; i > 0; --i) {
    let tmp = options[i];
    options[i] = options[i-1];
    options[i-1] = tmp;
  }

  const selectOptions = options.map((option) => {
    return { value: option, label: option };
  });

  return await select({
    message: 'Pick a branch',
    options: selectOptions,
  });
}

export const ChooseFile = async (branch) => {
  const dirPath = process.cwd()
  const options = await getFilesAA(branch);

  const selectOptions = options.map((option) => {
    return { value: option, label: option };
  });

  return await select({
    message: 'Pick a file',
    options: selectOptions,
  });
};
