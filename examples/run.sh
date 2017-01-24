#!/bin/bash
PSI="psi --noboundscheck --trace --bruteforce --mathematica"

if [ ! -f ./results/${1%.psi}.txt ]; then
    { { time $PSI $1; } 2>&1; } > ./results/${1%.psi}.txt
else
    echo skipping $1.
fi
