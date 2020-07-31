***********
Compilation
***********

CEMAC (recommended)
===================
Pre-built executables
*********************
- WRFChem has been built with all compiler and MPI combinations on ARC4 here:

.. code-block:: bash

  /nobackup/cemac/software/build/WRFChem/

- The pre-built executables are found in these locations:

.. code-block:: bash

  /nobackup/cemac/software/apps/WRFChem/

Custom executables
******************
- To build your own versions:

    - First create the empty build directories.
    - Then copy the :code:`build.sh` and the WRFChem .tar.gz file for the version of choice (e.g. 4.2 below).
    - Then run the build script as below.
    - This copies over the code, builds everything, puts the executables in :code:`software/apps/WRFChem/`, and hardlinks in the correct NetCDF libraries to avoid accidentally pointing to the wrong NetCDF libraries (e.g. from conda) through :code:`/nobackup/WRFChem/build_scripts/linknchdf5.sh`.
    - When finished, update :code:`WRFotron/config.bash` to direct to this new build.
    - Optional: Can then add any custom edits and `manually recompile <https://wrfotron.readthedocs.io/en/latest/compilation.html#compile-wps-wrfmeteo-and-wrfchem>`_.

.. code-block:: bash

  cd /nobackup/${USER}
  mkdir -p software/build/WRFChem/4.2/1
  mkdir -p software/build/WRFChem/4.2/src
  cd software/build/WRFChem/4.2/1
  cp /nobackup/WRFChem/build_scripts/4.2/build.sh .
  cp /nobackup/cemac/software/build/WRFChem/4.2/src/WRFChem4.2.tar.gz ../src/
  ./build.sh 
  # update WRFotron/config.bash to point to this new build

- To build and use a custom preprocessor:

    - First copy over the default preprocessor code from :code:`/nobackup/WRFChem` (e.g. anthro_emis).
    - Then copy over the makefile modifier to the same folder.
    - Then add your custom edits to the preprocessor.
    - Then create the custom preprocessor.
    - When finished, update :code:`WRFotron/config.bash` to direct to this new custom preprocessor.

.. code-block:: bash

  cd /nobackup/${USER}
  cp -r /nobackup/WRFChem/anthro_emis .
  cd anthro_emis
  cp /nobackup/WRFChem/build_scripts/fix_makefile.sh .
  ./fix_makefile.sh
  # make your custom edits
  make_anthro
  # update WRFotron/config.bash to point to this new processor

Misc
****
- To always be able to view and use all the software CEMAC has built when you run :code:`module avail`, add the following lines to :code:`.bashrc`:   

.. code-block:: bash

  if [ -r /nobackup/cemac/cemac.sh ] ; then
    . /nobackup/cemac/cemac.sh
  fi

- The recommended compiler and MPI combination is:

.. code-block:: bash

  compiler: intel
  mpi: openmpi

- IntelMPI on ARC4 is not optimized and contains a bug. Run the following command to run smoothly with IntelMPI:  

.. code-block:: bash

  export I_MPI_HYDRA_TOPOLIB=ipl

Manual (alternative)
====================

Setup
*****
- Download WRFotron, WRFChem, make a copy for WRFMeteo without the chemistry folder, download WPS, download `WPS Geography files <https://www2.mmm.ucar.edu/wrf/users/download/get_sources_wps_geog.html>`_:

.. code-block:: bash

  cd /nobackup/${USER}
  git clone git@github.com:wrfchem-leeds/WRFotron.git
  git clone git@github.com:wrf-model/WRF.git WRFChem
  git clone git@github.com:wrf-model/WPS.git

  cp -r WRFChem WRFMeteo
  cd WRFMeteo
  rm -rf chem

- Or copy these folders over from :code:`/nobackup/WRFChem`:

.. code-block:: bash

  cd /nobackup/${USER}
  cp -r /nobackup/WRFChem/{WRFotron,WRFChem4.2,WRFMeteo4.2,WPS4.2,WPSGeog4} .

- You will need to remove, or at minimum, change the module load line at the top of :code:`config.bash`. The modules intel, openmpi, and WRFchem are for the CEMAC installation, and keeping these (and potentially others) can interfere with executables. These need to be removed. NCL, NCO, and conda can be used from CEMAC for manual runs, or you could have your own personal conda environments with NCL and NCO (see below). You can see the manual blueprint in the repository: `config.bash.blueprint_manual <https://github.com/wrfchem-leeds/WRFotron/blob/master/config.bash.blueprint_manual>`_.

.. code-block:: bash

  # cemac compilation uses
  module load intel/19.0.4 openmpi/3.1.4 WRFchem/4.2 ncl/6.5.0 nco/4.6.0 wrfchemconda/3.7 sge

  # for manual compilation remove (at least) intel, openmpi, and WRFchem
  module load ncl/6.5.0 nco/4.6.0 wrfchemconda/3.7 sge

- The executables within :code:`pre.bash` need to be copied over directly, rather than just linked which is adequate for the CEMAC method. To do this make both of the following replacements. You can see the manual blueprint in the repository: `pre.bash.blueprint_manual <https://github.com/wrfchem-leeds/WRFotron/blob/master/pre.bash.blueprint_manual>`_.

.. code-block:: bash

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

- All executables and preprocessors will need to have :code:`./` before them to execute. This includes :code:`ungrib.exe`, :code:`geogrid.exe`, :code:`metgrid.exe`, :code:`real.exe`, :code:`megan_bio_emiss`, :code:`wesely`, :code:`exo_coldens`, :code:`anthro_emiss`, :code:`fire_emis`, and :code:`mozbc` in :code:`pre.bash`. Also, :code:`wrfmeteo.exe` and :code:`wrf.exe` in :code:`main.bash`. Also, :code:`wrf.exe` in :code:`main_restart.bash`. You can see the manual blueprints in the repository: `pre.bash.blueprint_manual <https://github.com/wrfchem-leeds/WRFotron/blob/master/pre.bash.blueprint_manual>`_, `main.bash.blueprint_manual <https://github.com/wrfchem-leeds/WRFotron/blob/master/main.bash.blueprint_manual>`_, and `main_restart.bash.blueprint_manual <https://github.com/wrfchem-leeds/WRFotron/blob/master/main_restart.bash.blueprint_manual>`_.
- Add links to the preprocessor executables :code:`anthro_emis`, :code:`fire_emis`, and :code:`mozbc` by adding the following code. You can see the manual blueprints in the repository: `pre.bash.blueprint_manual <https://github.com/wrfchem-leeds/WRFotron/blob/master/pre.bash.blueprint_manual>`_.

.. code-block:: bash

  ln -s ${WRFanthrodir}/anthro_emis . # section 4.a, line 148
  ln -s ${WRFfiredir}/fire_emis .     # section 4.b, line 164
  ln -s ${WRFMOZARTdir}/mozbc .         # section 6,   line 186

- Download flex (tool for generating scanners: programs which recognize lexical patterns in text).  
- `Download and compile (in serial) preprocessors <https://www2.acom.ucar.edu/wrf-chem/wrf-chem-tools-community>`_:  
    - anthro_emis (anthropogenic emissions preprocessor).  
    - fire_emiss (fire emissions preprocessor).  
    - megan (biogenic emissions preprocessor).  
    - mozbc (preprocessor for lateral boundary and initial conditions).  
    - wes-coldens (exocoldens and season_wesely, |O2| and |O3| column densities and dry deposition).  

        .. |O2| replace:: O\ :sub:`2`
        .. |O3| replace:: O\ :sub:`3`

    - Check preprocessors have the correct modules and libraries linked via: :code:`ldd preprocessor`.  

.. code-block:: bash

  conda deactivate
  module purge
  module load intel netcdf
  export NETCDF=$(nc-config --prefix)
  export NETCDF_DIR=$NETCDF
  export FC=ifort

  ./make_anthro

  ./make_fire_emis

  ./make_util megan_bio_emiss

  ./make_mozbc

  ./make_util wesely

  ./make_util exo_coldens

Conda
*****
- Download the latest `miniconda <https://docs.conda.io/en/latest/miniconda.html>`_:

.. code-block:: bash

  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh

- Run bash script, read terms, and set path:

.. code-block:: bash

  bash Miniconda3-latest-Linux-x86_64.sh

- Create conda environment with Python 3 (with some libraries for analysis), NCL, and NCO:  

.. code-block:: bash

  conda create -n python3_ncl_nco -c conda-forge -c oggm xarray salem xesmf numpy scipy pandas matplotlib rasterio affine ncl nco wrf-python

- To activate/deactivate conda environment:  

.. code-block:: bash

  conda activate python3_ncl_nco
  conda deactivate

- For more information on conda, `visit <https://docs.conda.io/projects/conda/en/latest/user-guide/index.html>`_.  
- Create separate environments for downloading ECMWF data (requires Python 2) and ncview, which you can then load temporarily to execute these functions:  

.. code-block:: bash

  conda create -n python2_ecmwf -c conda-forge ecmwf-api-client 
  conda create -n ncview -c eumetsat -c conda-forge ncview libpng


Compile WPS, WRFMeteo, and WRFChem
**********************************
- Modules:

.. code-block:: bash

  conda deactivate
  module unload conda
  module unload openmpi
  module load intel
  module load intelmpi
  module load netcdf

- Environment variables:

.. code-block:: bash

  export FC=ifort
  export NETCDF=$(nc-config --prefix)
  export NETCDF_DIR=$NETCDF
  export YACC='/usr/bin/yacc -d'
  export FLEX_LIB_DIR='/nobackup/username/flex/lib'
  export LD_LIBRARY_PATH=$FLEX_LIB_DIR:$LD_LIBRARY_PATH
  export JASPERLIB=/usr/lib64
  export JASPERINC=/usr/include

  export WRF_EM_CORE=1 # selects the ARW core
  export WRF_NMM_CORE=0 # ensures that the NMM core is deselected
  export WRF_CHEM=1 # selects the WRFChem module
  export WRF_KPP=1 # turns on Kinetic Pre-Processing (KPP)
  export WRFIO_NCD_LARGE_FILE_SUPPORT=1 # supports large wrfout files

- WRFChem compilation:

.. code-block:: bash

  cd /nobackup/username/WRFChem
  ./clean -a
  ./configure

- HPC option will be specific to your HPC architecture.
- ARC4 = 15 = INTEL (ifort/icc) (dmpar) e.g. Distributed-Memory Parallelism MPI.
- Compile for basic nesting: option 1.
- Compile real (as oppose to ideal simulations).
- Thousands of messages will appear. Compilation takes about 20-30 minutes.

.. code-block:: bash

  ./compile em_real >& log.compile

- How do you know your compilation was successful? 

    - If you have :code:`main/*.exe`.

- Check the executables have all relevant linked libraries:

.. code-block:: bash

  ldd main/wrf.exe

- WPS compilation (requires a successfully compiled WRF):

.. code-block:: bash

  cd /nobackup/username/WPS
  ./clean -a
  ./configure

- HPC option will be specific to your HPC architecture.
- ARC4 = 17 = INTEL (ifort/icc) (serial).
- Sometimes configure.wps can assign the incorrect path to WRFChem, check and edit if required:

.. code-block:: bash

  gedit configure.wps
  WRF_DIR="/nobackup/${USER}/WRFChem"

  ./compile >& log.compile

- How do you know your compilation was successful?

    - If you have geogrid.exe, metgrid.exe, and ungrib.exe.

- Check the executables have all relevant linked libraries:

.. code-block:: bash

  ldd geogrid.exe

- WRFMeteo compilation:

    - Deselect the WRFChem module

.. code-block:: bash

  export WRF_CHEM=0

  cd /nobackup/username/WRFMeteo
  ./clean -a
  ./configure

- HPC option will be specific to your HPC architecture.
- ARC4 = 15 = INTEL (ifort/icc) (dmpar).
- Compile for basic nesting: option 1.
- Compile real (as oppose to ideal simulations).
- Thousands of messages will appear. Compilation takes about 20-30 minutes.

.. code-block:: bash

  ./compile em_real >& log.compile

- Check have :code:`main/*.exe`.
- Check the executables have all relevant linked libraries:

.. code-block:: bash

  ldd main/real.exe

- If make any changes to pre-processor settings then require a fresh re-compile.
- Also check if preprocessor requires a different module version that currently compiled with.
- Run above environment variables to get NetCDF.
- Add :code:`-lnetcdff` to Makefile.
- Note for wes_coldens: FC hardcoded in :code:`make_util`.
- Downloaded tools from `here <http://www.acom.ucar.edu/wrf-chem/download.shtml>`_.

- If need JASPER:

.. code-block:: bash

  wget http://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/jasper-1.900.1.tar.gz
  tar xvfz jasper-1.900.1.tar.gz
  ./configure
  make
  make install
  export JASPERLIB=/usr/lib64 # not installed need own jasper
  export JASPERINC=/usr/include

- If need FLEX:

.. code-block:: bash

  cd /nobackup/${USER}/flex/lib
  ./configure --prefix=$(pwd)/../flex
  export FLEX_LIB_DIR='/nobackup/${USER}/flex/lib'

