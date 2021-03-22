from __future__ import print_function
import os
import glob
import re
import numpy as np
import pandas as pd
import salem
import xarray as xr
import xesmf as xe
import matplotlib
import matplotlib.pyplot as plt
from matplotlib import gridspec
from matplotlib.colors import Normalize, ListedColormap
import cartopy.crs as ccrs
import cartopy.feature as cfeature

# ---------------
# setup choice
use_china_measurements = True
use_openaq = False
countries = ['CN']
parameters = {
    'pm25': 'PM2_5_DRY', 
    'o3': 'o3'           
}
grid_rectilinear_global = xr.Dataset(
    {
        "lat": (["lat"], np.arange(-60, 85, 0.25)),
        "lon": (["lon"], np.arange(-180, 180, 0.25)),
    }
)

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


def plot_map(index, country, parameter, season, ds, df, title, label):
    ax = fig.add_subplot(gs[index], projection=ccrs.PlateCarree())
    if country == 'CN':
        ax.set_extent([73, 135, 18, 54], crs=ccrs.PlateCarree())
        ax.add_feature(cfeature.BORDERS)
        ax.add_feature(cfeature.COASTLINE)
    if parameter == 'pm25':
        vmax = 150
    elif parameter == 'o3':
        vmax = 100
    norm = Normalize(vmin=0, vmax=vmax)
    cmap = 'viridis'
    im = ax.contourf(
        xx, yy, 
        ds.values, 
        np.arange(0, vmax, 11), 
        cmap=cmap, norm=norm, 
        transform=ccrs.PlateCarree(),
        extend='both'
    )
    sm = plt.cm.ScalarMappable(norm=norm, cmap=im.cmap)
    sm.set_array([])  
    cb = plt.colorbar(sm, norm=norm, cmap=cmap, ticks=[int(num) for num in np.arange(0, vmax, 11)], shrink=0.75)
    cb.set_label(label, size=14)
    cb.ax.tick_params(labelsize=14)
    plt.title(title)
    obs_lats = np.array(df['lat'])
    obs_lons = np.array(df['lon'])
    obs_datas = np.array(df['obs_value'])
    plt.scatter(obs_lons, obs_lats, c=obs_datas, s=20, cmap=cmap, norm=norm, edgecolor='black', linewidth=0.5)
    plt.annotate(chr(index + 97), xy=(0,1.05), xycoords='axes fraction', fontsize=14)


def plot_scatter(index, country, parameter, season, df, title, label):
    ax = fig.add_subplot(gs[index])
    ax.set_facecolor('whitesmoke')
    plt.ylabel(f'Modelled, {label}', fontsize=14)
    plt.xlabel(f'Measured, {label}', fontsize=14)
    if parameter == 'pm25':
        vmax = 150
    elif parameter == 'o3':
        vmax = 100
    ax.set_xlim((0.0, vmax))
    ax.set_ylim((0.0, vmax))
    plt.annotate(chr(index + 97), xy=(0,1.05), xycoords='axes fraction', fontsize=14)
    plt.xticks(fontsize=14)
    plt.yticks(fontsize=14)
    plt.scatter(df['obs_value'], df['wrf_value'], marker='o', lw=0, c='#7fbf7b', s=70, alpha=0.8)
    x = np.arange(2 * vmax)
    plt.plot(x, x, '', color='black', ls='--')
    plt.plot(x, 0.5 * x, '', color='black', ls='--')
    plt.plot(x, 2 * x, '', color='black', ls='--')
    text = f"NMBF = {np.round(nmbfs[f'{country}_{parameter}_{season}'], decimals=2)}\nNMAEF = {np.round(nmaefs[f'{country}_{parameter}_{season}'], decimals=2)}"
    at = matplotlib.offsetbox.AnchoredText(text, prop=dict(size=12), frameon=True, loc=2)
    at.patch.set_boxstyle("round,pad=0.,rounding_size=0.2")
    ax.add_artist(at)

# ---------------
# processing
if use_china_measurements:
    obs_source = 'china_measurements'
elif use_openaq:
    obs_source = 'openaq'

df_values_files = {}
df_values_seasons = {}
nmbfs = {}
nmaefs = {}
obs_count = {}
season_dates = {'winter': '2015-02', 'spring': '2015-05', 'summer': '2015-08', 'autumn': '2015-11', 'annual': '2015'}

for country in countries:
    for parameter in parameters.keys():
        for season in season_dates.keys():
            df_values_files.update({f'{country}_{parameter}_{season}': sorted(glob.glob(f'{path}/df_values_{obs_source}_*{season_dates[season]}*_{parameter}_{country}.csv'))})

            obs_values_season = np.array([])
            wrf_values_season = np.array([])
            df_values_season_list = []

            for index in range(len(df_values_files[f'{country}_{parameter}_{season}'])):
                df_values = pd.read_csv(df_values_files[f'{country}_{parameter}_{season}'][index], index_col="datetime", parse_dates=True)
                lats = df_values['lat'].values
                lons = df_values['lon'].values
                obs_values = df_values['obs_value'].values
                wrf_values = df_values['wrf_value'].values              

                obs_values_season = np.append(obs_values_season, obs_values)
                wrf_values_season = np.append(wrf_values_season, wrf_values)

                df_values_season_list.append(df_values)

            obs_count.update({f'{country}_{parameter}_{season}': len(obs_values_season)})

            nmbfs.update({f'{country}_{parameter}_{season}': normalised_mean_bias_factor(obs_values_season, wrf_values_season)})
            nmaefs.update({f'{country}_{parameter}_{season}': normalised_mean_absolute_error_factor(obs_values_season, wrf_values_season)})

            df_values_season = pd.concat(df_values_season_list)
            df_values_season.to_csv(f'{path}/df_values_{obs_source}_{season}_{parameter}_{country}.csv')


print(f'Benchmarking against: {obs_source.upper()}')
for key in nmbfs.keys():
    print(f'Number of observations = {obs_count[key]}')
    print(f"NMBF  for {key.replace('_', ' ')} = {round(nmbfs[key], 2)}")
    print(f"NMAEF for {key.replace('_', ' ')} = {round(nmaefs[key], 2)}")
    print()

# ---------------
# plots
ds_seasons = {}
df_seasons = {}
labels = {
    'pm25': '$PM_{2.5}$ concentrations (${\mu}g$ $m^{-3}$)',
    'o3': '$O_3$ concentrations ($ppb$)',
}
for season in season_dates.keys():
    wrfout_files = sorted(glob.glob(f'{path}/wrfout_d01_{season_dates[season]}*'))
    ds_wrfouts_season = salem.open_mf_wrf_dataset(wrfout_files)

    for parameter in parameters.keys():
        ds_wrfouts_season_parameter_mean = ds_wrfouts_season[parameters[parameter]].isel(bottom_top=0).mean(dim='time')

        have_weights = len(glob.glob(f'{path}/bilinear*')) != 0
        regridder = xe.Regridder(ds_wrfouts_season_parameter_mean, grid_rectilinear_global, "bilinear", reuse_weights=have_weights)
        ds_wrfouts_season_parameter_mean_regrid = regridder(ds_wrfouts_season_parameter_mean)
        if parameter == 'o3':
            ds_wrfouts_season_parameter_mean_regrid = ds_wrfouts_season_parameter_mean_regrid * 1000
        ds_wrfouts_season_parameter_mean_regrid.to_netcdf(f'{path}/ds_values_{obs_source}_{season}_{parameter}_{country}.nc')
        ds_seasons.update({f'{parameter}_{season}': ds_wrfouts_season_parameter_mean_regrid})

        df_values_season = pd.read_csv(f'{path}/df_values_{obs_source}_{season}_{parameter}_{country}.csv', index_col="datetime", parse_dates=True)
        df_seasons.update({f'{parameter}_{season}': df_values_season})


xx, yy = np.meshgrid(ds_wrfouts_season_parameter_mean_regrid.lon.values, ds_wrfouts_season_parameter_mean_regrid.lat.values)

for parameter in parameters.keys():
    fig = plt.figure(1, figsize=(10, 25))
    gs = gridspec.GridSpec(5, 2)

    for index, season in enumerate(season_dates.keys()):
        plot_map(2 * index, 'CN', parameter, season, ds_seasons[f'{parameter}_{season}'], df_seasons[f'{parameter}_{season}'].groupby(['lat', 'lon',]).mean().reset_index(), f'{parameter.upper()} {season.upper()}', labels[parameter])
        plot_scatter(2 * index + 1, 'CN', parameter, season, df_seasons[f'{parameter}_{season}'].groupby(['lat', 'lon',]).mean(), f'{parameter.upper()} {season.upper()}', labels[parameter])

    gs.tight_layout(fig) 
    plt.savefig(f'{path}/benchmark_{parameter}_{obs_source}.png', dpi=700, alpha=True, bbox_inches='tight')
    plt.show()
