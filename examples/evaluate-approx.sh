#!/bin/bash

# experiments from Table 1:
# congestion
./run-approx.sh congestion-contracted.psi
./run-approx.sh congestion-deterministic-contracted.psi
./run-approx.sh congestion-large-contracted.psi
./run-approx.sh congestion-large-deterministic-contracted.psi
./run-approx.sh congestion-largest-contracted.psi

# reliability
./run-approx.sh reliability-contracted.psi
./run-approx.sh reliability-deterministic-contracted.psi
./run-approx.sh reliability-large-30nodes-contracted.psi
./run-approx.sh reliability-deterministic-large-30nodes-contracted.psi

# gossip
./run-approx.sh gossip-contracted.psi
./run-approx.sh gossip-deterministic-contracted.psi
./run-approx.sh gossip-20-contracted.psi
./run-approx.sh gossip-30-deterministic-contracted.psi
