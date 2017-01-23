#!/bin/bash

# congestion
## random scheduling
./run congestion-contracted.psi

./run congestion-synthesis-contracted.psi

# ./run congestion-large-contracted.psi # TODO: make fast...
# ./run congestion-large-synthesis-contracted.psi # PSI backend chokes on symbolic constraints. TODO: just use a better parameterization

## deterministic scheduling

./run congestion-deterministic-contracted.psi  # always congested
./run congestion-deterministic2-contracted.psi # prob of congestion 1/8, but scheduler is hard to explain

# ./run congestion-synthesis-deterministic-contracted.psi # seems pointless



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
