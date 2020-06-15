#!/bin/bash
#$ -cwd -V
#$ -l h_rt=48:00:00
#$ -pe ib 1
#$ -l node_type=40core-192G
#$ -l h_vmem=128G

ncl 'file_in="wrfout_2014_jan_chemopt201.nc"' 'file_out="wrfout_2014_jan_chemopt201_cf.nc"' wrfout_to_cf_201.ncl
