********
Versions
********

.. role:: bash(code)
   :language: bash


2.1.0 23/06/2020
==================
- Changes relative to version 2.0.0:  
    - WRF-Chem4.2  

        - `Fixes the performance interval issue of WRFChem4.0.3 <https://github.com/wrfchem-leeds/WRFotron/issues/4>`_.  

    - `If still use WRFChem3.7.1, then add aqueous chemistry in stratocumulus clouds in WRFChem3.7.1 <https://github.com/wrfchem-leeds/WRFotron/issues/5>`_.  
    - Refactored the GitHub repository:  

        - Converted user guide to readthedocs.io documentation.
        - Focus on CEMAC WRFotron.  
        - Removed old WRFotron code but kept a reference to the settings they used in the user guide.  
        - Removed superfluous files.  

    - Added no binding for MPI executions :bash:`-bind-to none` in :bash:`main.bash` and :bash:`main_restart.bash`.  
    - Added NCO and chemistry variables list version checks to :bash:`main.bash` and :bash:`main_restart.bash`.  
    - Changed the default memory per core to 2G for :bash:`main.bash` and :bash:`main_restart.bash`. 


2.0.0 01/02/2019.
==================
- Changes relative to version 1.0.0:
    - WRFChem4.0.3.  
    - With aqueous chemistry in stratocumulus clouds (:bash:`cldchem_onoff = 1`).  

        - Works with WRFChem4.0.3.  

    - Biomass burning plume rise throughout the boundary layer (:bash:`bbinjectscheme = 2`).  

        - The original option 2 was 50% at the surface and 50% evenly throughout the BL.  
        - The new option 2 has all BB emissions evenly distributed throughout the BL.  
        - `To add the bbinjectscheme to any new version of WRFChem <https://github.com/wrfchem-leeds/WRFotron/blob/master/additional_docs/add_bbinjectscheme.md>`_.  

    - Diurnal cycle from Olivier et al., (2003).  
    - Aerosol optical properties approximated by Maxwell-Garnett.  
    - Updated TUV scheme for photolysis (:bash:`phot_opt = 4`).  

        - `Download the additional data files <http://www.acom.ucar.edu/wrf-chem/TUV.phot.bz2>`_ to your :bash:`WRFChem/run` folder.  
        - Extract the data directories :bash:`DATAE1` and :bash:`DATAJ1`, and the :bash:`wrf_tuv_xsqy.nc` file from downloaded file using :bash:`tar xvf TUV.phot.bz2`.  

    - `Initial and boundary conditions for chemistry from WACCM for post 2018 or CAM-Chem for pre 2018 <https://github.com/wrfchem-leeds/WRFotron/blob/master/additional_docs/CESM-WRFchem_aerosols_plusgas.pdf>`_.  
    - Fixed the bug where nudging would stop after 312 hours (i.e. after day 13 of a simulation) i.e. changed :bash:`gfdda_end_h` to 10,000.  
    - Nudge above the boundary layer. To do this, go into :bash:`namelist.wrf.blueprint`, and within the FDDA section change:  

    .. code-block:: bash

      if_no_pbl_nudging_uv                = 1, 1, 1,                                    ! nudging of u and v in the PBL, 0 = yes, 1 = no
      if_no_pbl_nudging_t                 = 1, 1, 1,                                    ! nudging of t in the PBL, 0 = yes, 1 = no
      if_no_pbl_nudging_q                 = 1, 1, 1,                                    ! nudging of q in the PBL, 0 = yes, 1 = no

    - Hard-coded NCL and NCO commands.  
    - Fixed the bug where within the anthro_emiss namelist for EDGAR-HTAP2, |NH3| was incorrectly set as an aerosol i.e. removed (a) in the emis_map.  

        .. |NH3| replace:: NH\ :sub:`3`

    - Fixed the bug in plume rise where extra biomass burning mass was added aloft when the thickness of the vertical grid (dz) increases by altitude.  

        - Within :bash:`chem/module_chem_plumerise_scalar.F`:  

            - :bash:`dz_flam=zzcon(k2)-zzcon(k1-1) ! original version`.  
            - :bash:`dz_flam=zzcon(k2+1)-zzcon(k1)   ! fixed version`.  

    - Corrected the :bash:`metInc` within config.bash for ECMWF to be 6 (3 was for GFS).  
    - Added the faster version of post.bash from Helen Burns in CEMAC.  

        - Hard coded NCL and NCO commands in.  
        - Also, removed the deletion of pre-processed and temporary wrfout files from the staging directory, as these are often needed for error diagnosis.


1.0.0 01/06/2018.
==================
- Changes relative to version 0.0.0:  

    - MOZART-MOSAIC 4 bin, with aqueous chemistry and VBS SOA (:bash:`chem_opt = 202`).  
    - Without aqueous chemistry in stratocumulus clouds (`cldchem_onoff = 0`).  

        - Does not work with WRF-Chem version 3.7.1.   

    - Morrison microphysics (:bash:`mp_physics = 10`).  
    - Initial and boundary conditions for meteorology from ECMWF.  
    - 38 meteoroglogical levels.  
    - 3 meteorological soil levels for WRFChem4.0.3 and 4 for WRFChem3.7.1.  
    - Consistent timestep for chemistry and biogenics with meteorology.  


0.0.0 15/10/2015.
==================
- WRFChem3.7.1.  
- Single domain.  
- Continuous nudged meteorology each timestep (with target fields on a 3-hour update freq) with chemical restarts.  
- Initial and boundary conditions for meteorology from GFS.  
- Initial and boundary conditions for chemistry from MOZART.  
- MOZART-MOSAIC 4 bin, without aqueous chemistry and simple SOA (:bash:`chem_opt = 201`).  
- Horizontal spatial resolution of 30 km spatial resolution.  
- 33 vertical levels.  
- 27 meteoroglogical levels.  
- 180 second timestep for meteorology.  
- Thompson microphysics scheme (:bash:`mp_physics = 8`).  
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



