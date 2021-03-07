import xarray as xr
import salem
import os
import glob
import xesmf as xe
import numpy as np

year = "2016"
month = "10"
res = 0.25
domains = ["1"]
variables = ["PM2_5_DRY", "o3", "AOD550_sfc"]
aerosols = ["bc", "oc", "nh4", "so4", "no3", "asoaX", "bsoaX", "oin"]
variables.extend(aerosols)
surface_only = "yes"
regrid = "yes"

for domain in domains:
    path = os.getcwd()
    filelist = sorted(glob.glob(f"{path}/wrfout_d0{domain}_{year}-{month}*"))
    for variable in variables:
        with salem.open_mf_wrf_dataset(
            filelist, chunks={"west_east": "auto", "south_north": "auto"}
        ) as ds:
            if (surface_only == "yes") and (variable in aerosols):
                wrf_a01 = ds[variable + "_a01"].isel(bottom_top=0)
                wrf_a02 = ds[variable + "_a02"].isel(bottom_top=0)
                wrf_a03 = ds[variable + "_a03"].isel(bottom_top=0)
                wrf = wrf_a01 + wrf_a02 + wrf_a03
                wrf = wrf / ds['ALT'] # unit conversion from ug/kg to ug/m3
            elif (
                (surface_only == "yes")
                and (variable == "PM2_5_DRY")
                or (variable == "o3")
            ):
                wrf = ds[variable].isel(bottom_top=0)
            else:
                wrf = ds[variable]

        if regrid == "yes":
            ds_out = xr.Dataset(
                {
                    "lat": (["lat"], np.arange(-60, 85, res)),
                    "lon": (["lon"], np.arange(-180, 180, res)),
                }
            )
            have_weights = len(glob.glob(f'{path}/bilinear*')) != 0
            regridder = xe.Regridder(wrf, ds_out, "bilinear", reuse_weights=have_weights)
            wrf_regrid = regridder(wrf)

        if variable in aerosols:
            wrf_regrid.to_netcdf(
                f"{path}/wrfout_d0{domain}_global_{res}deg_{year}-{month}_{variable}_2p5.nc"
            )
        else:
            wrf_regrid.to_netcdf(
                f"{path}/wrfout_d0{domain}_global_{res}deg_{year}-{month}_{variable}.nc"
            )
