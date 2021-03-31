# Compilation

## CEMAC (recommended)

### Pre-built executables

WRFChem has been built with all compiler and MPI combinations on ARC4 here:
```bash
/nobackup/cemac/software/build/WRFChem/
```
The pre-built executables are found in these locations:
```bash
/nobackup/cemac/software/apps/WRFChem/
```

### Custom executables

To build your own WRFChem executables:

- First create the empty build directories.
- Then copy the `build.sh` and the WRFChem .tar.gz file for the version of choice (e.g. 4.2 below).
- Then run the build script as below.
- This copies over the code, builds everything, puts the executables in `software/apps/WRFChem/`, and hardlinks in the correct NetCDF libraries to avoid accidentally pointing to the wrong NetCDF libraries (e.g. from conda) through `/nobackup/WRFChem/build_scripts/linknchdf5.sh`.
- When finished, update `WRFotron/config.bash` to direct to this new build, remove the WRFChem module from being loaded, and copy over the manual blueprints as `pre.bash`, `main.bash`, and  `main_restart.bash` (reasons why given below in Manual compilation).  
- Optional: Can then add any custom edits and [manually recompile](compilation.html#compile-wps-wrfmeteo-and-wrfchem).
```bash
cd /nobackup/${USER} # replace ${USER} with your username
mkdir -p software/build/WRFChem/4.2/1
mkdir -p software/build/WRFChem/4.2/src
cd software/build/WRFChem/4.2/1
cp /nobackup/WRFChem/build_scripts/4.2/build.sh .
cp /nobackup/cemac/software/build/WRFChem/4.2/src/WRFChem4.2.tar.gz ../src/
./build.sh 

# go to your WRFotron and update config.bash to point to this new build, e.g.:
# cd /nobackup/${USER}/WRFotron
# gedit config.bash # or any other text editor
# WRFdir=/nobackup/${USER}/software/build/WRFChem/4.2/1/intel-19.0.4-openmpi-3.1.4/WRFChem4.2/WRFChem4.2 # example here for WRFChem, the exact path will be specific to your build(s)

# in config.bash remove WRFchem/4.2 from the module load line, e.g.:
# module load intel/19.0.4 openmpi/3.1.4 ncl/6.5.0 nco/4.6.0 wrfchemconda/3.7 sge

# from the namelists folder, copy over the manual build pre.bash and main.bash, e.g.:
# cp namelists/pre.bash.blueprint_manual pre.bash
# cp namelists/main.bash.blueprint_manual main.bash
# cp namelists/main_restart.bash.blueprint_manual main_restart.bash
```
To build and use a custom preprocessor:

- First copy over the default preprocessor code from `/nobackup/WRFChem` (e.g. anthro_emis).
- Then copy over the makefile modifier to the same folder.
- Then add your custom edits to the preprocessor.
- Then create the custom preprocessor.
- When finished, update `WRFotron/config.bash` to direct to this new custom preprocessor.
```bash
cd /nobackup/${USER} # replace ${USER} with your username
cp -r /nobackup/WRFChem/anthro_emis .
cd anthro_emis
cp /nobackup/WRFChem/build_scripts/fix_makefile.sh .
./fix_makefile.sh
# make your custom edits
make_anthro
# update WRFotron/config.bash to point to this new processor
```

### Misc

To always be able to view and use all the software CEMAC has built when you run `module avail`, add the following lines to `.bashrc`:   
```bash
if [ -r /nobackup/cemac/cemac.sh ] ; then
  . /nobackup/cemac/cemac.sh
fi
```
The recommended compiler and MPI combination is:
```bash
compiler: intel
mpi: openmpi
```
```{note}
IntelMPI on ARC4 is not optimized and contains a bug. Run the following command to run smoothly with IntelMPI: `export I_MPI_HYDRA_TOPOLIB=ipl`
```

## Manual (alternative)

### Setup

Download WRFotron, WRFChem, make a copy for WRFMeteo without the chemistry folder, download WPS, download [WPS Geography files](https://www2.mmm.ucar.edu/wrf/users/download/get_sources_wps_geog.html):
```bash
cd /nobackup/${USER}
git clone https://github.com/wrfchem-leeds/WRFotron.git
git clone https://github.com/wrf-model/WRF.git WRFChem
git clone https://github.com/wrf-model/WPS.git

cp -r WRFChem WRFMeteo
cd WRFMeteo
rm -rf chem
```
Or copy these folders over from `/nobackup/WRFChem`:
```bash
cd /nobackup/${USER}
cp -r /nobackup/WRFChem/{WRFotron,WRFChem4.2,WRFMeteo4.2,WPS4.2,WPSGeog4} .
```
You will need to remove, or at minimum, change the module load line at the top of `config.bash`. The modules intel, openmpi, and WRFchem are for the CEMAC installation, and keeping these (and potentially others) can interfere with executables. These need to be removed. NCL, NCO, and conda can be used from CEMAC for manual runs, or you could have your own personal conda environments with NCL and NCO (see below). You can see the manual blueprint in the repository: [config.bash.blueprint_manual](https://github.com/wrfchem-leeds/WRFotron/blob/master/namelists/config.bash.blueprint_manual).
```bash
# cemac compilation uses
module load intel/19.0.4 openmpi/3.1.4 WRFchem/4.2 ncl/6.5.0 nco/4.6.0 wrfchemconda/3.7 sge

# for manual compilation remove (at least) intel, openmpi, and WRFchem
module load ncl/6.5.0 nco/4.6.0 wrfchemconda/3.7 sge
```
The executables within `pre.bash` need to be copied over directly, rather than just linked which is adequate for the CEMAC method. To do this make both of the following replacements. You can see the manual blueprint in the repository: [pre.bash.blueprint_manual](https://github.com/wrfchem-leeds/WRFotron/blob/master/namelists/pre.bash.blueprint_manual).
```bash
# on line 21, replace:
for aFile in util geogrid ungrib link_grib.csh metgrid
# with:
for aFile in util geogrid geogrid.exe ungrib ungrib.exe link_grib.csh metgrid metgrid.exe

# and then on line 80, replace:
cp -r ${WRFdir}/run/* .
# with:
cp -r ${WRFdir}/run/* .
rm *.exe
cp -r ${WRFdir}/main/*.exe .
cp -r ${WRFmeteodir}/main/wrf.exe wrfmeteo.exe
```
All executables and preprocessors will need to have `./` before them to execute. This includes `ungrib.exe`, `geogrid.exe`, `metgrid.exe`, `real.exe`, `megan_bio_emiss`, `wesely`, `exo_coldens`, `anthro_emiss`, `fire_emis`, and `mozbc` in `pre.bash`. Also, `wrfmeteo.exe` and `wrf.exe` in `main.bash`. Also, `wrf.exe` in `main_restart.bash`. You can see the manual blueprints in the repository: [pre.bash.blueprint_manual](https://github.com/wrfchem-leeds/WRFotron/blob/master/namelists/pre.bash.blueprint_manual), [main.bash.blueprint_manual](https://github.com/wrfchem-leeds/WRFotron/blob/master/namelists/main.bash.blueprint_manual), and [main_restart.bash.blueprint_manual](https://github.com/wrfchem-leeds/WRFotron/blob/master/namelists/main_restart.bash.blueprint_manual).
Add links to the preprocessor executables `anthro_emis`, `fire_emis`, and `mozbc` by adding the following code. You can see the manual blueprints in the repository: [pre.bash.blueprint_manual](https://github.com/wrfchem-leeds/WRFotron/blob/master/namelists/pre.bash.blueprint_manual).
```bash
ln -s ${WRFanthrodir}/anthro_emis . # section 4.a, line 148
ln -s ${WRFfiredir}/fire_emis .     # section 4.b, line 164
ln -s ${WRFMOZARTdir}/mozbc .         # section 6,   line 186
```
Download flex (tool for generating scanners: programs which recognize lexical patterns in text).  
[Download](https://www2.acom.ucar.edu/wrf-chem/wrf-chem-tools-community) and compile (in serial) preprocessors:  
- anthro_emis (anthropogenic emissions preprocessor).  
- fire_emiss (fire emissions preprocessor).  
- megan (biogenic emissions preprocessor).  
- mozbc (preprocessor for lateral boundary and initial conditions).  
- wes-coldens (exocoldens and season_wesely, O<sub>2</sub> and O<sub>3</sub> column densities and dry deposition).  
- Check preprocessors have the correct modules and libraries linked via: `ldd preprocessor`.  
```bash
conda deactivate # maybe multiple times
module purge
module load intel netcdf openmpi
export NETCDF=$(nc-config --prefix)
export NETCDF_DIR=$NETCDF
export FC=ifort

./make_anthro

./make_fire_emis

./make_util megan_bio_emiss

./make_mozbc

./make_util wesely

./make_util exo_coldens
```

### Conda
Download the latest [miniconda](https://docs.conda.io/en/latest/miniconda.html):
```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
```
Run bash script, read terms, and set path:
```bash
bash Miniconda3-latest-Linux-x86_64.sh
```
Create conda environment with Python 3 (with some libraries for analysis), NCL, and NCO:  
```bash
conda create -n python3_ncl_nco -c conda-forge xarray salem xesmf numpy scipy pandas matplotlib rasterio affine ncl nco wrf-python dask geopandas descartes
```
To activate/deactivate conda environment:  
```bash
conda activate python3_ncl_nco
conda deactivate
```
For more information on conda, [see here](https://docs.conda.io/projects/conda/en/latest/user-guide/index.html).  

Create separate environments for downloading ECMWF data (requires Python 2) and ncview, which you can then load temporarily to execute these functions:  
```bash
conda create -n python2_ecmwf -c conda-forge ecmwf-api-client 
conda create -n ncview -c eumetsat -c conda-forge ncview libpng
```

### Compile WPS, WRFMeteo, and WRFChem
Setup:
```bash
# compiler setup
COMPILER_VER='intel:19.0.4'
MPI_VER='openmpi:3.1.4' # could use intelmpi instead of openmpi, and then also need: export I_MPI_HYDRA_TOPOLIB=ipl
CMP=${COMPILER_VER%:*}
CMP_VER=${COMPILER_VER#*:}
MP=${MPI_VER%:*}
MP_VER=${MPI_VER#*:}
FLAVOUR="${CMP}-${CMP_VER}-${MP}-${MP_VER}"

# modules
conda deactivate # maybe multiple times if many environments activated
module purge
module load licenses sge ${CMP}/${CMP_VER} ${MP}/${MP_VER} netcdf hdf5 patchelf

# environment variables - shell
NETCDF=$(nc-config --prefix)
NETCDF_DIR=$NETCDF
YACC='/usr/bin/yacc -d'
FLEX_LIB_DIR='/nobackup/WRFChem/flex/lib'
LD_LIBRARY_PATH=$FLEX_LIB_DIR:$LD_LIBRARY_PATH
JASPERLIB='/usr/lib64'
JASPERINC='/usr/include'

# environment variables - WRFChem
WRF_EM_CORE=1 # selects the ARW core
WRF_NMM_CORE=0 # ensures that the NMM core is deselected
WRF_CHEM=1 # selects the WRF-Chem module
WRF_KPP=1 # turns on Kinetic Pre-Processing (KPP)
WRFIO_NCD_LARGE_FILE_SUPPORT=1 # supports large wrfout files

# export variables
export FC CC NETCDF NETCDF_DIR YACC FLEX_LIB_DIR LD_LIBRARY_PATH JASPERLIB JASPERINC
export WRFIO_NCD_LARGE_FILE_SUPPORT WRF_KPP WRF_CHEM WRF_NMM_CORE WRF_EM_CORE
```
WRFChem compilation:
- HPC option will be specific to your HPC architecture.
- ARC4 = 15 = INTEL (ifort/icc) (dmpar) e.g. Distributed-Memory Parallelism MPI.
- Compile for basic nesting: option 1.
- Compile real (as oppose to ideal simulations).
- Thousands of messages will appear. Compilation takes about 20-30 minutes.
- How do you know your compilation was successful? If you have all four `main/*.exe`.
- Check the executables have all relevant linked libraries: `ldd main/wrf.exe`.
```bash
cd /nobackup/${USER}/WRFChem
./clean -a
./configure # 15 for intel (ifort/icc) (dmpar) hpc architecture, 1 for basic nesting

./compile em_real >& log.compile 
```
WPS compilation (requires a successfully compiled WRF):
- HPC option will be specific to your HPC architecture.
- ARC4 = 17 = INTEL (ifort/icc) (serial).
- Sometimes `configure.wps` can assign the incorrect path to WRFChem, check and edit if required.
- How do you know your compilation was successful? If you have `geogrid.exe`, `metgrid.exe`, and `ungrib.exe`.
- Check the executables have all relevant linked libraries: `ldd geogrid.exe`.
```bash
cd /nobackup/${USER}/WPS
./clean -a
./configure # 17 for intel (ifort/icc) (serial) hpc architecture

gedit configure.wps
WRF_DIR="/nobackup/${USER}/WRFChem"

./compile >& log.compile
```
WRFMeteo compilation:
- Deselect the WRFChem module.
- HPC option will be specific to your HPC architecture.
- ARC4 = 15 = INTEL (ifort/icc) (dmpar).  
- Compile for basic nesting: option 1.
- Compile real (as oppose to ideal simulations).
- Thousands of messages will appear. Compilation takes about 20-30 minutes.
- How do you know your compilation was successful? If you have all four `main/*.exe`.
- Check the executables have all relevant linked libraries: `ldd main/wrf.exe`.
```bash
export WRF_CHEM=0

cd /nobackup/${USER}/WRFMeteo
./clean -a
./configure # 15 for intel (ifort/icc) (dmpar) hpc architecture, 1 for basic nesting

./compile em_real >& log.compile
```
Preprocessors:
- If make any changes to preprocessors then they require recompilation.
- Raw preprocessors downloaded from [here](http://www.acom.ucar.edu/wrf-chem/download.shtml).
- Ensure the setup is the same as above for manual compilation of WPS/WRFChem/WRFMeteo.
  - May need to check if preprocessor requires a different module version that currently compiled with.
  - If Makefile cannot locate the correct NetCDF path, may need to add `-lnetcdff`.
  - Note for wes_coldens: FC hardcoded in `make_util`.

If need JASPER:
```bash
wget http://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/jasper-1.900.1.tar.gz
tar xvfz jasper-1.900.1.tar.gz
./configure
make
make install
export JASPERLIB=/usr/lib64 # not installed need own jasper
export JASPERINC=/usr/include
```
If need FLEX:
```bash
cd /nobackup/${USER}/flex/lib
./configure --prefix=$(pwd)/../flex
export FLEX_LIB_DIR='/nobackup/${USER}/flex/lib'
```
