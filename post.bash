#!/bin/bash
# ------------------------------------------------------------------------------
# WRFOTRON
# ------------------------------------------------------------------------------
#$ -cwd -V
#$ -l h_rt=48:00:00
#$ -pe smp __nprocPost__
#$ -l h_vmem=12G

module purge
module load licenses sge intel/19.0.4 nco/4.6.0 wrfchemconda/3.7
export OMP_NUM_THREADS=__nprocPost__

. __CONFIGDIR__config.bash

cd ${stagingDir}

msg "Postprocessing of WRF/Chem output"

mkdir -p ${archiveDir}

# Postprocessing funtion (same as before just removed from for loop)
postpoc(){
  # hour is passed in as a local variable
  local hour=$1
  # Tags and files are local vars so each core works on only one thing
  local dateTag=$(date -u --date="__inpYear__-__inpMonth__-__inpDay__ __inpHour__:00:00 ${hour} hours" "+%Y%m%d%H%M%S")
  local curDate=$(date -u --date="__inpYear__-__inpMonth__-__inpDay__ __inpHour__:00:00 ${hour} hours" "+%Y-%m-%d_%H")

  echo "PP'ing ${dateTag}"

  for domain in $(seq -f "0%g" 1 ${max_dom})
  do
    local inFile=wrfout_d${domain}_${curDate}:00:00

    if [ ! -f ${inFile} ]
    then
      echo "${inFile} missing, skipped!"
      continue
    fi

    if [ -f ${archiveDir}/${inFile} ]
    then
      echo "${archiveDir}/${inFile} already exists, skipped!"
      continue
    fi

    # --------------------- per file postprocessing ----------------------------

    local outFile=${inFile}.nc
    cp -p $inFile $outFile
    echo 'deleting tmp_'${outFile}
    rm -f tmp_${outFile}

    # create new variables
    python ${pyPpScript} ${inFile} tmp_${outFile} $WRFdir

    # temporary workaround for WRFChem4 due to NCO bug (fxm TODO nco1089) need to convert netcdf4 back to netcdf3, remove when fixed
    if [ "$(printf '%s\n' "4.0.0" "${WRFdir} | grep -Eo '[0-9]+([.][0-9]+)?([.][0-9]+)?' | tail -1" | sort -V | head -n1)" = 4.0.0 ]; then
        ncks -3 -O tmp_${outFile} tmp_${outFile}
        ncks -3 -O ${outFile} ${outFile}
    fi

    # append all other variables
    ncks -A tmp_${outFile} ${outFile}

    #. $ppBashScript $inFile $outFile $domain $dateTag
    # outFile=$inFile

    # do whatever you want to do in postprocessing, just create a final NetCDF
    # file with its name in the variable "outFile".
    # This will be archived.

    # --------------------- per file postprocessing ----------------------------

    # apply compression and save to archive, use input filename
    # k3 --> NetCDF-4 format
    # d9 --> max compression level
    # s  --> shuffling (can improve compression)
    nccopy -k3 -d9 -s $outFile ${archiveDir}/${inFile}

    # remove output file only from staging area
    rm -f $outFile

  done
}

# parallel for loop runs post proc in background in chunks of number of avaible
# cores, i.e. core requested
N=$(nproc)
for hour in $(seq -w 0 __fcstTime__)
do
  ((i=i%N)); ((i++==0)) && wait
  postpoc $hour &
done

# remove the run directory
if __REMOVERUNDIR__
then
  echo $(du -sh ${runDir})
  rm -rf ${runDir}
fi

msg "PP ended"
date
echo "-----------------------------"
