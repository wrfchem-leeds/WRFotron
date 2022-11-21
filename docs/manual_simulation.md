# Manual Simulation

Independently run a 24 hour simulation for India from 2016 10 05.

## Setup

Check you have the GFS data you need for the dates required to initialise and force meteorological conditions (1 file per 3 hours, 8 files per day, none are too small):  
```bash
cd /nobackup/${USER}
mkdir initial_boundary_meteo_gfs 
cd initial_boundary_meteo_gfs
cp /nobackup/WRFChem/initial_boundary_meteo_gfs/GF201610{04..07}* .
```
If require more GFS data, can copy more over from `/nobackup/WRFChem/initial_boundary_meteo_gfs` or can use the download scripts `get_GFS_analysis_2004-current.bash` and `get_GFS_analysis_parallel.bash` within `cd /nobackup/WRFChem/download_and_find_gfs_mz4`.

Create a test run folder for the manual run of WRF:  
```bash
cd /nobackup/${USER}/
mkdir testrun
```

Copy `link_grib.csh` to the new folder.  
```bash
cd /nobackup/${USER}/testrun
cp /nobackup/WRFChem/testrun_files/link_grib.csh .
```

Link the required GFS data via `link_grib.csh` in to the new simulation folder.  
```bash
./link_grib.csh /nobackup/${USER}/initial_boundary_meteo_gfs/GF201610*
```

Copy over the ungrib, geogrid and metgrid folders.  
```bash
cp -r /nobackup/WRFChem/testrun_files/ungrib .
cp -r /nobackup/WRFChem/testrun_files/geogrid .
cp -r /nobackup/WRFChem/testrun_files/metgrid .
```

Link the ungrib, geogrid and metgrid executables from the folders that are now copied over.  
```bash
ln -sf metgrid/src/metgrid.exe
ln -sf geogrid/src/geogrid.exe
ln -sf ungrib/src/ungrib.exe
```

Copy over the WPS and input namelists.  
```bash
cp /nobackup/WRFChem/testrun_files/namelist.wps .
cp /nobackup/WRFChem/testrun_files/namelist.input .
```

Link to the variables table.  
- If post-2015 simulation, use new variable table:  
  ```bash
  ln -sf /nobackup/WRFChem/Vtable.GFS_new Vtable
  ```
- If pre-2015 simulation, use old variable table:
  ```bash
  ln -sf /nobackup/WRFChem/Vtable.GFS Vtable
  ```

Copy over the WRF and real executables, and the WRF and real bash scripts for job submission.  
```bash
cp /nobackup/WRFChem/testrun_files/real.exe .
cp /nobackup/WRFChem/testrun_files/real.bash .
cp /nobackup/WRFChem/testrun_files/wrf.exe .
cp /nobackup/WRFChem/testrun_files/wrf.bash .
```

Edit the time for the run on the WPS namelist according to the new requirements for the simulation. Be careful for leap years, and any changes made in the WPS namelist have to mirrored if the same variables are present in the input namelist.  
- `start_date = '2016-10-05_00:00:00'`.  
- `end_date   = '2016-10-06_00:00:00'`.  
- number of domains (use 1).  
- spatial resolution (dx and dy).  
- map projection (i.e. Lambert conformal, Mercator, polar stereographic, or Regular latitude-longitude also known as cylindrical equidistant).  
- If lambert, dx and dy are in metres.  
- Uses projection parameters: truelat1, truelat2, stand_lon.  
- See page 37 of WRF User Guide.  
- Update and edit the namelist.input.  
- make sure the run_hours, start date, end date, timestep, e_we, e_sn, dx, dy are the same here as they are in the namelist.wps.  
- time step for integration seconds (recommended 6*dx in km for a typical case).  

Load the netCDF module.  
```bash
module load netcdf
export NETCDF=$(nc-config --prefix)
export NETCDF_DIR=$NETCDF
```

## Preprocessing

Run geogrid  
```bash
./geogrid.exe
```
- Configures the horizontal domain, interpolating static geographical data.  
    - Creates geography (`geo_em.d01.nc`) for each domain.  
    - Progress logged in geogrid.log.  

Run ungrib  
```bash
./ungrib.exe
```
- Reads, reformats, and extracts meteo input data.  
    - Creates meteorology by ungribbing the GFS grb2 files.  
    - Intermediate files for every time step.  
    - Progress logged in ungrib.log.  

Run metgrid
```bash
./metgrid.exe   
```
- Ingests and interpolates input data creating initial and boundary meteorological conditions.  
    - Creates `met_em.d01.2016-02-25_00:00:00.nc` for every 6 hour time step, for both domains.  
    - Also metgrid.log.  

Copy the anthro_emiss, wesely, exo_coldens, megan_bio_emiss, mozbc executables.  
```bash
cp /nobackup/WRFChem/testrun_files/anthro_emis .
cp /nobackup/WRFChem/testrun_files/wesely .
cp /nobackup/WRFChem/testrun_files/exo_coldens .
cp /nobackup/WRFChem/testrun_files/megan_bio_emiss .
cp /nobackup/WRFChem/testrun_files/mozbc .
```

Copy the input files for these executables.  
```bash
cp /nobackup/WRFChem/testrun_files/emis_edgarhtap2_mozmos.inp .
cp /nobackup/WRFChem/testrun_files/wesely.inp .
cp /nobackup/WRFChem/testrun_files/exo_coldens.inp .
cp /nobackup/WRFChem/testrun_files/megan_bio_emiss.inp .
cp /nobackup/WRFChem/testrun_files/mozbc.inp .
```

Copy over the run subdirectory from WRF.  
```bash
cp -r /nobackup/${USER}/WRFChem/run/* .
```

Remove the testrun version of real.exe and wrf.exe and copy the freshly compiled versions.  
```bash
rm real.exe
rm wrf.exe
cp /nobackup/${USER}/WRFChem/main/real.exe .
cp /nobackup/${USER}/WRFChem/main/wrf.exe .
```

Link the required MOZART chemical boundary condition files (need previous day too for spin up).  
```bash
cd /nobackup/

cd /nobackup/${USER}
mkdir initial_boundary_chem_mz4
cd initial_boundary_chem_mz4
cp /nobackup/${USER}/initial_boundary_chem_mz4/MZ2016oct .
cd /nobackup/${USER}/testrun
ln -sf /nobackup/${USER}/initial_boundary_chem_mz4/MZ2016oct moz0000.nc
```
- Pre-2018:
    - Download [MZ4](http://www.acom.ucar.edu/wrf-chem/mozart.shtml).  
    - Download [CAM-Chem](https://www.acom.ucar.edu/cam-chem/cam-chem.shtml). 
- Post-2018:
    - Download [WACCM](https://www.acom.ucar.edu/waccm/download.shtml).  
    - Note the directory needs to change in config.bash (`MOZARTdir`).  
- Can access individual days using the script.  
  ```bash
  cd /nobackup/WRFChem/download_and_find_gfs_mz4
  . get_MZ4_fcst.bash YYYY MM DD
  ```

Run real.exe
```bash
vi real.bash
```
- This has all the requirements for time, nodes, cores, processors.  
    - 1 core required, with h_vmem 6GB.  
    - May need to change/remove the project code.  
    - Before running real.exe, may need to comment out (with a ! in Fortran) in namelist.input aux_input_6 for megan_bio_emiss (3 lines which relates to this).  

Check namelists, run real, and check progress.  
```bash
qsub real.bash
```
- Interpolates between the intermediate files to create the time domain data at the prescribed time intervals.  
```bash
qstat
```
- When complete, creates:  
    - `real.bash.o3502300`.  
        - Output from the job submission script (MPI output from job id 3502300).  
    - `real.bash.e3502300`.  
        - Error from the job submission script (MPI output from job id 3502300).  
    - `namelist.output`.  
        - `wrfinput_d01` (for initial conditions).  
        - `wrfinput_d02` (for initial conditions).  
        - `wrfbdy_d01` (for boundary conditions).  
    - Check `rsl.error*` that the run was successful.  
        - If it fails, the wrfinput and wrfbdy won't be created.  
    - Check in `rsl.error*` and `rsl.out*` files for each core.  

Edit namelist for biogenic emissions.  
```bash
vi megan_bio_emiss.inp
```

Run MEGAN.  
```bash
./megan_bio_emiss < megan_bio_emiss.inp
```
- Creates for both domains (`wrfbiochemi_d*`).  

Edit and run mozbc.  
```bash
vi mozbc.inp
```
- Domain 1, `do_ic = .true`.  
    - Updates `wrfinput_d01` (NetCDF) with initial conditions.  
- Domain 1, `do_bc = .true`.  
    - Updates `wrfbdy_d01` (NetCDF) with boundary conditions.  
- If ncview wrfbdy_d01, then can see the 2D curtains in space of the boundary conditions (think of box walls), i.e. T is transect or not, X or Y domain, E east or S south.  
    - Domain 2, `do_ic = .true`.  
- Updates `wrfinput_d02` (netCDF) with initial conditions for the nested domain, as gets its boundary conditions from the outer domain.  
  ```bash
  ./mozbc < mozbc.inp
  ```

Run wesely.  
- Reads, reformats, and extracts input data for dry deposition.  
- Copy over the `season_wes_usgs.nc` file.  
- Creates `wrf_season_wes_usgs_d01.nc` and `wrf_season_wes_usgs_d02.nc`.  
  ```bash
  cp /nobackup/WRFChem/wes-coldens/season_wes_usgs.nc .
  ./wesely < wesely.inp
  ```

Run exo coldens. 
- Reads, reformats, and extracts input data.  
- Copy over the `exo_coldens.nc` file.  
- Creates `exo_coldens_d01` and `exo_coldens_d02`.
  ```bash
  cp /nobackup/WRFChem/wes-coldens/exo_coldens.nc .
  ./exo_coldens < exo_coldens.inp
  ```

Edit anthropogenic namelist (check the NO/NO2 ratio from NOX is correct for your domain).  
```bash
vi emis_edgarhtap2_mozmos.inp
```

Run anthro_emis.  
```bash
./anthro_emis < emis_edgarhtap2_mozmos.inp
```
- Run for both domain 1 and 2 separately.  
    - Change the `start_output_time` and `stop_output_time`.  
    - Creates `wrfchemi`.  

## Main

Before running `wrf.exe`, may need to comment back in (removing the !) in namelist.input aux_input_6 for megan_bio_emiss (3 lines which relates to this).  

Create bash script for wrf.exe.  
```bash
vi wrf.bash
```

This has all the requirements for time, nodes, cores, processors. 32 cores required.  
Run wrf.exe.  
```bash
qsub wrf.bash
```

Can follow the progress by tailing the `rsl.error.0000` file.  
```bash
tail rsl.error.0000
```

Can also check jobs running on HPC through.  
```bash
qstat
```

Creates:  
- wrfout files per hour.  
- rsl.out.* (for each core).  
- rsl.error.* (for each core). 

Check linked files were for this ${USER}.  

## Postprocessing  

Not doing in the test run.  

To view wrfout files (without the post-processing).  
```bash
conda activate ncview # or module load ncview
ncview wrfout*
```
