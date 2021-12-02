---

# WRF-Chem post-processing instructions


### File tree
Here is a diagram showing the layout of the files that is created in your nobackup when you run WRF-Chem
```bash
./simulation_WRFChem4.2_test # can be changed for each project
└── output
│   └── base # where the post processed output files are
└── restart
│   └── base # where the restart file should be moved to
└── run
│   └── base
│   │   └── 2015-10-11_18:00:00-2015-10-13_00:00:00 # where the run happens
│   │   └── staging # where wrfout files are copied before they are post-processed
```

### Checking the output
Your test simulation should now have finished. First we will check that all the 'wrfout' files were created. On ARC4, go to the run directory of the test simulation (`simulation_WRFChem4.2_test`).
```bash
cd /nobackup/${USER}/simulation_WRFChem4.2_test/run/base/2015-10-11_18:00:00-2015-10-13_00:00:00
```

Then you can use `ls` to list the wrfout files, and you can count the wrfout files using `ls | wc`
```bash
ls wrfout_d01_2015-10-1*
ls wrfout_d01_2015-10-1* | wc
```

The test run should generate 31 output files. This is because the meteorology spinup was 6 hours, and the run was 24, and an extra hour is added so that a restart file for the next day (`wrfout_d01_2015-10-13_00:00:00`) can be generated. This would allow us to restart the run from the next day if necessary.

Then we need to check whether `post.bash` has run successfully. `post.bash` compresses the files to reduce their size. At the end of `main.bash`, the wrfout files are moved to the staging directory (`/simulation_WRFChem4.2_test/run/base/staging`). If you navigate there, you should see the wrfout files there (but not the ones generated during the spinup).

Then, `post.bash` outputs postprocessed files to `/simulation_WRFChem4.2_test/output/base`. There should be 23 wrfout files there (It should be 24 but there is a bug in the code, I have sent a [pull request](https://github.com/wrfchem-leeds/WRFotron/pull/46)). If you have 23 wrfout files in your `/output/base` directory, move onto the next step

### Regridding and concatenating the output

This process used to be a bit of a pain but now we have Luke's `pp_concat_regrid.py` script. This script does two things:
1. It concatenates the hourly wrfout files into a single file, i.e. the 2d arrays (lat, lon) are joined into a 3d array (time, lat, lon).
2. It regrids the arrays from a curvilinear grid to a rectilinear/regular grid. This makes the data easier to analyse and compare with other datasets.

First, please make sure you have these lines in your `~/.bashrc` file:
```bash
if [ -r /nobackup/cemac/cemac.sh ] ; then
  . /nobackup/cemac/cemac.sh
fi
```

You will see that `pp_concat_regrid.py` is already in the `/output/base` directory. There is also the `pp_concat_regrid.bash` script, which is used to submit `pp_concat_regrid.py` to the supercomputer queue and load the python modules needed to run the script.

Before submitting `pp_concat_regrid.py` you need to change a couple of variables in the file. Open `pp_concat_regrid.py` using `vim` or `gedit`, and you will see some variables that you can define at the top of the file, you will need to change the `year` variable as the test run was in 2015 not 2016

```python
# setup - ensure meets your requirements
year = "2016" # change this to 2015
month = "10"
domains = ["1"]
variables = ["PM2_5_DRY", "o3", "AOD550_sfc"]
aerosols = ["bc", "oc", "nh4", "so4", "no3", "asoaX", "bsoaX", "oin"] 
variables.extend(aerosols)
surface_only = True
res = 0.25
regrid = True
convert_aerosol_units_from_ugkg_to_ugm3 = True
```

Now submit the regridding script `qsub pp_concat_regrid.bash`. The script may take around an hour to run. If it finishes quickly, there was probably an error. If this happens, the error will be in the `pp_concat_regrid.bash.eXXXXXX` file. If the script is working, it will create these files:

```bash
wrfout_d01_global_0.25deg_2015-10_AOD550_sfc.nc
wrfout_d01_global_0.25deg_2015-10_o3.nc
wrfout_d01_global_0.25deg_2015-10_PM2_5_DRY.nc
wrfout_d01_global_0.25deg_2015-10_bc_2p5.nc
wrfout_d01_global_0.25deg_2015-10_oc_2p5.nc
```
