function processData(input) {
    let lines = input.split("\n");
    let sum = 0;
    for (let i = 0; i < lines.length; i++) {
        let num = parseInt(lines[i]);
          if (!isNaN(num)) {
              sum += num;
          }
      }
     let avg = sum / lines.length;
     console.log("Total:", sum);
     console.log("Average:", avg);
     let squared = [];
     for (let i = 0; i < lines.length; i++) {
        squared.push(lines[i] * lines[i]);
     }
     console.log("Squares:", squared);
     return {
         total: sum,
         average: avg,
         squares: squared
     };
}

console.log('testing')
console.log('testing2')
module.exports = processData;