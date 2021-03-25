*****************
Manual Simulation
*****************
Independently run a 24 hour simulation for India from 2016 10 05.

- Check you have the GFS data you need for the dates required to initialise and force meteorological conditions (1 file per 3 hours, 8 files per day, none are too small):  

.. code-block:: bash

  cd /nobackup/${USER}
  mkdir initial_boundary_meteo_gfs 
  cd initial_boundary_meteo_gfs
  cp /nobackup/WRFChem/initial_boundary_meteo_gfs/GF201610{04..07}* .

- If require more GFS data, can copy more over from :code:`/nobackup/WRFChem/initial_boundary_meteo_gfs` or can use the download scripts :code:`get_GFS_analysis_2004-current.bash` and :code:`get_GFS_analysis_parallel.bash` within :code:`cd /nobackup/WRFChem/download_and_find_gfs_mz4`.
- Create a test run folder for the manual run of WRF:  

.. code-block:: bash

  cd /nobackup/${USER}/
  mkdir testrun

- Copy :code:`link_grib.csh` to the new folder.  

.. code-block:: bash

  cd /nobackup/${USER}/testrun
  cp /nobackup/WRFChem/testrun_files/link_grib.csh .

- Link the required GFS data via :code:`link_grib.csh` in to the new simulation folder.  

.. code-block:: bash

  ./link_grib.csh /nobackup/${USER}/initial_boundary_meteo_gfs/GF201610*

- Copy over the ungrib, geogrid and metgrid folders.  

.. code-block:: bash

  cp -r /nobackup/WRFChem/testrun_files/ungrib .
  cp -r /nobackup/WRFChem/testrun_files/geogrid .
  cp -r /nobackup/WRFChem/testrun_files/metgrid .

- Link the ungrib, geogrid and metgrid executables from the folders that are now copied over.  

.. code-block:: bash

  ln -sf metgrid/src/metgrid.exe
  ln -sf geogrid/src/geogrid.exe
  ln -sf ungrib/src/ungrib.exe

- Copy over the WPS and input namelists.  

.. code-block:: bash

  cp /nobackup/WRFChem/testrun_files/namelist.wps .
  cp /nobackup/WRFChem/testrun_files/namelist.input .

- Link to the variables table.  
- If post-2015 simulation, use new variable table:  

.. code-block:: bash

  ln -sf /nobackup/WRFChem/Vtable.GFS_new Vtable

- If pre-2015 simulation, use old variable table:

.. code-block:: bash

  ln -sf /nobackup/WRFChem/Vtable.GFS Vtable

- Copy over the WRF and real executables, and the WRF and real bash scripts for job submission.  

.. code-block:: bash

  cp /nobackup/WRFChem/testrun_files/real.exe .
  cp /nobackup/WRFChem/testrun_files/real.bash .
  cp /nobackup/WRFChem/testrun_files/wrf.exe .
  cp /nobackup/WRFChem/testrun_files/wrf.bash .

- Edit the time for the run on the WPS namelist according to the new requirements for the simulation. Be careful for leap years, and any changes made in the WPS namelist have to mirrored if the same variables are present in the input namelist.  

    - start_date = '2016-10-05_00:00:00'.  
    - end_date   = '2016-10-06_00:00:00'.  
    - number of domains (use 1).  
    - spatial resolution (dx and dy).  
    - map projection (i.e. Lambert conformal, Mercator, polar stereographic, or Regular latitude-longitude also known as cylindrical equidistant).  
    - If lambert, dx and dy are in metres.  
    - Uses projection parameters: truelat1, truelat2, stand_lon.  
    - See page 37 of WRF User Guide.  
    - Update and edit the namelist.input.  
    - make sure the run_hours, start date, end date, timestep, e_we, e_sn, dx, dy are the same here as they are in the namelist.wps.  
    - time step for integration seconds (recommended 6*dx in km for a typical case).  

- Load the netCDF module.  

.. code-block:: bash

  module load netcdf
  export NETCDF=$(nc-config --prefix)
  export NETCDF_DIR=$NETCDF

- Run geogrid.  

.. code-block:: bash

  ./geogrid.exe

- Configures the horizontal domain, interpolating static geographical data.  

    - Creates geography (:code:`geo_em.d01.nc`) for each domain.  
    - Progress logged in geogrid.log.  

- Run ungrib.  

.. code-block:: bash

  ./ungrib.exe

- Reads, reformats, and extracts meteo input data.  

    - Creates meteorology by ungribbing the GFS grb2 files.  
    - Intermediate files for every time step.  
    - Progress logged in ungrib.log.  

- Run metgrid.  

.. code-block:: bash

  ./metgrid.exe   

- Ingests and interpolates input data creating initial and boundary meteorological conditions.  

    - Creates :code:`met_em.d01.2016-02-25_00:00:00.nc` for every 6 hour time step, for both domains.  
    - Also metgrid.log.  

- Copy the anthro_emiss, wesely, exo_coldens, megan_bio_emiss, mozbc executables.  

.. code-block:: bash

  cp /nobackup/WRFChem/testrun_files/anthro_emis .
  cp /nobackup/WRFChem/testrun_files/wesely .
  cp /nobackup/WRFChem/testrun_files/exo_coldens .
  cp /nobackup/WRFChem/testrun_files/megan_bio_emiss .
  cp /nobackup/WRFChem/testrun_files/mozbc .

- Copy the input files for these executables.  

.. code-block:: bash

  cp /nobackup/WRFChem/testrun_files/emis_edgarhtap2_mozmos.inp .
  cp /nobackup/WRFChem/testrun_files/wesely.inp .
  cp /nobackup/WRFChem/testrun_files/exo_coldens.inp .
  cp /nobackup/WRFChem/testrun_files/megan_bio_emiss.inp .
  cp /nobackup/WRFChem/testrun_files/mozbc.inp .

- Copy over the run subdirectory from WRF.  

.. code-block:: bash

  cp -r /nobackup/${USER}/WRFChem/run/* .

- Remove the testrun version of real.exe and wrf.exe and copy the freshly compiled versions.  

.. code-block:: bash

  rm real.exe
  rm wrf.exe
  cp /nobackup/${USER}/WRFChem/main/real.exe .
  cp /nobackup/${USER}/WRFChem/main/wrf.exe .

- Link the required MOZART chemical boundary condition files (need previous day too for spin up).  

.. code-block:: bash

  cd /nobackup/

  cd /nobackup/${USER}
  mkdir initial_boundary_chem_mz4
  cd initial_boundary_chem_mz4
  cp /nobackup/${USER}/initial_boundary_chem_mz4/MZ2016oct .
  cd /nobackup/${USER}/testrun
  ln -sf /nobackup/${USER}/initial_boundary_chem_mz4/MZ2016oct moz0000.nc

- Pre-2018:

    - Download `MZ4 <http://www.acom.ucar.edu/wrf-chem/mozart.shtml>`_.  
    - Download `CAM-Chem <https://www.acom.ucar.edu/cam-chem/cam-chem.shtml>`_. 

- Post-2018:

    - Download `WACCM <https://www.acom.ucar.edu/waccm/download.shtml>`_.  
    - Note the directory needs to change in config.bash (:code:`MOZARTdir`).  

- Can access individual days using the script.  

.. code-block:: bash

  cd /nobackup/WRFChem/download_and_find_gfs_mz4
  . get_MZ4_fcst.bash YYYY MM DD

- Edit bash script for real.exe.  

.. code-block:: bash

  vi real.bash

- This has all the requirements for time, nodes, cores, processors.  

    - 1 core required, with h_vmem 6GB.  
    - May need to change/remove the project code.  
    - Before running real.exe, may need to comment out (with a ! in Fortran) in namelist.input aux_input_6 for megan_bio_emiss (3 lines which relates to this).  

- Check namelists, run real, and check progress.  

.. code-block:: bash

  qsub real.bash

- Interpolates between the intermediate files to create the time domain data at the prescribed time intervals.  

.. code-block:: bash

  qstat

- When complete, creates:  

    - :code:`real.bash.o3502300`.  

        - Output from the job submission script (MPI output from job id 3502300).  

    - :code:`real.bash.e3502300`.  

        - Error from the job submission script (MPI output from job id 3502300).  

    - :code:`namelist.output`.  

        - :code:`wrfinput_d01` (for initial conditions).  
        - :code:`wrfinput_d02` (for initial conditions).  
        - :code:`wrfbdy_d01` (for boundary conditions).  

    - Check :code:`rsl.error*` that the run was successful.  

        - If it fails, the wrfinput and wrfbdy won't be created.  

    - Check in :code:`rsl.error*` and :code:`rsl.out*` files for each core.  

- Edit namelist for biogenic emissions.  

.. code-block:: bash

  vi megan_bio_emiss.inp

- Run MEGAN.  

.. code-block:: bash

  ./megan_bio_emiss < megan_bio_emiss.inp

- Creates for both domains (:code:`wrfbiochemi_d*`).  
- Edit and run mozbc.  

.. code-block:: bash

  vi mozbc.inp

- Domain 1, :code:`do_ic = .true`.  

    - Updates :code:`wrfinput_d01` (NetCDF) with initial conditions.  

- Domain 1, :code:`do_bc = .true`.  

    - Updates :code:`wrfbdy_d01` (NetCDF) with boundary conditions.  

- If ncview wrfbdy_d01, then can see the 2D curtains in space of the boundary conditions (think of box walls), i.e. T is transect or not, X or Y domain, E east or S south.  

    - Domain 2, :code:`do_ic = .true`.  

- Updates :code:`wrfinput_d02` (netCDF) with initial conditions for the nested domain, as gets its boundary conditions from the outer domain.  

.. code-block:: bash

  ./mozbc < mozbc.inp

- Run wesely.  

    - Reads, reformats, and extracts input data for dry deposition.  
    - Copy over the :code:`season_wes_usgs.nc` file.  
    - Creates :code:`wrf_season_wes_usgs_d01.nc` and :code:`wrf_season_wes_usgs_d02.nc`.  

.. code-block:: bash

  cp /nobackup/WRFChem/wes-coldens/season_wes_usgs.nc .
  ./wesely < wesely.inp

- Run EXO COLDENS. 

    - Reads, reformats, and extracts input data.  
    - Copy over the :code:`exo_coldens.nc` file.  
    - Creates :code:`exo_coldens_d01` and :code:`exo_coldens_d02`.

.. code-block:: bash

  cp /nobackup/WRFChem/wes-coldens/exo_coldens.nc .
  ./exo_coldens < exo_coldens.inp

- Edit anthropogenic namelist (check the NO/NO2 ratio from NOX is correct for your domain).  

.. code-block:: bash

  vi emis_edgarhtap2_mozmos.inp

- Run anthro_emis.  

.. code-block:: bash

  ./anthro_emis < emis_edgarhtap2_mozmos.inp

- Run for both domain 1 and 2 separately.  

    - Change the :code:`start_output_time` and :code:`stop_output_time`.  
    - Creates :code:`wrfchemi`.  

- Before running :code:`wrf.exe`, may need to comment back in (removing the !) in namelist.input aux_input_6 for megan_bio_emiss (3 lines which relates to this).  
- Create bash script for wrf.exe.  

.. code-block:: bash

  vi wrf.bash

- This has all the requirements for time, nodes, cores, processors.  

    - 32 cores required.  

- Run wrf.exe.  

.. code-block:: bash

  qsub wrf.bash

- Can follow the progress by tailing the :code:`rsl.error.0000` file.  

.. code-block:: bash

  tail rsl.error.0000

- Can also check jobs running on HPC through.  

.. code-block:: bash

  qstat

- Creates:  

    - wrfout files per hour.  
    - rsl.out.* (for each core).  
    - rsl.error.* (for each core). 
 
- Check linked files were for this ${USER}.  
- Post-processing.  

    - Not doing in the test run.  

- To view wrfout files (without the post-processing).  

.. code-block:: bash

  conda activate ncview
  ncview wrfout*

