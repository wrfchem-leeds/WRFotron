********************
Automatic simulation
********************
Running
=======

WRFotron uses pre-built executables on ARC4 from CEMAC. Everything required is loaded in :code:`config.bash`, including Python, NCO, NCL, WPS, WRFMeteo, WRFChem, preprocessors, and ncview.  

1. Log into ARC4 and clone the WRFotron repo:  

.. code-block:: bash

  git clone git@github.com:wrfchem-leeds/WRFotron.git

2. Load the availability of CEMAC modules:

.. code-block:: bash

  . /nobackup/cemac/cemac.sh
    
3. Run WRFotron:  

.. code-block:: bash

  . master.bash 2016 10 12 00 24 06


How it works
============
- WRFotron is used by calling the :code:`master.bash` bash script. :code:`master.bash` takes a starting date, a run time, a spinup time, and (optionally) a previous run's job ID on the queuing system as arguments.  
- According to the run configuration in :code:`config.bash`, WRFotron then prepares a run directory (typically on scratch or nobackup) with all necessary data, and submits 3 jobs to the queue:  

    - Preprocessing script (:code:`pre.bash`), containing calls to ungrib.exe, metgrid.exe, real.exe and the preprocessor tools for chemistry.  
    - Main execution script (:code:`main.bash`), which does the actual wrf.exe runs (spinup and chemistry run).  
    - Postprocessing script (:code:`post.bash`), which can be extended to do any kind of postprocessing on the wrfout files of the WRFChem run.  

- Calling :code:`master.bash` and giving it the job ID of another WRFotron :code:`main.bash` process in the queue will tell the :code:`main.bash` script to wait for this process to end before starting, thereby allowing you to submit several runs in a row at the same time, each of them restarting using the result of the previous run.  
- The re-initialisation of meteorology works as follows:  

    - After each successful WRFotron WRFChem run, wrfrst restart files are saved in a common directory. When a new run is called using :code:`master.bash`, a meteo-only spinup run is made first, and a restart file is created at its end, now containing only "fresh" meteorology variables. It is then checked whether a restart file (with chemistry) from a previous run exists in the common restart directory. If this is the case, only the chemistry variables are copied from the previous run's restart file to the meteo spinup restart file. Then, a WRFChem run is started using this combined restart file as initial conditions, thereby using "fresh" meteorology while carrying on chemistry variables across runs. In case no restart file is found, a "cold start" chemistry run is conducted, starting with MOZART global model forecast values as initial conditions.
- If :code:`main.bash` breaks in the middle of the simulation, can restart using :code:`main_restart.bash`:  

    - Edited to not repeat the meteo spin up and carry on from where chem wrf.exe stopped.
    - Steps:

        - Go to the run folder where :code:`main.bash` stopped
        - Copy the latest restart file with 00 hours over to the restart/base directory
        - Edit :code:`main_restart.bash`:

            - Change newRunRstFile to this latest restart file
            - Change submission time length appropriately
            - Change lastRstFile to the final restart file date at the end of run
            - Change curDate to the first wrfout file date

        - Edit :code:`namelist.input`:

            - Ensure :code:`restart = .true`.
            - Change start date to match date of newRunRstFile

        - :code:`qsub main_restart.bash`
        - When finished:

            - Manually copy over the final restart file to restart/base
            - Manually move the wrfout files to run/base/staging
            - Manually :code:`qsub post.bash`

- Other files within WRFotron:  

    - :code:`pp.ncl` (post-processing script).  

        - Calculates AOD for 550nm through interpolations and just extracting for the surface.  
        - Converts units of aerosols at a certain standard temperature and pressure by dividing by the inverse of density: µg/kg of dry air to µg/|m3| by dividing by |m3|/kg.  

            .. |m3| replace:: m\ :sup:`3`

    - WRFChem namelists (read :code:`/WRFChem/run/README.namelist` or user guide for detailed information).  

        - :code:`namelist.chem`.  
        - :code:`namelist.wrf`.  
        - :code:`namelist.wps`.  

    - :code:`Vtable.ECMWF/GFS`.  

        - Variable table for the intial and boundary meteorological conditions.  

    - preprocessor input files (:code:`emis_edgarhtap2_mozmos.inp`, :code:`exo_coldens.inp`, :code:`fire_emis.mozm.inp`, :code:`mozbc.inp`, :code:`megan_bio_emiss.inp`, :code:`mozbc.inp.blueprint_201_mz4`, :code:`mozbc.inp.blueprint_202_mz4`).     
    - For files which depend on the aerosol / chemistry schemes (mozbc.inp, namelist.chem, and namelist.wrf), there are blueprints of each of these files for both the mozart_mosaic_4bin (:code:`chem_opt = 201`) and the mozart_mosaic_4bin_aq (:code:`chem_opt = 202`). See `document <https://github.com/wrfchem-leeds/WRFotron/blob/master/additional_docs/MOZART_MOSAIC_V3.6.readme_dec2016.pdf>`_.  

        - Replace the contents of the namelist with the blueprint_201 / 202 version.  

- Crontab script.  

    - Not normally allowed, check with HPC staff first.  
    - Touches all files in :code:`/nobackup/${USER}` to update their date and stop them getting deleted. 
    - Create a hidden file in home directory (:code:`vi ~/.not_expire.sh`) and add to it triples of lines such as:  

        - Touch -h makes sure symlinks don’t expire too.  
        - This script will change the last accessed date for all the specified directories and files underneath that path.  
        - Change permissions 755 on .not_expire.sh (:code:`chmod 755 ~/.not_expire.sh`).  
        - Use the crontab command to edit the crontab file :code:`crontab -e`
        - Then add a line: :code:`0 4 4 * * ~/.not_expire.sh`
        - This has now set a cronjob to run that will automatically touch (and thus reset last accessed time) the files once a month at 0400 on the 4th of the month.
        - Runs on the login nodes

.. code-block:: bash

  cd /nobackup/${USER}  
  find . -exec touch -ah {} \;
  find . -exec touch -a {} \;  

- Simulation folder layout  automatically created by WRFChem:  

    - Output/Base/ (NetCDF files for wrfout).  
    - Restart/Base/ (Restart files for simulation runs).  
    - Run/Base/Folder per simulation run/ (Everything gets created in here, specific to run).  
    - Run/Base/Staging (wrfout files are stored for post-processing).  

- Acquire meteorological NCEP GFS files.  

    - Will have to change all scripts with dataDir locations to the correct ${USER}.  

    .. code-block:: bash

      cd /nobackup/${USER}/download_and_find_gfs_mz4
      get_GFS_analysis_2004-current.bash
      get_GFS_analysis_parallel.bash

    - If these have a size of 0, use `FNL analysis files at lower resolution <https://rda.ucar.edu/datasets/ds083.2/index.html#!description>`_.  

        - The Globus Transfer Service (GridFTP) option to transfer the FNL files from the RDA.  
        - The other option is to go to that link, click data access, click web file listing for either GRIB1 (pre 2007.12.06) or GRIB2 (post 2007.12.06), click complete file list, click on the year of interest within the group ID column and checkbox the timeframe you're interested in. Now either click csh download script and follow the instructions in the comments of the script (remembering to change your linux shell to csh), or click get as a tar file (though this is limited to 2GB), or again there is the option for globus.
        - To download for more than 1 day at a time. First changing the script to the time frame required, ensuring download for the spin-up timeframe too.  

    - Go over GFS folder to check have 8 files per day for each day of simulation.  

    .. code-block:: bash

      .find_missing_GFS.bash
      qsub find_missing_GFS_parallel.bash

    - Rename FNL files to original GFS naming convention and copy for 3 hourly interval midpoints.

- Acquire MOZART (MZ4) files for chemical initial and boundary conditions.  

    - Pre-2018:  

        - Download `MZ4 <http://www.acom.ucar.edu/wrf-chem/mozart.shtml>`_.  
        - Download `CAM-Chem <https://www.acom.ucar.edu/cam-chem/cam-chem.shtml>`_.  

    - Post-2018:

        - Download `WACCM <https://www.acom.ucar.edu/waccm/download.shtml>`_. 

    - Ensure for a month have day either side of time frame of interest, and go for global domain.  

- Emissions.  

    - Choose anthropogenic input namelist setting in config.bash.  

    .. code-block:: bash

      cd /nobackup/${USER}/WRFotron
      vi emis_edgarhtap2_mozmos.inp

    - Fire emissions (FINN).  

        - Update :code:`fire_emis.mozm.inp` to have to correct filename for the year of simulation  careful to update file for the correct chemical mechanism.  

- :code:`config.bash`.  

    - Check all directories are correct.  
    - Change where WRFChem will run.  
    - Keep the same name for synchronous runs.  
    - Or if a new simulation, change.  

        - workDir / achiveRootDir / restartRootDir.  

- Check :code:`pre.bash`.  

    - Check the linked MZ4 files are for timeframe required e.g. 2015.  
    - If using daily files, use this portion of code and comment out the monthly section.  
    - Vice versa for if using monthly files.  

- :code:`namelist.wps.blueprint`.  

    - Change domain, resolution, map projection, and map area.  
    - Edit :code:`namelist.wps.domain_test` to try out different domain settings.  
    - Create domain plot :code:`ncl plotgrids.ncl`.  
    - View the PDF of the domain :code:`evince wps_show_dom.pdf`.  
    - When decided update setting in :code:`namelist.wps.blueprint`.  

- :code:`namelist.wrf.blueprint`.  

    - Change domain, resolution, and number of levels.  

- :code:`namelist.chem.blueprint`.  

    - Change chemistry options.  
    - See WRFChem User Guide.  

- :code:`master.bash`.  

    - Calling master.bash without arguments gives you usage instructions:  

    .. code-block:: bash

      . master.bash

      $ Call with arguments <year (YYYY)> <month (MM)> <day (DD)> <hour (hh)> ...    
      $                 or <year (YYYY)> <month (MM)> <day (DD)> <hour (hh)> ...  
      $ possible options (have to go before arguments):  
      $                  -e <experiment name>  
      $                  -c <chain directory (submission from CRON)>  


    - Master.bash submits :code:`pre.bash`, :code:`main.bash`, and :code:`post.bash`.  
    - Creates output, restart, and run directories on /nobackup/${USER}.  

        - /run/base/startdate_enddate.  

    - In this folder is all the files copied over with the settings updated in all the bash scripts (master, pre, main, post, config).  
    - Test run for 24 hours.  

    .. code-block:: bash

      . master.bash 2016 10 05 00 24 06

    - Start year / start month / start day / start hour (UTC time) / simulation length / spin up length.  
    - Spin-up runs from 2016-10-04_18:00:00 to 2016-10-05_00:00:00.  
    - Simulation runs from 2016-10-05_00:00:00 to 2016-10-06_00:00:00.  
    - Check linked files were for this ${USER}.  

    - Now make another run starting when the first one finishes, which will use the output of the previous run for chemistry initial conditions (rather than MOZART chemical boundary conditions), while re-initialising meteorology (from GFS/ECMWF data):

    .. code-block:: bash

      . master.bash 2016 10 05 00 24 06 999999

    - The 999999 is the job id for the :code:`main.bash` from the previous run. This is used in the syntax to tell the HPC machine to wait until this job has finished before starting the new run. This is because the new run uses the files created from the first run. This allows you to submit several runs in a row at the same time, each of them restarting using the result of the previous run.
    - Four-dimension data assimilation (FDDA, i.e. re-initialisation of meteorology).  

    .. code-block:: bash

      vi master.bash
      S/GRIDFDDA/0/g # to turn it off
      S/GRIDFDDA/1/g # to turn it on  

    - Nudges horizontal and vertical wind, potential temperature and water vapor mixing ratio to analyses. It doesn’t take the analyses fields for its values like some other models do. It uses them as initial conditions and then uses the primitive atmospheric equations. This is not for chemistry directly, though affects chemicals through transport.  

    - After each successful WRFotron run, wrfrst restart files are saved in the restart directory. When a new run is called using :code:`master.bash`, a meteo-only spinup run is made first, and a restart file is created at its end, now containing only "fresh" meteorology variables. It is then checked whether a restart file (with chemistry) from a previous run exists in the common restart directory. If this is the case, only the chemistry variables are copied from the previous run's restart file to the meteo spinup restart file. Then, a WRFChem run is started using this combined restart file as initial conditions, thereby using "fresh" meteorology while carrying on chemistry variables across runs. In case no restart file is found, a "cold start" chemistry run is conducted, starting with MOZART global model forecast values as initial conditions.

- If need to re-submit any parts of the simulation, from within the folder, make changes to the relevant bash script and then:  

.. code-block:: bash

  qsub pre.bash  
  qsub main.bash  
  qsub post.bash

- Approximate job run times and HPC requirements:
 
    - 1 day simulation takes 1 hour wall clock time approximately.  
    - 1 month simulation takes 2 days wall clock time approximately.  
    - 1 year simulations takes 1 month wall clock time approximately.  
    - :code:`pre.bash` = 7 hours, 1 core, 32GB/process (run in serial).
    - :code:`main.bash` = 48 hours, 32 cores, 1GB/process (run in parallel).
    - :code:`post.bash` = 48 hours, 4 core, 12GB/process (run in parallel).

