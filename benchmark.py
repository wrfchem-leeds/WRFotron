import os
import re
import glob
import sys
import numpy as np
import pandas as pd
import xarray as xr
import xesmf as xe
import salem

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
# data
path = os.getcwd()
wrfout_file = sys.argv[1]
year = re.findall(r'wrfout_d01_\d+', wrfout_file)[0][-4:]
month = re.findall(r'wrfout_d01_\d+-\d+', wrfout_file)[0][-2:]

grid_rectilinear_global = xr.Dataset(
    {
        "lat": (["lat"], np.arange(-60, 85, 0.25)),
        "lon": (["lon"], np.arange(-180, 180, 0.25)),
    }
)

# ---------------
# processing
if use_china_measurements:
    obs_source = 'china_measurements'
    if year in ['2013', '2014', '2015', '2016', '2017', '2020']:
        obs_filename = f'/nobackup/WRFChem/measurements/china_measurements_corrected/df_obs_summary_{year}.csv'
elif use_openaq:
    obs_source = 'openaq'
    if year in ['2013', '2014', '2015', '2016', '2017', '2020']:
        obs_filename = f'/nobackup/WRFChem/openaq/csv/openaq_data_{year}_noduplicates.csv'
    elif year in ['2018', '2019']:
        if int(month) < 7:
            obs_filename = f'/nobackup/WRFChem/openaq/csv/openaq_data_{year}_part1_noduplicates.csv'
        else:
            obs_filename = f'/nobackup/WRFChem/openaq/csv/openaq_data_{year}_part2_noduplicates.csv'


df_obs = pd.read_csv(obs_filename, index_col="date.utc", parse_dates=True)

number_of_stations = {}
nmbfs = {}
nmaefs = {}

ds_wrfout = salem.open_wrf_dataset(wrfout_file)
year_month_day = str(ds_wrfout.time.values)[2:12]
hour = str(ds_wrfout.time.values)[13:15]
df_obs_dt = df_obs[year_month_day].loc[df_obs[year_month_day].index.hour == int(hour)]

for country in countries:
    df_obs_dt_country = df_obs_dt.loc[df_obs_dt.country == country]

    for parameter in parameters.keys():
        ds_wrfout_parameter = ds_wrfout[parameters[parameter]].isel(bottom_top=0)

        have_weights = len(glob.glob(f'{path}/bilinear*')) != 0
        regridder = xe.Regridder(ds_wrfout_parameter, grid_rectilinear_global, "bilinear", reuse_weights=have_weights)
        ds_wrfout_parameter_regrid = regridder(ds_wrfout_parameter)

        df_obs_dt_country_parameter = df_obs_dt_country.loc[df_obs_dt_country.parameter == parameter]
        df_obs_dt_country_parameter.replace(-999, np.nan, inplace=True)

        number_of_stations.update({f'{parameter}_{country}': len(df_obs_dt_country_parameter.index)})

        obs_values = []
        wrf_values = []
        for index, obs in df_obs_dt_country_parameter.iterrows():
            lat = obs['coordinates.latitude']
            lon = obs['coordinates.longitude']

            if parameter == 'o3': # convert units to ppb
                if 'g/m' in obs.unit:
                    obs_value = obs.value / 1.9957
                elif 'ppm' in obs.unit:
                    obs_value = obs.value * 1000

                wrf_value = ds_wrfout_parameter_regrid.sel(lat=lat, lon=lon, method='nearest').values[0] * 1000
            else:
                obs_value = obs.value
                wrf_value = ds_wrfout_parameter_regrid.sel(lat=lat, lon=lon, method='nearest').values[0]

            obs_values.append(obs_value)
            wrf_values.append(wrf_value)

        np.savez_compressed(f'{path}/obs_values_{obs_source}_{year_month_day}-{hour}_{parameter}_{country}.npz', obs_values=np.array(obs_values))
        np.savez_compressed(f'{path}/wrf_values_{obs_source}_{year_month_day}-{hour}_{parameter}_{country}.npz', wrf_values=np.array(wrf_values))
