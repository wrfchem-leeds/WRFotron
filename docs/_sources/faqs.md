# Frequently Asked Questions

## Recommendations

- Submit runs individually and quality control.  
- Check all steps in the process have run correctly.  
- Check main.bash.o has “substituting initial chemistry from restart” if do not want a cold start.  
- Manage space requirements, as run and output folders can get very large.  
- Run `main.bash` in 2 week chunks to fit within 48 hours.  
- Information on improving performance [here](https://github.com/wrfchem-leeds/WRFotron/issues/29).  
- A selection of data science scripts using Python [here](https://github.com/wrfchem-leeds/python-scripts). 

## Troubleshooting and errors

- Find the errors' first occurance, checking rsl.error, rsl.out, .e, .o, and .log files within the run folder.  
- You need to make sure all programs are compiled and useable, and that the paths in your config.bash point to the correct locations.  
- You need to ensure that your data is all available for the period you want to simulate (including meteo spin-up).  
- You need to ensure your namelists are correct.  
- [If the error if related to a FORTRAN run-time error](https://software.intel.com/en-us/fortran-compiler-developer-guide-and-reference-list-of-run-time-error-messages).  
- [Check WRF FAQ's](http://www2.mmm.ucar.edu/wrf/users/FAQ_files/).  
- [Check WRF forums](http://forum.wrfforum.com/).  
- Check Google groups for:  
    - [WRFChem](https://groups.google.com/a/ucar.edu/forum/#!forum/wrf-chem).  
    - [fire_emiss](https://groups.google.com/a/ucar.edu/forum/#!forum/wrf-chem-fire_emiss).  
    - [anthro_emis](https://groups.google.com/a/ucar.edu/forum/#!forum/wrf-chem-anthro_emiss).  
    - [Runs](https://groups.google.com/a/ucar.edu/forum/#!forum/wrf-chem-run).  
- Try increasing the debug level.  
- Timesteps for meteorology (time_step in namelist.wrf), chemistry (chemdt in namelist.chem), and biogenics (bioemdt in namelist.chem) need to match (careful of units).  
- If no error message given at the bottom of rsl.error. file:  
    - Potentially a violation of the CFL criterion:  
        - Try reducing the timestep.  
        - Try turning w_damping off.  
    - Potentially a memory error:  
        - Increase the number of cores.  
        - Increase the memory per core.  
        
## Download ECMWF meteorlogy files

- [Create an account with ECMWF](https://apps.ecmwf.int/registration/).  
- [Follow the steps](https://confluence.ecmwf.int/display/WEBAPI/Access+ECMWF+Public+Datasets).  
- Login.  
- Retrieve your key.  
- Copy the information to `~/.ecmwfapirc`
- Create a python2 environment for ecmwf-api-client (this library has not yet been updated for python 3).  
    ```bash
    conda create -n python2_ecwmf -c conda-forge ecmwf-api-client
    ```
- Go to the folder `initial_boundary_meteo_ecmwf`.
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

## To run with a nest

Offline nests:
- See [step-by-step guide to run with a nest document from Carly Reddington](https://github.com/wrfchem-leeds/WRFotron/blob/master/guides/Guide_to_offline_nesting_CR.pdf).  
- Uses ndown.exe for one-way nesting
- Feedback = 0
- Parent and nest domain may drift apart

Online nests:
- Turn off urban physics (i.e. `sf_urban_physics = 0, 0, 0`) in physics subsection of namelist.wrf.  
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
    - `&domains`
        - `smooth_option = 0`
    - `&physics`
        - `cugd_avedx = 3`
        - `smooth_option = 0`
        - `cu_rad_feedback = .false.`
        - `cu_diag = 0`
        - `slope_rad = 1`
        - `topo_shading = 1`
    - `&dynamics`
        - `non_hydrostatic = .false.`

## To run with cumulus parameterisation off

`Namelist.chem`
- `cldchem_onoff = 1`
- `chem_conv_tr = 0` (subgrid convective transport)
- `conv_tr_wetscav = 0` (subgrid convective wet scavenging)
- `conv_tr_aqchem = 0` (subgrid convective aqueous chemistry)

`Namelist.wps`
- Resolution < 5 km

`Namelist.wrf`
- Resolution < 5 km
- `cu_physics = 0` (cumulus parameterization off)
- `cugd_avedx = 3` (number of grid boxes over which subsidence is spread)

`Master.bash`, turn off nudging
- `s/GRIDFDDA/0/g`

## Changes for WRFChem4

Select updates for WRFChem4
- Bug fixes:
    - NOAH land surface scheme
    - Thompson microphysics scheme
    - Boundary layer and surface schemes from MYNN.
    - Chemical reaction rate constant for reaction: SO<sub>2</sub> + OH -> SO<sub>4</sub>
    - Dust < 0.46 microns contribution to AOD.
    - Dust and salt bin contributions to AOD.
    - Urban physics.
    - Fires (`module_mosaic_addemiss.F`).
    - glysoa not needed as no longer uses to_toa variable which has the summation error (`module_mosaic_driver.F`).
    - `GEOGRID.TBL` within WPS4/geogrid is a hard copy of the `GEOGRID.TBL.ARW_CHEM` including erod.
- New defaults
    - Hybrid sigma-pressure vertical coordinate.
    - Temperature variable is now moist theta. 
    - Method to compute vertical levels, smooth variation of dz.
- Various improved options available:
    - RRTMK (`ra_sw_physics = 14`, `ra_lw_physics = 14`) improves RRTMG

## To run with WRFChem3.7.1 or WRFChem4.2
Within `config.bash`:
- Replace all instances of 4.2 with 3.7.1, or vice-versa.
- Use the appropriate geography files, being either `/nobackup/WRFChem/WPSGeog3` or `/nobackup/WRFChem/WPSGeog4`.

Within `namelist.wps.blueprint`:
- For the `geog_data_res` variable (within `&geogrid`), use `'modis_30s+30s'` for WRFChem3.7.1 and use `'default'` for WRFChem4.2.

Within `namelist.wrf.blueprint`:
- Remove the `force_use_old_data` variable (within `&time_control`) for WRFChem3.7.1 and have it set to `T` for WRFChem4.2.
- For the `num_metgrid_soil_layers` variable (within `&domains`), use `4` for WRFChem3.7.1 and `3` for WRFChem4.2.
- For the `num_soil_layers` variable (within `&physics`), use `4` for WRFChem3.7.1 and `3` for WRFChem4.2.
- For the `num_land_cat` variable (within `&physics`), use `20` for WRFChem3.7.1 and `21` for WRFChem4.2.

## To run with a diurnal cycle

Choosing the diurnal cycle:
- There are several different diurnal cycles in WRF_UoM_EMIT.
- They are contained in the `emission_script_data*.ncl` files. Whichever of these files is named emission_script_data.ncl will be the diurnal cycle that is read by `MAIN_emission_processing.ncl`. The current `emission_script_data.ncl` is a copy of `emission_script_data_EU.ncl`.
    - EU = European diurnal cycles based on Olivier et al 2003
    - EX = Exaggerated diurnal cycle with 99% of emissions during daytime
    - QH = Qinghua diurnal cycle
- Change settings in `MAIN_emission_processing.ncl`
    - `time_offset`
    - `oc_om_scale`
- To check if the diurnal cycle application was successful, run the following python script, which should be within WRF_UoM_EMIT, and is automatically linked to your run folder during pre.bash. Take a copy of the file from the following location if you don’t have it:  
    ```bash
    python plot_wrfchemi.py
    ```

## To run with NAEI emissions

[Follow the guide created by Ailish Graham](https://github.com/wrfchem-leeds/WRFotron/blob/master/guides/Guide_to_NAEI_emissions_AG.pdf).  

## To add (or remove) variables to wrfout files

- First, check whether the variable is in the Registry. If it isn't, then add it using the steps [here](https://www.climatescience.org.au/sites/default/files/WRF_gill_registry.pdf).  
- Then, if you're running with chemistry edit the file `iofields.chem`, otherwise edit the file `iofields.met`, which are both in WRFotron.  
- There are lines of text such as:  
    ```bash
    +:h:0:ccn1,ccn2,ccn3,ccn4,ccn5,ccn6
    ```
- The + is to add or - is to remove a variable.
- The h is for the history (wrfout) stream. Can have history, restarts, or both.
- The 0 is for the stream number. Generally, stream numbers of 10-24 are okay, and avoid 22-23.
- Then list the variables.

## To include upper boundary conditions

- Turn on the `have_bcs_upper` boolean within `namelist.chem.blueprint`.  
- Set the lowest pressure level where the upper boundary concentrations are overwritten: `fixed_ubc_press` variable, default is 50 (hPa).  
- Provide 2 data files: a climatology for tropopause levels (`clim_p_trop.nc`) and an input file with upper boundary conditions for gas species (`fixed_ubc_inname`).  
    - Climatologies for 4 different time periods derived from WACCM RCP simulations are [here](https://www2.acom.ucar.edu/wrf-chem/wrf-chem-tools-community). A direct download link is [here](http://www.acom.ucar.edu/wrf-chem/UBC_inputs.tar). Within here is the `clim_p_trop.nc` file, along with the 4 different climatology time periods: `ubvals_b40.20th.track1_1950-1959.nc`, `ubvals_b40.20th.track1_1980-1989.nc`, `ubvals_b40.20th.track1_1996-2005.nc`, and `ubvals_rcp4_5.2deg_2020-2029.nc` where the years used to produce the climatology are specified in the file names.  
- Copy the climatology files over to each run folder by adding the following to the bottom of `pre.bash`:  
    ```bash
    msg "bringing over upper boundary condition files"  
    cp /nobackup/${USER}/where_you_place_these_files/{clim_p_trop.nc,ubvals_b40.20th.track1_1996-2005.nc} .  
    ```
- More information is [here](https://www2.acom.ucar.edu/sites/default/files/wrf-chem/8A_2_Barth_WRFWorkshop_11.pdf) and within Chapter 2 [here](https://github.com/wrfchem-leeds/WRFotron/blob/master/guides/MOZCART_UsersGuide.pdf).  

## To run with the chemistry option T1-MOZCART (chem_opt = 114)

- Replace the contents of `mozbc.inp` with that from `mozbc.inp.blueprint_114_mz4`.  
- Delete ONIT from boundary condition input file (i.e. `moz0001.nc`), as this is not currently in our version of WRFChem.  
- Delete N2O from boundary condition input file (i.e. `moz0001.nc`), as this is not in the MOZBC netcdf file.  
- Make the following changes to `namelist.chem.blueprint`:  
  - `cldchem_onoff = 0`, was previously 1.  
  - `biomass_burn_opt = 4`, was previously 2.  
- Make the following change to `namelist.wrf.blueprint`:  
  - `auxinput6_inname = 'wrfbiochemi_d<domain>', ! biogenic emission filename`, was previously `'wrfbiochemi_d<domain>_<date>'`.    
- More information is [here](https://github.com/wrfchem-leeds/WRFotron/blob/master/guides/T1-MOZCART-UsersGuide-27April2018.pdf).  

## Benchmarking and Testing 

- Run together automatically by submitting `. benchmark_and_test.bash`.  
- This runs short (48 hour) simulations per season over the default domain and evaluates against either the China measurements or from OpenAQ.  
- To select which measurement set the model is evaluated against, set the corresponding Boolean in `benchmark.py`.  
- They run from the output directory, and can both be run manually using `qsub benchmark.bash` and `qsub tests.bash`.
- To discuss these further and suggest improvements, see the discussions for them: [Benchmarks](https://github.com/wrfchem-leeds/WRFotron/discussions/34) and [Tests](https://github.com/wrfchem-leeds/WRFotron/discussions/33).  

## Run WRFChem for long-term scenarios

- See information from this [NCAR technical note](http://dx.doi.org/10.5065/D6445JJ7) and [CLWRF (CLimate WRF)](https://www.meteo.unican.es/en/software/clwrf).  

## Misc.

- To see details of all the variables, see the registry files e.g. for chemistry: `WRFChem{version}/Registry/registry.chem`  
- To see the equations used for your mechanism, see the file: `WRFChem{version}/chem/KPP/mechanisms/{mechanism}/{mechanism}.eqn`  
- To see the variable mappings between the mechanism and WRFChem (which can have different names), see the file: `WRFChem{version}/chem/KPP/mechanisms/{mechanism}/{mechanism}.equiv`  
- To see the rate constants used per equation, see the file (note, that these match the equations in sequential order e.g., the final rate constant for equation 346 matches to equation {S060}): `WRFChem{version}/chem/KPP/mechanisms/{mechanism}/{mechanism}_Rates.f90`  