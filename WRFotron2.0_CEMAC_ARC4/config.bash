#!/bin/bash
# ------------------------------------------------------------------------------
# WRFOTRON
# ------------------------------------------------------------------------------
# code
# ------------------------------------------------------------------------------
module load intel/19.0.4 openmpi/3.1.4  WRFchem/3.7.1 ncl/6.5.0 nco/4.6.0 wrfchemconda/2.7 
# WRFotron
chainDir=/nobackup/$USER/WRFotron/WRFotron2.0_CEMAC_ARC4
version=0.1
projectTag=WRFChem3.7.1
withChemistry=true
# WPS
WPSdir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_code/WPS3.7.1
# WRFChem
WRFdir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_code/WRFChem3.7.1
# WRFMeteo
WRFmeteodir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_code/WRFMeteo3.7.1
# ------------------------------------------------------------------------------
# preprocessors
# ------------------------------------------------------------------------------
# MEGAN
WRFMEGANdir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_code/megan
# MOZBC
WRFMOZARTdir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_code/mozbc
# WESLEY/EXOCOLDENS
WRFmztoolsdir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_code/wes-coldens
# ANTHRO_EMISS
WRFanthrodir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_code/anthro_emis
# FIRE_EMISS
WRFfiredir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_code/finn/src
# ------------------------------------------------------------------------------
# input data
# ------------------------------------------------------------------------------
# initial and boundary meteorological data
#metDir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_data/initial_boundary_meteo_ecmwf
metDir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_data/initial_boundary_meteo_gfs
metInc=6
# initial and boundary chemistry data (MZ4/CAM-Chem pre 2018, WACCM post 2018)
MOZARTdir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_data/initial_boundary_chem_mz4
#MOZARTdir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_data/initial_boundary_chem_camchem
#MOZARTdir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_data/initial_boundary_chem_waccm
# geography data
geogDir=/nobackup/WRFChem/wps_geog/
#landuseDir=modis_landuse_21class_30s/
# MEGAN input data
MEGANdir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_data/emissions/MEGAN
# anthropogenic emissions - data
emissDir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_data/emissions/EDGAR-HTAP2/MOZART
# anthropogenic emissions - input namelist
emissInpFile=emis_edgarhtap2_mozmos.inp
# anthropogenic emissions - year the emissions are valid for (for offset calculation)
emissYear=2010
# fire emissions from FINN (requires a / at the end)
fireDir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_data/emissions/FINN/
# FINN fire emissions input file
fireInpFile=fire_emis.mozm.inp
# diurnal cycle code
WRFemitdir=/nobackup/WRFChem/WRFChem3.7.1_WRFotron2.0_clean/WRF3.7.1_code/WRF_UoM_EMIT
# ------------------------------------------------------------------------------
# simulation directories
# ------------------------------------------------------------------------------
# run folder
workDir=/nobackup/$USER/WRFChem3.7.1_test/run
# output folder
archiveRootDir=/nobackup/$USER/WRFChem3.7.1_test/output
# restart folder
restartRootDir=/nobackup/$USER/WRFChem3.7.1_test/restart
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
