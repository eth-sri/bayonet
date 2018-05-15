#!/bin/bash
./build.sh && time ./bayonet $@
# dmd -release -inline -O *.d -ofprob && time ./prob $@
