#!/bin/bash

. config.bash

# ------------------------------------
# 1. run simulations per season
# ------------------------------------

# winter - feb
for file in pre.bash
do
    sed -i 's/20150901_20160101/20141201_20150501/g' $file
    sed -i 's/MZ2015oct/MZ2015feb/g' $file
done

. master.bash 2015 02 01 00 48 00

# spring - may
for file in pre.bash
do
    sed -i 's/20141201_20150501/20150501_20150901/g' $file
    sed -i 's/MZ2015feb/MZ2015may/g' $file
done

. master.bash 2015 05 01 00 48 00

# summer - aug
for file in pre.bash
do
    sed -i 's/MZ2015may/MZ2015aug/g' $file
done

. master.bash 2015 08 01 00 48 00

# autumn - nov
for file in pre.bash
do
    sed -i 's/20150501_20150901/20150901_20160101/g' $file
    sed -i 's/MZ2015aug/MZ2015nov/g' $file
done

. master.bash 2015 11 01 00 48 00

# ------------------------------------
# 2. run benchmarking
# ------------------------------------
cd ${archiveRootDir}/base

# needs to wait until last season post.bash finished
benchmark_text=$(qsub -hold_jid ${postjobnr} benchmark.bash)
benchmark_job_id=$(echo $benchmark_text | grep -o "[0-9]\{1,10\}" )

# ------------------------------------
# 3. run testing
# ------------------------------------

# needs to wait until last season post.bash finished
tests_text=$(qsub -hold_jid ${postjobnr} tests.bash)
tests_job_id=$(echo $tests_text | grep -o "[0-9]\{1,10\}" )
