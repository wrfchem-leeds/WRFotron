import xarray as xr
import salem
import os
import glob
import xesmf as xe
import numpy as np

# steps
# 1. accounts for the staggered nature of the wrfchem grid
# 2. combines the hourly wrfout files to monthly files
# 3. extracts only the variables of interest (some at the surface only and some with converted units)
# 4. regrids (optional) the variables to a global rectilinear grid

# setup - ensure meets your requirements
year = "2016"
month = "10"
domains = ["1"]
variables = ["PM2_5_DRY", "o3", "AOD550_sfc"]
aerosols = ["bc", "oc", "nh4", "so4", "no3", "asoaX", "bsoaX", "oin"]
variables.extend(aerosols)
surface_only = True
res = 0.25
regrid = True
convert_aerosol_units_from_ugkg_to_ugm3 = True

for domain in domains:
    path = os.getcwd()
    filelist = sorted(glob.glob(f"{path}/wrfout_d0{domain}_{year}-{month}*"))
    for variable in variables:
        with salem.open_mf_wrf_dataset(
            filelist, chunks={"west_east": "auto", "south_north": "auto"}
        ) as ds:
            if surface_only and (variable in aerosols):
                wrf_a01 = ds[variable + "_a01"].isel(bottom_top=0)
                wrf_a02 = ds[variable + "_a02"].isel(bottom_top=0)
                wrf_a03 = ds[variable + "_a03"].isel(bottom_top=0)
                wrf = wrf_a01 + wrf_a02 + wrf_a03
                if convert_aerosol_units_from_ugkg_to_ugm3:
                    inverse_density = ds['ALT'].isel(bottom_top=0)
                    wrf = wrf / inverse_density
            elif (
                surface_only
                and (variable == "PM2_5_DRY")
                or (variable == "o3")
            ):
                wrf = ds[variable].isel(bottom_top=0)
            else:
                wrf = ds[variable]

        if regrid:
            ds_out = xr.Dataset(
                {
                    "lat": (["lat"], np.arange(-60, 85, res)),
                    "lon": (["lon"], np.arange(-180, 180, res)),
                }
            )
            have_weights = len(glob.glob(f'{path}/bilinear*')) != 0
            regridder = xe.Regridder(wrf, ds_out, "bilinear", reuse_weights=have_weights)
            wrf_regrid = regridder(wrf)

        if variable in aerosols and regrid:
            wrf_regrid.to_netcdf(
                f"{path}/wrfout_d0{domain}_global_{res}deg_{year}-{month}_{variable}_2p5.nc"
            )
        elif regrid:
            wrf_regrid.to_netcdf(
                f"{path}/wrfout_d0{domain}_global_{res}deg_{year}-{month}_{variable}.nc"
            )
        else:
            wrf.to_netcdf(
                f"{path}/wrfout_d0{domain}_global_{res}deg_{year}-{month}_{variable}.nc"
            )
