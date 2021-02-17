#!/bin/bash -l
#$ -cwd -V
#$ -l h_rt=24:00:00
#$ -pe ib 1
#$ -l h_vmem=148G

using_cemac_conda=$((module list -t) |& grep -i wrfchemconda | wc -c)

if [[ $using_cemac_conda -ne 0 ]]; then
    module load wrfchemconda/3.7
else
    conda activate python3_ncl_nco 
fi

python pp_concat_regrid.py