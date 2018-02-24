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


# reliability with observations
./run.sh reliability-observe-contracted-fail-strategy1.psi
./run.sh reliability-observe-contracted-fail-strategy2.psi
./run.sh reliability-observe-contracted-fail-strategy3.psi
./run.sh reliability-observe-contracted-nofail-strategy1.psi
./run.sh reliability-observe-contracted-nofail-strategy23.psi

# monitor example
# ../bayonet monitor-large.bayonet > monitor-large.psi
# ./run.sh monitor-large-bad.psi
# ./run.sh monitor-large-good.psi

# ../bayonet monitor-small.bayonet > monitor-small.psi
# ./run.sh monitor-small-bad.psi
# ./run.sh monitor-small-good.psi

# ../bayonet monitor-smaller.bayonet > monitor-smaller.psi
# ./run.sh monitor-smaller-bad.psi
# ./run.sh monitor-smaller-good.psi

# ../bayonet monitor-smallest.bayonet > monitor-smallest.psi
./run.sh monitor-smallest-bad.psi
./run.sh monitor-smallest-good.psi

# ../bayonet monitor-small3.bayonet > monitor-small3.psi
./run.sh monitor-small3-bad.psi
./run.sh monitor-small3-good.psi


# moved to end because large:
./run.sh congestion-large-contracted.psi
./run.sh congestion-largest-contracted.psi
# ./run.sh congestion-large-synthesis-contracted.psi

./run.sh reliability-large-30nodes-contracted.psi
./run.sh reliability-deterministic-large-30nodes-contracted.psi
