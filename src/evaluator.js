import fs from 'fs';

function countMatchingLines(index, file1, file2) {
  const text1 = fs.readFileSync(file1, 'utf8').split(/\r?\n/);
  const answer = fs.readFileSync(file2, 'utf8').split(/\r?\n/);

  let matches = 0;
  for (let i = 0; i < answer.length; i++) {
    if (answer.includes(text1[i])) {
      matches++;
    }
  }

  console.log(`Total matching lines for test ${index + 1}: ${matches / answer.length * 100}% (${text1.length - answer.length} extra line(s) in output than answer)`);
}

const outputs = fs.readdirSync('./outputs');
const answers = fs.readdirSync('./answer_keys');

for (let i=0; i < outputs.length; i++) {
  countMatchingLines(i, `outputs/${outputs[i]}`, `answer_keys/${answers[i]}`);
}
