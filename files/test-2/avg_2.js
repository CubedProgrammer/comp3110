function processData(input) {
    const lines = input.split("\n");

    // Compute numeric sum
    let sum = 0;
    for (let i = 0; i < lines.length; i++) {
          const n = parseFloat(lines[i]);
          if (!isNaN(n)) {
              sum += n;
         }
     }

     // Compute average safely
     const average = lines.length > 0 ? sum / lines.length : 0;

     console.log("Total:", sum);
     console.log("Average:", average);

     // Compute squares
     const squares = [];
     for (let i = 0; i < lines.length; i++) {
         const value = parseFloat(lines[i]);
         squares.push(isNaN(value) ? null : value * value);
     }

     console.log("Squares:", squares);

     return {
        total: sum,
         average: average,
         squares: squares
     };
}

module.exports = processData;