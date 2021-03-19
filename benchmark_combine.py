from __future__ import print_function
import os
import glob
import re
import numpy as np

# ---------------
# setup choice
use_china_measurements = True
use_openaq = False
countries = ['CN']
parameters = {
    'pm25': 'PM2_5_DRY', 
    'o3': 'o3'           
}

# ---------------
# functions
path = os.getcwd()

def normalised_mean_bias_factor(obs_values, wrf_values):
    if ( np.nansum(( obs_values / np.nansum(obs_values) ) * ( ( wrf_values - obs_values) / obs_values )) ) > 0.0:
        overestimates = True
    else:
        overestimates = False
    if overestimates:
        return np.nansum(( obs_values / np.nansum(obs_values) ) * ( ( wrf_values - obs_values) / obs_values ))
    else:
        return np.nansum(( wrf_values /np.nansum( wrf_values) ) * ( ( wrf_values - obs_values) / obs_values ))


def normalised_mean_absolute_error_factor(obs_values, wrf_values):
    if ( np.nansum(( obs_values / np.nansum(obs_values) ) * ( ( wrf_values - obs_values) / obs_values )) ) > 0.0:
        overestimates = True
    else:
        overestimates = False
    if overestimates:
        return np.nansum(( obs_values / np.nansum(obs_values) ) * ( np.abs(( wrf_values - obs_values)) / obs_values ))
    else:
        return np.nansum(( wrf_values / np.nansum(wrf_values) ) * ( np.abs(( wrf_values - obs_values)) / obs_values ))


# ---------------
# processing
if use_china_measurements:
    obs_source = 'china_measurements'
elif use_openaq:
    obs_source = 'openaq'

obs_values_summary = {}
wrf_values_summary = {}

obs_values_files = {}
wrf_values_files = {}

nmbfs = {}
nmaefs = {}

obs_count = {}

season_dates = {'winter': '2016-02', 'spring': '2016-05', 'summer': '2016-08', 'autumn': '2016-11'}

for country in countries:
    for parameter in parameters.keys():
        obs_values_annual = np.array([])
        wrf_values_annual = np.array([])

        for season in season_dates.keys():
            obs_values_files.update({f'{country}_{parameter}_{season}': sorted(glob.glob(f'{path}/obs_values_{obs_source}_*{season_dates[season]}*_{parameter}_{country}.npz'))})
            wrf_values_files.update({f'{country}_{parameter}_{season}': sorted(glob.glob(f'{path}/wrf_values_{obs_source}_*{season_dates[season]}*_{parameter}_{country}.npz'))})

            obs_values_season = np.array([])
            wrf_values_season = np.array([])

            for index in range(len(obs_values_files[f'{country}_{parameter}_{season}'])):
                obs_values = np.load(obs_values_files[f'{country}_{parameter}_{season}'][index])['obs_values']
                wrf_values = np.load(wrf_values_files[f'{country}_{parameter}_{season}'][index])['wrf_values']
                
                obs_values_season = np.append(obs_values_season, obs_values)
                wrf_values_season = np.append(wrf_values_season, wrf_values)
            
            for index in range(len(obs_values_season)):
                if obs_values_season[index] <= 0 or wrf_values_season[index] <= 0 or obs_values_season[index] == np.nan or wrf_values_season[index] == np.nan:
                    obs_values_season[index] = np.nan
                    wrf_values_season[index] = np.nan

            obs_values_annual = np.append(obs_values_annual, obs_values_season)
            wrf_values_annual = np.append(wrf_values_annual, wrf_values_season)

            obs_count.update({f'{country}_{parameter}_{season}': np.count_nonzero(~np.isnan(obs_values_season))})

            nmbfs.update({f'{country}_{parameter}_{season}': normalised_mean_bias_factor(obs_values_season, wrf_values_season)})
            nmaefs.update({f'{country}_{parameter}_{season}': normalised_mean_absolute_error_factor(obs_values_season, wrf_values_season)})

        obs_count.update({f'{country}_{parameter}_annual': np.count_nonzero(~np.isnan(obs_values_annual))})

        nmbfs.update({f'{country}_{parameter}_annual': normalised_mean_bias_factor(obs_values_annual, wrf_values_annual)})
        nmaefs.update({f'{country}_{parameter}_annual': normalised_mean_absolute_error_factor(obs_values_annual, wrf_values_annual)})


print(f'Benchmarking against: {obs_source.upper()}')
for key in nmbfs.keys():
    print(f'Number of observations = {obs_count[key]}')
    print(f"NMBF  for {key.replace('_', ' ')} = {round(nmbfs[key], 2)}")
    print(f"NMAEF for {key.replace('_', ' ')} = {round(nmaefs[key], 2)}")
    print()
