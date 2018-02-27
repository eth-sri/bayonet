#!/bin/bash

# experiments from Table 1:
# congestion
./run-approx.sh congestion.psi
./run-approx.sh congestion-deterministic.psi
./run-approx.sh congestion-large.psi
./run-approx.sh congestion-large-deterministic.psi
./run-approx.sh congestion-largest.psi

# reliability
./run-approx.sh reliability.psi
./run-approx.sh reliability-deterministic.psi
./run-approx.sh reliability-large-30nodes.psi
./run-approx.sh reliability-deterministic-large-30nodes.psi

# gossip
./run-approx.sh gossip.psi
./run-approx.sh gossip-deterministic.psi
./run-approx.sh gossip-20.psi
./run-approx.sh gossip-30.psi
