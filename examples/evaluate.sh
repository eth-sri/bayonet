#!/bin/bash

# congestion
## random scheduling
./run congestion-contracted.psi

./run congestion-synthesis-contracted.psi

# ./run congestion-large-contracted.psi # TODO: make fast...
# ./run congestion-large-synthesis-contracted.psi # PSI backend chokes on symbolic constraints. TODO: just use a better parameterization

## deterministic scheduling

# ./run congestion-contracted-deterministic.psi

# ./run congestion-synthesis-contracted-deterministic.psi



# reliability

## random scheduling
./run reliability-contracted.psi

## deterministic scheduling
# unnecessary: result is independent of scheduling as we model only one packet at a time

# Gossip

## random scheduling
# N/A

## deterministic scheduling

# TODO!
