# Versions

## 2.3.0 - 04/02/2021

Updates
  - Action needed:
    - Either clone the new repository.
    - Or add the following changes to an existing WRFotron:
      - In `config.bash`, add `netcdf/4.6.3` to the loaded modules.
      - In `namelist.wrf.blueprint`, remove all instances of `auxinput5/6` from the `&time_control` section.
        - This fixes meteorological spin up in CEMAC builds [issue](https://github.com/wrfchem-leeds/WRFotron/issues/24).
      - In `namelist.chem.blueprint`, change `dust_opt` to 13.
        - This replaces dust_opt 3 for WRFChem4.2 [issue](https://github.com/wrfchem-leeds/WRFotron/issues/25).
      - In `pre.bash`, remove duplicate `WRF_UoM_EMIT/` in path for copying over the `final_output` (line 149).
  - No action needed:
    - CEMAC conda module includes python libraries required for post-processing (`pp_concat_regrid.py`) script.
    - CEMAC modulefile for WRFChem4.2 updated for build 2.
      - This fixes the N2O5 chemistry [issue](https://github.com/wrfchem-leeds/WRFotron/issues/23).
    - CEMAC build for WPSChem3.7.1 fixed for geogrid and metgrid.
    - Removed superfluous `anthro_emis.inp` from WRF_UoM_EIT.

## 2.2.0 - 10/11/2020

Updates
- Changing default settings to turn on heterogeneous uptake of N2O5 onto aerosol particles. Within `namelist.chem.blueprint`, `n2o5_hetchem = 1`.  
- Added [introductory Python course](https://github.com/wrfchem-leeds/python-scripts/tree/master/introduction_to_python) for analysing WRFChem output.  
- Added blueprints for CEMAC/manual compilation runs.  
- Added Python postprocessing script.  
- Changed default cores to 64.   

## 2.1.0 - 23/06/2020

Updates
- WRF-Chem4.2  
    - Fixes the performance interval of WRFChem4.0.3 [issue](https://github.com/wrfchem-leeds/WRFotron/issues/4).  
- If still use WRFChem3.7.1, then add aqueous chemistry in stratocumulus clouds in WRFChem3.7.1 [issue](https://github.com/wrfchem-leeds/WRFotron/issues/5).  
- Refactored the GitHub repository:  
    - Converted user guide to readthedocs.io documentation.
    - Focus on CEMAC WRFotron.  
    - Removed old WRFotron code but kept a reference to the settings they used in the user guide.  
    - Removed superfluous files.  
- Added no binding for MPI executions `-bind-to none` in `main.bash` and `main_restart.bash`.  
- Added NCO and chemistry variables list version checks to `main.bash` and `main_restart.bash`.  
- Changed the default memory per core to 2G for `main.bash` and `main_restart.bash`. 

## 2.0.0 - 01/02/2019

Updates
- WRFChem4.0.3.  
- With aqueous chemistry in stratocumulus clouds (`cldchem_onoff = 1`).  
    - Works with WRFChem4.0.3.  
- Biomass burning plume rise throughout the boundary layer (`bbinjectscheme = 2`).  
    - The original option 2 was 50% at the surface and 50% evenly throughout the BL.  
    - The new option 2 has all BB emissions evenly distributed throughout the BL.  
    - To add the bbinjectscheme to any new version of WRFChem see [here](https://github.com/wrfchem-leeds/WRFotron/blob/master/guides/add_bbinjectscheme.md).  
- Diurnal cycle from Olivier et al., (2003).  
- Aerosol optical properties approximated by Maxwell-Garnett.  
- Updated TUV scheme for photolysis (`phot_opt = 4`).  
    - Download the additional data files [here](http://www.acom.ucar.edu/wrf-chem/TUV.phot.bz2) to your `WRFChem/run` folder.  
    - Extract the data directories `DATAE1` and `DATAJ1`, and the `wrf_tuv_xsqy.nc` file from downloaded file using `tar xvf TUV.phot.bz2`.  
- Initial and boundary conditions for chemistry from WACCM for post 2018 or CAM-Chem for pre 2018 [here](https://github.com/wrfchem-leeds/WRFotron/blob/master/guides/CESM-WRFchem_aerosols_plusgas.pdf).  
- Fixed the bug where nudging would stop after 312 hours (i.e. after day 13 of a simulation) i.e. changed `gfdda_end_h` to 10,000.  
- Nudge above the boundary layer. To do this, go into `namelist.wrf.blueprint`, and within the FDDA section change:  
    ```bash
    if_no_pbl_nudging_uv                = 1, 1, 1,                                    ! nudging of u and v in the PBL, 0 = yes, 1 = no
    if_no_pbl_nudging_t                 = 1, 1, 1,                                    ! nudging of t in the PBL, 0 = yes, 1 = no
    if_no_pbl_nudging_q                 = 1, 1, 1,                                    ! nudging of q in the PBL, 0 = yes, 1 = no
    ```
- Hard-coded NCL and NCO commands.  
- Fixed the bug where within the anthro_emiss namelist for EDGAR-HTAP2, NH<sub>3</sub> was incorrectly set as an aerosol i.e. removed (a) in the emis_map.  
- Fixed the bug in plume rise where extra biomass burning mass was added aloft when the thickness of the vertical grid (dz) increases by altitude.  
    - Within `chem/module_chem_plumerise_scalar.F`:  
        - `dz_flam=zzcon(k2)-zzcon(k1-1) ! original version`.  
        - `dz_flam=zzcon(k2+1)-zzcon(k1)   ! fixed version`.  
- Corrected the `metInc` within config.bash for ECMWF to be 6 (3 was for GFS).  
- Added the faster version of post.bash from Helen Burns in CEMAC.  
    - Hard coded NCL and NCO commands in.  
    - Also, removed the deletion of pre-processed and temporary wrfout files from the staging directory, as these are often needed for error diagnosis.

## 1.0.0 - 01/06/2018

Updates
- MOZART-MOSAIC 4 bin, with aqueous chemistry and VBS SOA (`chem_opt = 202`).  
- Without aqueous chemistry in stratocumulus clouds (`cldchem_onoff = 0`).  
    - Does not work with WRF-Chem version 3.7.1.   
- Morrison microphysics (`mp_physics = 10`).  
- Initial and boundary conditions for meteorology from ECMWF.  
- 38 meteoroglogical levels.  
- 3 meteorological soil levels for WRFChem4.0.3 and 4 for WRFChem3.7.1.  
- Consistent timestep for chemistry and biogenics with meteorology.  


## 0.0.0 - 15/10/2015

- WRFChem3.7.1.  
- Single domain.  
- Continuous nudged meteorology each timestep (with target fields on a 3-hour update freq) with chemical restarts.  
- Initial and boundary conditions for meteorology from GFS.  
- Initial and boundary conditions for chemistry from MOZART.  
- MOZART-MOSAIC 4 bin, without aqueous chemistry and simple SOA (`chem_opt = 201`).  
- Horizontal spatial resolution of 30 km spatial resolution.  
- 33 vertical levels.  
- 27 meteoroglogical levels.  
- 180 second timestep for meteorology.  
- Thompson microphysics scheme (`mp_physics = 8`).  
- Radiation from RRTMG for both long and short-wave.  
- Boundary layer scheme from Mellor-Yamada Nakanishi and Niino-2.5.  
- Noah Land Surface Model.  
- Convective parameterisation from Grell 3-D ensemble.  
- Photolysis scheme from Madronich fTUV.  
- Emissions.  
    - Anthropogenic from EDGAR-HTAPv2.2.  
    - Fire from FINN.  
    - Biogenic from MEGAN.  
    - Dust from GOCART with AFWA.  
