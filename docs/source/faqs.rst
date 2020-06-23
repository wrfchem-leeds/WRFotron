**************************
Frequently Asked Questions
**************************
Recommendations
===============
- Submit runs individually and quality control.  
- Check all steps in the process have run correctly.  
- Check main.bash.o has “substituting initial chemistry from restart” if do not want a cold start.  
- Manage space requirements, as run and output folders can get very large.  
- Make use of CPU affinity to have dedicated input/output processors, as these are not scalable in WRF-Chem:

    - Within namelist.wrf.blueprint:

        - &namelist_quilt

            - nio_tasks_per_group = 5 ! number of processors used for IO quilting per IO group.  
            - nio_tasks_per_group = 2 ! number of quilting groups
            - So the number of cores = nproc_x * nproc_y + nio_groups * nio_tasks_per_group
            - For example, 42 = 4 * 8 + 2 * 5

- `LC and BS have created a selection of data science scripts using Python <https://github.com/wrfchem-leeds/python-scripts>`_. 

Troubleshooting and errors
==========================
- Find the errors' first occurance, checking rsl.error, rsl.out, .e, .o, and .log files within the run folder.  
- You need to make sure all programs are compiled and useable, and that the paths in your config.bash point to the correct locations.  
- You need to ensure that your data is all available for the period you want to simulate (including meteo spin-up).  
- You need to ensure your namelists are correct.  
- `If the error if related to a FORTRAN run-time error <https://software.intel.com/en-us/fortran-compiler-developer-guide-and-reference-list-of-run-time-error-messages>`_.  
- `Check WRF FAQ's <http://www2.mmm.ucar.edu/wrf/users/FAQ_files/>`_.  
- `Check WRF forums <http://forum.wrfforum.com/>`_.  
- Check Google groups for:  

    - `WRFChem <https://groups.google.com/a/ucar.edu/forum/#!forum/wrf-chem>`_.  
    - `fire_emiss <https://groups.google.com/a/ucar.edu/forum/#!forum/wrf-chem-fire_emiss>`_.  
    - `anthro_emis <https://groups.google.com/a/ucar.edu/forum/#!forum/wrf-chem-anthro_emiss>`_.  
    - `Runs <https://groups.google.com/a/ucar.edu/forum/#!forum/wrf-chem-run>`_.  

- Try increasing the debug level.  
- Timesteps for meteorology (time_step in namelist.wrf), chemistry (chemdt in namelist.chem), and biogenics (bioemdt in namelist.chem) need to match (careful of units).  
- If no error message given at the bottom of rsl.error. file:  

    - Potentially a violation of the CFL criterion:  

        - Try reducing the timestep.  
        - Try turning w_damping off.  

    - Potentially a memory error:  

        - Increase the number of cores.  
        - Increase the memory per core.  
        
Download ECMWF meteorlogy files
===============================
- `Create an account with ECMWF <https://apps.ecmwf.int/registration/>`_.  
- `Follow the steps <https://confluence.ecmwf.int/display/WEBAPI/Access+ECMWF+Public+Datasets>`_.  
- Login.  
- Retrieve your key.  
- Copy the information to ~/.ecmwfapirc
- Create a python2 environment for ecmwf-api-client (this library has not yet been updated for python 3).  

.. code-block:: bash

  conda create -n python2_ecwmf -c conda-forge ecmwf-api-client

- Go to the folder initial_boundary_meteo_ecmwf.
- Edit the python scripts:

    - Both surface and pressurelevels.
    - Only need to change the date and target name.

- Qsub the .bash scripts
- Edit pre.bash to comment out the GFS and comment in the ECMWF files
- Ensure the date and target name correspond to those you want to run with
- Change the number of meteorological vertical levels from 27 (GFS) to 38 (ECMWF)
- Also, the number of meteorological soil levels from 4 (GFS):

    - To 3 for ECMWF with WRFChem4
    - To 4 for ECMWF with WRFChem3

To run with a nest
==================
- Offline nests:

    - See step-by-step guide to run with a nest document from Carly Reddington [here](https://github.com/wrfchem-leeds/WRFotron/blob/master/additional_docs/Guide_to_offline_nesting_CR.pdf).  
    - Uses ndown.exe for one-way nesting
    - Feedback = 0
    - Parent and nest domain may drift apart

- Online nests:

    - Turn off urban physics (i.e. sf_urban_physics = 0, 0, 0) in physics subsection of namelist.wrf.  
    - Requires a large amount of cores, as memory intensive
    - Uses wrf.exe for two-way nesting
    - Feedback = 1
    - Have an odd number for the parent_grid_ratio.
    - For nest 2, (e_we-s_we+1) must be one greater than an integer multiple of the parent_grid_ratio (3 or 5).
    - WRF will decompose each domain in the exact same way, so ensure all the domains are similar shapes (i.e. don’t have a square domain within a rectangular domain, or even a rectangular domain which is longer in the x-direction within another domain which is longer in the y-direction).  
    - Check all namelist settings and check all required nest parameters are set (use registry to check which parameters need to be set for every domain).
    - All variables with dimension = max_domains or (max_dom) need to be set for the nests
    - Careful the domains are not too big, otherwise wrfinput won’t be created
    - Use same physics options and physics calling options e.g. radt/cudt

        - An exception is cumulus scheme. One may need to turn it off for a nest that has grid distance of a few kilometers or less.

    - For nest, e_we and e_sn for a parent_grid_ratio of 3 must be return a whole number when minus 1 and divide by parent_grid_ratio (3)
    - Decrease restart_interval to 720 (2/day) from 360 (4/day)
    - Tests with less than 24 hours break the coarsest domains mozbc
    - Add diurnal cycle for all domains:

        - Within MAIN_emission_processing.ncl, change to all domains.

    - Timestep:

        - Decrease propotionally

    - Radiation timestep should coincide with the finest domain resolution (1 minute per km dx), but it usually is not necessary to go below 5 minutes. All domains should use the same value, so that radiation forcing is applied at the same time for all domains.
    - Other namelist.wrf settings specific for domains < 3km res

        - &domains

            - smooth_option = 0

        - &physics

            - cugd_avedx = 3
            - smooth_option = 0
            - cu_rad_feedback = .false.
            - cu_diag = 0
            - slope_rad = 1
            - topo_shading = 1

        - &dynamics

            - non_hydrostatic = .false.

To run with cumulus parameterisation off
========================================
- Namelist.chem

    - cldchem_onoff = 1
    - chem_conv_tr = 0 (subgrid convective transport)
    - conv_tr_wetscav = 0 (subgrid convective wet scavenging)
    - conv_tr_aqchem = 0 (subgrid convective aqueous chemistry)

- Namelist.wps

    - Resolution < 5 km

- Namelist.wrf

    - Resolution < 5 km
    - cu_physics = 0 (cumulus parameterization off)
    - cugd_avedx = 3 (number of grid boxes over which subsidence is spread)

- Master.bash, turn off nudging

    - s/GRIDFDDA/0/g

Changes for WRFChem4
==============================
- Select updates for WRFChem4

    - Bug fixes:

        - NOAH land surface scheme
        - Thompson microphysics scheme
        - Boundary layer and surface schemes from MYNN.
        - Chemical reaction rate constant for reaction: |SO2| + OH -> |SO4|

            .. |SO2| replace:: SO\ :sub:`2`
            .. |SO4| replace:: SO\ :sub:`4`

        - Dust < 0.46 microns contribution to AOD.
        - Dust and salt bin contributions to AOD.
        - Urban physics.
        - Fires (module_mosaic_addemiss.F).
        - glysoa not needed as no longer uses to_toa variable which has the summation error (module_mosaic_driver.F).
        - GEOGRID.TBL within WPS4/geogrid is a hard copy of the GEOGRID.TBL.ARW_CHEM including erod.

    - New defaults

        - Hybrid sigma-pressure vertical coordinate.
        - Temperature variable is now moist theta. 
        - Method to compute vertical levels, smooth variation of dz.

    - Various improved options available:

        - RRTMK (ra_sw_physics=14, ra_lw_physics=14) improves RRTMG

- Setting changes

    - namelist.wps.blueprint

        - Need to change geog_data_res from ‘modis_30s+30s ‘ to ‘default’

    - Namelist.wrf.blueprint

        - Num_metgrid_soil_layers from 4 to 3
        - Num_soil_layers from 4 to 3
        - Num_land_cat from 20 to 21
        - io_form_auxinput12 = ISRESTARTVALUE

    - master.bash

        - WPS and spin up

            - s/ISRESTARTVALUE/0/g

        - WRFChem

            - s/ISRESTARTVALUE/1/g

    - New static geography files in WPSGeog4

To run with a diurnal cycle
===========================
- Choosing the diurnal cycle:

    - There are several different diurnal cycles in WRF_UoM_EMIT.
    - They are contained in the emission_script_data*.ncl files. Whichever of these files is named emission_script_data.ncl will be the diurnal cycle that is read by MAIN_emission_processing.ncl. The current emission_script_data.ncl is a copy of emission_script_data_EU.ncl.

        - EU = European diurnal cycles based on Olivier et al 2003
        - EX = Exaggerated diurnal cycle with 99% of emissions during daytime
        - QH = Qinghua diurnal cycle

    - Change settings in MAIN_emission_processing.ncl

        - time_offset
        - oc_om_scale

- To check if the diurnal cycle application was successful, run the following python script, which should be within WRF_UoM_EMIT, and is automatically linked to your run folder during pre.bash. Take a copy of the file from the following location if you don’t have it:  

.. code-block:: bash

  python plot_wrfchemi.py

To run with NAEI emissions
==========================
- `Follow the guide created by Ailish Graham <https://github.com/wrfchem-leeds/WRFotron/blob/master/additional_docs/Guide_to_NAEI_emissions_AG.pdf>`_.  

To add (or remove) variables to wrfout files
============================================
- With help from Doug Lowe:

    - In namelist.wrf.blueprint (in the &time_control section) add this line:

    .. code-block:: bash

      iofields_filename                   = 'add_remove_var.txt','add_remove_var.txt','add_remove_var.txt',

    - There is one file per domain, and these can be different.  
    - The file `add_remove_var.txt` needs to be copied into the run folder to be read in.   
    - Inside your add_remove_var.txt file, you’ll have lines of text such as:  

    .. code-block:: bash

      +:h:0:ccn1,ccn2,ccn3,ccn4,ccn5,ccn6

    - The + (to add) or  (to remove) a variable.
    - The h is for the history stream. Can have history, restarts, or both.
    - The 0 is for the stream number. Generally, stream numbers of 10-24 are okay, and avoid 22-23.
    - Then list the variables.
    - `Additional information on pages 19-20 <https://www.climatescience.org.au/sites/default/files/WRF_gill_registry.pdf>`_.  

