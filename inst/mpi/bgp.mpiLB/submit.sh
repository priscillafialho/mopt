#!/bin/bash

echo "starting qsub script file"
source ~/.bash_profile
date 

# here's the SGE directives
# ------------------------------------------
#$ -q batch.q   # <- the name of the Q you want to submit to
#$ -pe mpich 8 #  <- load the openmpi parallel env w/ 3 slots
#$ -S /bin/bash   # <- run the job under bash
#$ -N mopt-example # <- name of the job in the qstat output
#$ -o std.out # <- name of the output file.
#$ -e err.out # <- name of the stderr file.
#$ -cwd

module load openmpi
module load r/2.15.2

echo "loaded modules"
module list

echo "calling mpirun now"
mpirun -np 8 /data/uctpfos/R/x86_64-unknown-linux-gnu-library/2.15/snow/RMPISNOW -q < example.bgp.mpiLB.r > example.Rout


