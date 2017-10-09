#!/bin/bash
dmd -gc -debug *.d -ofbayonet && time ./bayonet $@
# dmd -release -inline -O *.d -ofprob && time ./prob $@
