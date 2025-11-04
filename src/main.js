function main(args)
{
    if (args.length < 5) {

        console.log('<first commit> <second commit> <files...>');
        console.log('Commit can be a hash value or an offset from HEAD');
        return 1;

    }

    const commit1 = args[2];
    const commit2 = args[3];
    const filels = args.slice(4);
    diff(commit1, commit2, filels);
    return 0;
}

function diff(c1, c2, ls) {
    console.log(ls);
}

function diffImpl(f1, f2) {
    console.log('to be implemented')
}

process.exitCode = main(process.argv);
