#!/usr/bin/env python3
import xarray as xr
import os
import glob
import re

cwd = os.path.dirname(os.path.abspath(__file__))
wrfchemi_files = sorted(glob.glob(cwd + '/wrfchemi*'))

# find time interval between files
if '00z' in wrfchemi_files[0]:
    time_interval = 12
else:
    time_first_file = int(re.findall(r'\d+:00:00', wrfchemi_files[0])[-1][0:2])
    time_second_file = int(re.findall(r'\d+:00:00', wrfchemi_files[2])[-1][0:2])
    time_interval = time_second_file - time_first_file

# process emission
for wrfchemi_file in wrfchemi_files:
    print('processing', wrfchemi_file)
    with xr.open_dataset(wrfchemi_file) as open_ds:
        ds = open_ds.copy(deep=True)

    # create dictionary of emission totals (E_*) per specie
    species = {}
    for var, da in ds.data_vars.items():
        if var[0] != 'E':
            continue
        var_list = var.split('_')
        if len(var_list) == 2:
            species['E_' + var_list[1]] = []
       
    # add emission sectors
    for var, sector_var_list in species.items():
        [species[var].append(var_sec) for var_sec in ds.data_vars.keys() \
        if (var_sec[:len(var)] == var) & (len(var_sec.split('_')) == 3) ]
          
    # iterate through ds summing sectors
    for var, var_sec_list in species.items():
        for time in range(0, time_interval):
            sectors_das_list = []
            for var_sec in var_sec_list:
                sector = var_sec.split('_')[-1]
                sectors_das_list.append(ds[var_sec][time])
                
            # concatenate and sum sector dataarrays
            sectors_da = xr.concat(sectors_das_list, dim='sectors')
            sectors_da.name = var
            total_sectors = sectors_da.sum('sectors', keep_attrs=True)
            
            # put back into dataset
            ds[total_sectors.name][time] = total_sectors
    
    print('writing updated', wrfchemi_file)
    ds.to_netcdf(wrfchemi_file)
    ds.close()

