# Automatic simulation

## Running

WRFotron uses pre-built executables on ARC4 from CEMAC (for University of Leeds users). Everything required is loaded in `config.bash`, including Python, NCO, NCL, WPS, WRFMeteo, WRFChem, preprocessors, and ncview.  

1. Log into ARC4, clone the WRFotron repo, and edit the `chainDir` path within `config.bash` if it is not `/nobackup/${USER}/WRFotron`:  
    ```bash
    git clone https://github.com/wrfchem-leeds/WRFotron.git
    ```
2. Load the availability of CEMAC modules. If have other modules loaded then unload them (`module purge`), and similarly deactivate conda (`conda deactivate`), as both of these can cause conflits.:
    ```bash
    . /nobackup/cemac/cemac.sh
    ```    
3. From within the WRFotron folder run `master.bash`:  
    ```bash
    . master.bash 2015 10 12 00 24 06
    ```
For users that require their own executables or that are from outside of the University of Leeds, you can manually compile them using the instructions [here](compilation.html#manual-alternative).  

## How it works
WRFotron runs WRFChem via `master.bash` for a simulation setup in `config.bash`.

### `config.bash`  

- Check all directories are correct.  
- Change where WRFChem will run.  
- Keep the same name for synchronous runs.  
- Or if a new simulation, change.  
    - workDir / achiveRootDir / restartRootDir.  

### `master.bash`
 `master.bash` takes a starting date, a run time, a spinup time, and (optionally) a previous run's job ID on the queuing system as arguments.  

According to the run configuration in `config.bash`, WRFotron then prepares a run directory (typically on scratch or nobackup) with all necessary data, and submits 3 jobs to the queue:  
- Preprocessing script (`pre.bash`), containing calls to ungrib.exe, metgrid.exe, real.exe and the preprocessor tools for chemistry.  
- Main execution script (`main.bash`), which does the actual wrf.exe runs (spinup and chemistry run).  
- Postprocessing script (`post.bash`), which can be extended to do any kind of postprocessing on the wrfout files of the WRFChem run.  

Calling `master.bash` and giving it the job ID of another WRFotron `main.bash` process in the queue will tell the `main.bash` script to wait for this process to end before starting, thereby allowing you to submit several runs in a row at the same time, each of them restarting using the result of the previous run.  

The re-initialisation of meteorology works as follows:  
- After each successful WRFotron WRFChem run, wrfrst restart files are saved in a common directory. When a new run is called using `master.bash`, a meteo-only spinup run is made first, and a restart file is created at its end, now containing only "fresh" meteorology variables. It is then checked whether a restart file (with chemistry) from a previous run exists in the common restart directory. If this is the case, only the chemistry variables are copied from the previous run's restart file to the meteo spinup restart file. Then, a WRFChem run is started using this combined restart file as initial conditions, thereby using "fresh" meteorology while carrying on chemistry variables across runs. In case no restart file is found, a "cold start" chemistry run is conducted, starting with MOZART global model forecast values as initial conditions.

Creates output, restart, and run directories on `/nobackup/${USER}`:
- `putput/base/` (NetCDF files for wrfout).  
- `restart/base/` (Restart files for simulation runs).  
- `run/base/startdate_enddate` per simulation run/ (Everything gets created in here, specific to run).  
    - In this folder is all the files copied over with the settings updated in all the bash scripts (master, pre, main, post, config). 
- `run/base/staging` (wrfout files are stored for post-processing). 

Test run for 24 hours.  
```bash
. master.bash 2015 10 05 00 24 06
```
- Start year / start month / start day / start hour (UTC time) / simulation length / spin up length.  
- Spin-up runs from 2015-10-04_18:00:00 to 2015-10-05_00:00:00.  
- Simulation runs from 2015-10-05_00:00:00 to 2015-10-06_00:00:00.  
- Check linked files were for this `${USER}`.  
- Now make another run starting when the first one finishes, which will use the output of the previous run for chemistry initial conditions (rather than MOZART chemical boundary conditions), while re-initialising meteorology (from GFS/ECMWF data):
    ```bash
    . master.bash 2015 10 05 00 24 06 999999
    ```
- The 999999 is the job id for the `main.bash` from the previous run. This is used in the syntax to tell the HPC machine to wait until this job has finished before starting the new run. This is because the new run uses the files created from the first run. This allows you to submit several runs in a row at the same time, each of them restarting using the result of the previous run.

Four-dimension data assimilation (FDDA, i.e. re-initialisation of meteorology).  
```bash
vi master.bash
S/GRIDFDDA/0/g # to turn it off
S/GRIDFDDA/1/g # to turn it on  
```
- Nudges horizontal and vertical wind, potential temperature and water vapor mixing ratio to analyses. It doesn’t take the analyses fields for its values like some other models do. It uses them as initial conditions and then uses the primitive atmospheric equations. This is not for chemistry directly, though affects chemicals through transport.  

If need to re-submit any parts of the simulation, from within the folder, make changes to the relevant bash script and then:  
```bash
qsub pre.bash  
qsub main.bash  
qsub post.bash
```

### `main_restart.bash`

If `main.bash` breaks in the middle of the simulation, can restart using `main_restart.bash` (edited to not repeat the meteo spin up and carry on from where chem wrf.exe stopped).

Steps:
- Go to the run folder where `main.bash` stopped
- Copy the latest restart file with 00 hours over to the restart/base directory
- Edit `main_restart.bash`:
    - Change newRunRstFile to this latest restart file
    - Change submission time length appropriately
    - Change lastRstFile to the final restart file date at the end of run
    - Change curDate to the first wrfout file date
- Edit `namelist.input`:
    - Ensure `restart = .true`.
    - Change start date to match date of newRunRstFile
- `qsub main_restart.bash`
- When finished:
    - Manually copy over the final restart file to restart/base
    - Manually move the wrfout files to run/base/staging
    - Manually `qsub post.bash`

### Other files within WRFotron

`postprocessing.py`
- Calculates AOD for 550nm through interpolations and just extracting for the surface.  
- Converts units of aerosols at a certain standard temperature and pressure by dividing by the inverse of density: µg/kg of dry air to µg/m<sup>3</sup> by dividing by m<sup>3</sup>/kg.  

WRFChem namelists (read `/WRFChem/run/README.namelist` or user guide for detailed information).  
- `namelist.chem`.  
- `namelist.wrf`.  
- `namelist.wps`.  

`Vtable.ECMWF/GFS`.  
- Variable table for the intial and boundary meteorological conditions.  

Preprocessor input files (`emis_edgarhtap2_mozmos.inp`, `exo_coldens.inp`, `fire_emis.mozm.inp`, `mozbc.inp`, `megan_bio_emiss.inp`, `mozbc.inp.blueprint_201_mz4`, `mozbc.inp.blueprint_202_mz4`).     
- For files which depend on the aerosol / chemistry schemes (mozbc.inp, namelist.chem, and namelist.wrf), there are blueprints of each of these files for both the mozart_mosaic_4bin (`chem_opt = 201`) and the mozart_mosaic_4bin_aq (`chem_opt = 202`). See [document](https://github.com/wrfchem-leeds/WRFotron/blob/master/guides/MOZART_MOSAIC_V3.6.readme_dec2016.pdf).  
- Replace the contents of the namelist with the blueprint_201 / 202 version.  

Crontab script  
- Not normally allowed, check with HPC staff first.  
- Touches all files in `/nobackup/${USER}` to update their date and stop them getting deleted. 
- Create a hidden file in home directory (`vi ~/.not_expire.sh`) and add to it triples of lines such as:  
    - Touch -h makes sure symlinks don’t expire too.  
    - This script will change the last accessed date for all the specified directories and files underneath that path.  
    - Change permissions 755 on .not_expire.sh (`chmod 755 ~/.not_expire.sh`).  
    - Use the crontab command to edit the crontab file `crontab -e`
    - Then add a line: `0 0 1 */2 * ~/.not_expire.sh`
    - This has now set a cronjob to run that will automatically touch (and thus reset last accessed time) the files once a month at 0400 on the 4th of the month.
    - Runs on the login nodes
        ```bash
        cd /nobackup/${USER}  
        find . -exec touch -ah {} +
        ```

Acquire meteorological NCEP GFS files.  
- Will have to change all scripts with dataDir locations to the correct `${USER}`.  
```bash
cd /nobackup/${USER}/download_and_find_gfs_mz4
get_GFS_analysis_2004-current.bash
get_GFS_analysis_parallel.bash
```
- If these have a size of 0, use [FNL analysis files at lower resolution](https://rda.ucar.edu/datasets/ds083.2/index.html#!description).  
    - The Globus Transfer Service (GridFTP) option to transfer the FNL files from the RDA.  
    - The other option is to go to that link, click data access, click web file listing for either GRIB1 (pre 2007.12.06) or GRIB2 (post 2007.12.06), click complete file list, click on the year of interest within the group ID column and checkbox the timeframe you're interested in. Now either click csh download script and follow the instructions in the comments of the script (remembering to change your linux shell to csh), or click get as a tar file (though this is limited to 2GB), or again there is the option for globus.
    - To download for more than 1 day at a time. First changing the script to the time frame required, ensuring download for the spin-up timeframe too.  
- Go over GFS folder to check have 8 files per day for each day of simulation.  
    ```bash
    .find_missing_GFS.bash
    qsub find_missing_GFS_parallel.bash
    ```
- Rename FNL files to original GFS naming convention and copy for 3 hourly interval midpoints.

Acquire MOZART (MZ4) files for chemical initial and boundary conditions.  
- Pre-2018:  
- Download [MZ4](http://www.acom.ucar.edu/wrf-chem/mozart.shtml).  
- Download [CAM-Chem](https://www.acom.ucar.edu/cam-chem/cam-chem.shtml).  
- Post-2018:
- Download [WACCM](https://www.acom.ucar.edu/waccm/download.shtml). 
- Ensure for a month have day either side of time frame of interest, and go for global domain.  

Anthropogenic emissions  
- Choose anthropogenic input namelist setting in config.bash.  
```bash
cd /nobackup/${USER}/WRFotron
vi emis_edgarhtap2_mozmos.inp
```
Fire emissions (FINN)  
- Update `fire_emis.mozm.inp` to have to correct filename for the year of simulation  careful to update file for the correct chemical mechanism.  

`pre.bash`  
- Check the linked MZ4 files are for timeframe required e.g. 2015.  
- If using daily files, use this portion of code and comment out the monthly section.  
- Vice versa for if using monthly files.  

`namelist.wps.blueprint`.  
- Change domain, resolution, map projection, and map area.  
- Edit `namelist.wps.domain_test` to try out different domain settings.  
- Create domain plot `ncl plotgrids.ncl`.  
- View the PDF of the domain `evince wps_show_dom.pdf`.  
- When decided update setting in `namelist.wps.blueprint`.  

`namelist.wrf.blueprint`.  
- Change domain, resolution, and number of levels.  

`namelist.chem.blueprint`.  
- Change chemistry options.  
- See WRFChem User Guide.  

### Approximate job run times and HPC requirements
For a 30 km domain at 1.5 minute timestep over China using `chem_opt = 202`. For a different setup, you can scale this accordingly.:
- 1 day simulation takes 1-2 hour wall clock time approximately.  
- 1 month simulation takes 2-4 days wall clock time approximately.  
- 1 year simulations takes 1-2 month wall clock time approximately.  
- `pre.bash` = 2 hours, 1 core, 12GB/process (run in serial).
- `main.bash` = 48 hours, 128 cores, 1GB/process (run in parallel).
- `post.bash` = 48 hours, 4 cores, 12GB/process (run in parallel).

### Analyse output using Python
For those new to Python, see this [introductory course](https://www.lukeconibear.com/introduction_to_scientific_computing/index.html).  