#!/bin/bash
#$ -cwd -V
#$ -l h_rt=48:00:00
#$ -pe ib 4
#$ -l h_vmem=128G

module purge
module load licenses sge wrfchemconda/3.7
export OMP_NUM_THREADS=4
n_cores=4

echo "Evaluating wrfout files"

for season in 'winter' 'spring' 'summer' 'autumn'
do
    if [ $season == 'winter' ]
    then
        wrfout_files=wrfout_d01_2015-02*
    elif [ $season == 'spring' ]
    then
        wrfout_files=wrfout_d01_2015-05*
    elif [ $season == 'summer' ]
    then
        wrfout_files=wrfout_d01_2015-08*
    elif [ $season == 'autumn' ]
    then
        wrfout_files=wrfout_d01_2015-11*
    fi

    for wrfout_file in $wrfout_files
    do
        ((core=core%n_cores)); ((core++==0)) && wait
        echo $wrfout_file
        python benchmark.py $wrfout_file &
    done
done

echo "Combining metrics per season and annual"
python benchmark_combine.py

echo "Complete"
