#!/bin/bash
#$ -cwd -V                          # execute from current working directory and export all current environment variables to all spawned processes
#$ -l h_rt=03:00:00                 # The wall clock time which is the amount of real time needed by the job
#$ -l h_vmem=4G                     # Sets the limit of virtual memory required which is for parallel jobs per processor
#$ -pe ib 16                        # Specifies a job for parallel programs using MPI, nprocPre is the number of cores to be used by the parallel job

cd /nobackup/user/wrf3.7.1_clean/wrf3.7.1_code/download_and_find_gfs_mz4/
. find_missing_GFS.bash

