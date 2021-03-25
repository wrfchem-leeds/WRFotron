#!/bin/bash -l
#$ -cwd -V
#$ -l h_rt=04:00:00
#$ -pe smp 1
#$ -l h_vmem=12G

conda activate my_python_environment
python dask_on_hpc.py