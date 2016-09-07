#!/bin/bash
dmd -gc -debug *.d -ofnetppl && time ./netppl $@
# dmd -release -inline -O *.d -ofprob && time ./prob $@
