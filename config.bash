#!/bin/bash
# ------------------------------------------------------------------------------
# WRFOTRON
# ------------------------------------------------------------------------------
# code
# ------------------------------------------------------------------------------
module load intel/19.0.4 openmpi/3.1.4 netcdf/4.6.3 WRFchem/4.2 ncl/6.5.0 nco/4.6.0 wrfchemconda/3.7 sge

version=2.1
projectTag=simulation_WRFChem4.2_test
withChemistry=true

# WRFotron
chainDir=/nobackup/${USER}/WRFotron

# WPS
WPSdir=/nobackup/WRFChem/WPS4.2

# WRFChem
WRFdir=/nobackup/WRFChem/WRFChem4.2

# WRFMeteo
WRFmeteodir=/nobackup/WRFChem/WRFMeteo4.2

# ------------------------------------------------------------------------------
# preprocessors
# ------------------------------------------------------------------------------
# MEGAN
WRFMEGANdir=/nobackup/WRFChem/megan

# MOZBC
WRFMOZARTdir=/nobackup/WRFChem/mozbc

# WESLEY/EXOCOLDENS
WRFmztoolsdir=/nobackup/WRFChem/wes-coldens

# ANTHRO_EMISS
WRFanthrodir=/nobackup/WRFChem/anthro_emis

# FIRE_EMISS
WRFfiredir=/nobackup/WRFChem/finn/src

# ------------------------------------------------------------------------------
# input data
# ------------------------------------------------------------------------------
# initial and boundary meteorological data
metDir=/nobackup/WRFChem/initial_boundary_meteo_ecmwf
metInc=6

# initial and boundary chemistry data (MZ4/CAM-Chem pre 2018, WACCM post 2018)
MOZARTdir=/nobackup/WRFChem/initial_boundary_chem_mz4

# geography data
geogDir=/nobackup/WRFChem/WPSGeog4
landuseDir=modis_landuse_21class_30s/

# MEGAN input data
MEGANdir=/nobackup/WRFChem/emissions/MEGAN

# anthropogenic emissions - data
emissDir=/nobackup/WRFChem/emissions/EDGAR-HTAP2_MEIC2015/MOZART

# anthropogenic emissions - input namelist
emissInpFile=emis_edgarhtap2-meic2015_mozmos.inp

# anthropogenic emissions - year the emissions are valid for (for offset calculation)
emissYear=2010

# fire emissions from FINN (requires a / at the end)
fireDir=/nobackup/WRFChem/emissions/FINN/

# FINN fire emissions input file
fireInpFile=fire_emis.mozm.inp

# diurnal cycle code
WRFemitdir=/nobackup/WRFChem/WRF_UoM_EMIT

# ------------------------------------------------------------------------------
# simulation directories
# ------------------------------------------------------------------------------
# run folder
workDir=/nobackup/${USER}/${projectTag}/run

# output folder
archiveRootDir=/nobackup/${USER}/${projectTag}/output

# restart folder
restartRootDir=/nobackup/${USER}/${projectTag}/restart

# remove run directory after run is finished?
removeRunDir=false

# post processing script
pyPpScript=${chainDir}/postprocessing.py

# ------------------------------------------------------------------------------
# HPC settings
# ------------------------------------------------------------------------------
# number of cores to run with for each stage
nprocPre=1
nprocMain=2  # this is the number of nodes, see https://github.com/wrfchem-leeds/WRFotron/commit/ca279396f6cf606c87dd13bed49a2a90120e0da6
nprocPost=4

# mpirun for real.exe and wrf.exe
mpiCommandPre=mpirun
mpiCommandMain=mpirun
submitCommand=qsub
usequeue=true

# ------------------------------------------------------------------------------
# misc.
# ------------------------------------------------------------------------------
function msg {
  echo ""
  echo "---"
  echo $1
  echo "---"
  echo ""
}
