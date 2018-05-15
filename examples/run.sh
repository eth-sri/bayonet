#!/bin/bash
PSI="../../psi/psi --noboundscheck --trace --dp --expectation --mathematica"

if [ ! -f ./results/${1%.psi}.txt ]; then
    echo running $1
    { { time $PSI $1; } 2>&1; } > ./results/${1%.psi}.txt
else
    echo skipping $1.
fi
