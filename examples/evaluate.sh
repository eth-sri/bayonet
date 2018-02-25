#!/bin/bash

# experiments from Table 1:
## congestion
./run.sh congestion-contracted.psi
./run.sh congestion-deterministic-contracted.psi
./run.sh congestion-large-contracted.psi
./run.sh congestion-large-deterministic-contracted.psi
./run.sh congestion-largest-contracted.psi

## reliability
./run.sh reliability-contracted.psi
./run.sh reliability-deterministic-contracted.psi
./run.sh reliability-large-30nodes-contracted.psi
./run.sh reliability-deterministic-large-30nodes-contracted.psi

## gossip
./run.sh gossip-contracted.psi
./run.sh gossip-deterministic-contracted.psi
# ./run.sh gossip-20-contracted.psi # times out with exact backend
# ./run.sh gossip-30-contracted.psi # times out with exact backend


# bayesian reasoning using observations
## probability of correct load-balancing
./run.sh monitor-smallest-bad.psi
./run.sh monitor-smallest-good.psi

## reliability with observations
./run.sh reliability-observe-contracted-fail-strategy1.psi
./run.sh reliability-observe-contracted-fail-strategy2.psi
./run.sh reliability-observe-contracted-fail-strategy3.psi
./run.sh reliability-observe-contracted-nofail-strategy1.psi
./run.sh reliability-observe-contracted-nofail-strategy23.psi


