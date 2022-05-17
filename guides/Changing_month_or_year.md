# Running a different month or year

Unfortunately, running a different month in WRF-Chem is not as simple as providing different arguments to `master.bash`. There are several parameters that need editing in the namelists. Changing month requires changing meteorological and chemical boundary files, changing year requires changing fire emissions files.

### Changing met files

The met files are used by the model to provide initial conditions and nudge during the simulation.

`pre.bash` contains the line:
```bash
/bin/csh ./link_grib.csh ${metDir}/ecmwf_global_pressurelevels_20141201_20150501.grib ${metDir}/ecmwf_global_surface_20141201_20150501.grib
```
You must make sure that the start and end dates for the `ecmwf_global_pressurelevels_`... and `ecmwf_global_surface_`... cover the entire run, and match each other.

For example, if the current file is `ecmwf_global_pressurelevels_20141201_20150501.grib`, but you want to run during May 2015, the file must be changed

To see the files in `${metdir}` you can run:

```bash
# by default metDir location will be:
ls /nobackup/WRFChem/initial_boundary_meteo_ecmwf
# but you can check what it is in config.bash by running:
grep metDir= config.bash
```

So in this case the file including the desired run period in `${metdir}` would be:
`ecmwf_global_pressurelevels_20150501_20150901.grib`. Remember to also change the `ecmwf_global_surface_`... file

### Changing chemical boundary files
The chemical background files come are used to provide boundary chemical conditions. For simulations prior to 2018, output from MOZART is used. After 2018, WACCM is used. Changing simulation to a different month requires changing the following lines in `pre.bash`:

```bash If monthly MOZBC files use this portion (otherwise comment out)
# MOZART - pre 2018
ln -s ${MOZARTdir}/MZ2015jan ./moz0000.nc
ln -s ${MOZARTdir}/MZ2015feb ./moz0001.nc
ln -s ${MOZARTdir}/MZ2015mar ./moz0002.nc
```
If the model was to be run for the month of May (i.e. using `. master.bash 2015 05 01 00 744 24`) the files would have to be updated to:

```bash If monthly MOZBC files use this portion (otherwise comment out)
# MOZART - pre 2018
ln -s ${MOZARTdir}/MZ2015apr ./moz0000.nc
ln -s ${MOZARTdir}/MZ2015may ./moz0001.nc
ln -s ${MOZARTdir}/MZ2015jun ./moz0002.nc
```

The chemistry files must cover the meteorological spinup period. If they end on the first hour of the next month, they must also cover that month. Note that chemical boundary files do not provide initial conditions, so a long (2 weeks by convention) chemical spinup is used.

### Changing fire emissions
The fire emissions file must correspond to the meteorological year. When this is changed, the following line in `fire_emis.mozm.inp` must be changed:

For example, changing from 2015 to 2016
```bash
fire_filename  = 'FINNv1.5_2015.MOZ4',
# should be changed to
fire_filename  = 'FINNv1.5_2016.MOZ4',
```
Note that simulations that span a year need the fire emissions for each year. For example, the `fire_emis.mozm.inp` for a simulation of December that requires the first hour of January (so that a January restart file is created) such as `. master.bash 2015 12 01 00 744 24`

```bash
fire_filename(1)  = 'FINNv1.5_2015.MOZ4',
fire_filename(2)  = 'FINNv1.5_2016.MOZ4',
```
