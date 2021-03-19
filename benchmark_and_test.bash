#!/bin/bash

. config.bash

# ------------------------------------
# 1. run simulations per season
# ------------------------------------

# winter - feb
for file in pre.bash
    do sed -i 's/20160901_20170101/20151201_20160501/g' $file
    do sed -i 's/MZ2016oct/MZ2016feb/g' $file
done

. master.bash 2016 02 01 00 48 00

# spring - may
for file in pre.bash
    do sed -i 's/20151201_20160501/20160501_20160901/g' $file
    do sed -i 's/MZ2016feb/MZ2016may/g' $file
done

. master.bash 2016 05 01 00 48 00

# summer - aug
for file in pre.bash
    do sed -i 's/MZ2016may/MZ2016aug/g' $file
done

. master.bash 2016 08 01 00 48 00

# autumn - nov
for file in pre.bash
    do sed -i 's/20160501_20160901/20160901_20170101/g' $file
    do sed -i 's/MZ2016aug/MZ2016nov/g' $file
done

. master.bash 2016 11 01 00 48 00

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
