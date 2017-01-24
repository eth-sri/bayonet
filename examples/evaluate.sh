#!/bin/bash

# congestion
## random scheduling
./run.sh congestion-contracted.psi
./run.sh congestion-synthesis-contracted.psi

# ./run congestion-large-contracted.psi # TODO: make fast...
# ./run congestion-large-synthesis-contracted.psi # PSI backend chokes on symbolic constraints. TODO: use a better parameterization

## deterministic scheduling

./run.sh congestion-deterministic-contracted.psi  # always congested
./run.sh congestion-deterministic2-contracted.psi # prob of congestion 1/8, but scheduler is hard to explain

./run.sh congestion-large-deterministic-contracted.psi
./run.sh congestion-large-deterministic2-contracted.psi

# ./run congestion-synthesis-deterministic-contracted.psi # seems pointless


# reliability

## random scheduling
./run.sh reliability-contracted.psi
./run.sh reliability-synthesis-contracted.psi # computes probability that packet arrives

## deterministic scheduling
./run.sh reliability-deterministic-contracted.psi

# Gossip

## random scheduling
./run.sh gossip-contracted.psi

## deterministic scheduling
./run.sh gossip-deterministic-contracted.psi



# moved to end because large:
./run.sh congestion-large-contracted.psi
./run.sh congestion-large-syhnthesis-contracted.psi
