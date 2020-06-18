#!/bin/bash
# ------------------------------------------------------------------------------
# WRFOTRON
# ------------------------------------------------------------------------------
# code
# ------------------------------------------------------------------------------
module load intel/19.0.4 openmpi/3.1.4  WRFchem/3.7.1 ncl/6.5.0 nco/4.6.0 wrfchemconda/2.7

version=2.1
projectTag=simulation_WRFChem3.7.1_test
withChemistry=true

# WRFotron
chainDir=/nobackup/${USER}/WRFotron

# WPS
WPSdir=/nobackup/wrfchem/WPS3.7.1

# WRFChem
WRFdir=/nobackup/wrfchem/WRFChem3.7.1

# WRFMeteo
WRFmeteodir=/nobackup/wrfchem/WRFMeteo3.7.1

# ------------------------------------------------------------------------------
# preprocessors
# ------------------------------------------------------------------------------
# MEGAN
WRFMEGANdir=/nobackup/wrfchem/megan

# MOZBC
WRFMOZARTdir=/nobackup/wrfchem/mozbc

# WESLEY/EXOCOLDENS
WRFmztoolsdir=/nobackup/wrfchem/wes-coldens

# ANTHRO_EMISS
WRFanthrodir=/nobackup/wrfchem/anthro_emis

# FIRE_EMISS
WRFfiredir=/nobackup/wrfchem/finn/src

# ------------------------------------------------------------------------------
# input data
# ------------------------------------------------------------------------------
# initial and boundary meteorological data
metDir=/nobackup/wrfchem/initial_boundary_meteo_ecmwf
metInc=6

# initial and boundary chemistry data (MZ4/CAM-Chem pre 2018, WACCM post 2018)
MOZARTdir=/nobackup/wrfchem/initial_boundary_chem_mz4

# geography data
geogDir=/nobackup/wrfchem/WPSGeog4
landuseDir=modis_landuse_21class_30s/

# MEGAN input data
MEGANdir=/nobackup/wrfchem/emissions/MEGAN

# anthropogenic emissions - data
emissDir=/nobackup/wrfchem/emissions/EDGAR-HTAP2/MOZART

# anthropogenic emissions - input namelist
emissInpFile=emis_edgarhtap2_mozmos.inp

# anthropogenic emissions - year the emissions are valid for (for offset calculation)
emissYear=2010

# fire emissions from FINN (requires a / at the end)
fireDir=/nobackup/wrfchem/emissions/FINN/

# FINN fire emissions input file
fireInpFile=fire_emis.mozm.inp

# diurnal cycle code
WRFemitdir=/nobackup/wrfchem/WRF_UoM_EMIT

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
nclPpScript=${chainDir}/pp.ncl

# ------------------------------------------------------------------------------
# HPC settings
# ------------------------------------------------------------------------------
# number of cores to run with for each stage
nprocPre=1
nprocMain=32
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
