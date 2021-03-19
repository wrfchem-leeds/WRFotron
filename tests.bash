#!/bin/bash
#$ -cwd -V
#$ -l h_rt=01:00:00
#$ -pe ib 1
#$ -l h_vmem=12G

module load licenses sge wrfchemconda/3.7

for test in tests/*py;
  do pytest $test;
done