#!/bin/bash

# experiments from Table 1:
## congestion
./run.sh congestion.psi
./run.sh congestion-deterministic.psi
./run.sh congestion-large.psi
./run.sh congestion-large-deterministic.psi
./run.sh congestion-largest.psi

## reliability
./run.sh reliability.psi
./run.sh reliability-deterministic.psi
./run.sh reliability-large-30nodes.psi
./run.sh reliability-deterministic-large-30nodes.psi

## gossip
./run.sh gossip.psi
./run.sh gossip-deterministic.psi
# ./run.sh gossip-20.psi # times out with exact backend
# ./run.sh gossip-30.psi # times out with exact backend


# Bayesian reasoning using observations

## probability of correct load-balancing
./run.sh monitor-smallest-bad.psi
./run.sh monitor-smallest-good.psi

## reliability with observations
./run.sh reliability-observe-1-3.psi
./run.sh reliability-observe-1-2-3.psi
./run.sh reliability-observe-empty.psi
./run.sh reliability-observe-2-1-3.psi

