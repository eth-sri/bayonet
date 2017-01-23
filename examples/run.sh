#!/bin/bash
PSI="psi --noboundscheck --trace --bruteforce --mathematica"

{ { time $PSI $1; } 2>&1; } > ./results/${1%.psi}.txt
