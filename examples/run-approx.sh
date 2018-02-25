#!/bin/bash
cp webppl_options.txt ../../psi-approximate/approximateBackends/webppl_options.txt
PSI="./psi --noboundscheck --trace --webppl --mathematica"

cd ../../psi-approximate/
if [ ! -f ../bayonet-implementation/examples/results-approx/${1%.psi}.txt ]; then
    { { time $PSI ../bayonet-implementation/examples/$1; } 2>&1; } > ../bayonet-implementation/examples/results-approx/${1%.psi}.txt
else
    echo skipping $1.
fi
