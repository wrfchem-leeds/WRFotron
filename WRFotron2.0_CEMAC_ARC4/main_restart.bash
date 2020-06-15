#!/bin/bash
# ------------------------------------------------------------------------------
# WRFOTRON
# ------------------------------------------------------------------------------
#$ -cwd -V
#$ -l h_rt=04:00:00
#$ -pe ib 32
#$ -l node_type=40core-192G
#$ -l h_vmem=8G

. config.bash

# fix hyper-threading issue with Yellowstone after upgrade
unset MP_PE_AFFINITY
export MP_TASK_AFFINITY=cpu

# -----------------------------------------------------------------------------
# 2) Chemistry simulation
# -----------------------------------------------------------------------------

# update restart files with previous results for chemistry, or do cold start

# restart check logic assumes that once we have restart file for domain 1
# we continue, even though further domains might be missing a restart file.
# Logic does not account for the case that restart file for domain 1 is missing,
# but is available for another domain (--> would attempt restart run...)
restartFound=false

for domain in $(seq -f "0%g" 1 ${max_dom})
do

newRunRstFile=wrfrst_d${domain}_YYYY-MM-DD_HH:00:00
prevRunRstFile=${restartDir}/${newRunRstFile}

if [ -f ${prevRunRstFile} ]
then

msg "substituting initial data with ${prevRunRstFile}"

# Check nco Version
ncks --version &> ncover.txt
ncksvno=$(grep -E '[0-9]' ncover.txt | cut -d" " -f5 | tr -d -c 0-9)

msg "nco version is ${ncksvno}"

# Use correct code depending on version
if (( ${ncksvno} > 460 )); then
# listing variables in old (chemistry) and new (met-only) restart files
ncks -m ${prevRunRstFile} | grep -E ':FieldType' |  cut -f1 -d ':' | tr -d '      ' | sort > chemVarList
ncks -m ${newRunRstFile} | grep -E ':FieldType' |  cut -f1 -d ':' | tr -d '      ' | sort > metVarList
else
# listing variables in old (chemistry) and new (met-only) restart files
ncks -m ${prevRunRstFile} | grep -E ': type' | cut -f 1 -d ' ' | sed 's/://' | sort > chemVarList
ncks -m ${newRunRstFile} | grep -E ': type' | cut -f 1 -d ' ' | sed 's/://' | sort  > metVarList
fi

chemvarsno=$(wc -l chemVarList | awk '{ print $1 }')
metvarsno=$(wc -l metVarList | awk '{ print $1 }')

if [ $chemvarsno == 0 ]; then
if [ $chemvarsno == $metvarsno ]; then
 msg "WARNING chemistry restart file and meteorology restart file have same variables"
else
  msg "WARNING chemistry variable list nor created"
fi
fi

# determining arrays only in old (chemistry) restart file
chemVarsArr=( $(awk 'FNR==NR{a[$0]++;next}!a[$0]' metVarList chemVarList) )
# converting to comma-separated string
chemVarsLst=${chemVarsArr[@]}
chemVarsTxt=${chemVarsLst// /,}

# adding chemistry variables to new restart file
ncks -A -v ${chemVarsTxt} ${prevRunRstFile} ${newRunRstFile}

restartFound=true

fi

done

msg "chem"

# do the chem run
${mpiCommandMain} wrf.exe

mkdir chem_out
mv rsl* chem_out

# -----------------------------------------------------------------------------
# 3) house keeping
# -----------------------------------------------------------------------------

msg "save restart files"

# save restart files in restart directory
for domain in $(seq -f "0%g" 1 ${max_dom})
do
  lastRstFile=wrfrst_d${domain}_YYYY-MM-DD_HH:00:00
  cp ${lastRstFile} ${restartDir}/${lastRstFile}
done


# that stuff was for runs with chemistry only...
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

msg "save output to archive staging area"

# move all new output to archive directory
for domain in $(seq -f "0%g" 1 ${max_dom})
do
  for hour in $(seq -w 1 __fcstTime__)
  do
    curDate=$(date -u --date="YYYY-MM-DD HH:00:00 ${hour} hours" "+%Y-%m-%d_%H")
    outFile=wrfout_d${domain}_${curDate}:00:00

    cp ${outFile} ${stagingDir}/
  done
done

msg "finished WRF/chem"
