#!/bin/bash -l
#$ -cwd -V
#$ -l h_rt=24:00:00
#$ -pe ib 1
#$ -l h_vmem=148G

conda activate python3_ncl_nco

python pp_concat_regrid.py