#!/usr/bin/env python3
"""
WRFotron postprocessing script to create new variables
Based on the NCL postprocessing script (pp.ncl)
Using same variable names for consistency

Example:
    python postprocessing.py inFile outFile WRFChem_path
    
"""
import sys
from netCDF4 import Dataset
from wrf import getvar
from wrf import destagger
import numpy as np
import xarray as xr
import re

def create_variables(raw_wrfout_filename):
    """
    Description:
        Creates variables that are not in the raw wrfout files.
        
    Arguments:
        raw_wrfout_file(string): path to raw wrfout file.
        
    Returns:
        new_wrfout_file(xarray.core.dataset.Dataset): Saved Dataset with all created variables.
    """
    # open raw NetCDF file
    raw_wrfout_file_nc = Dataset(raw_wrfout_filename, mode='r')
    
    # extract variables
    timestamp = getvar(raw_wrfout_file_nc, 'Times')
    timestamp = timestamp.rename('timestamp')
    timestamp = timestamp.assign_coords(XTIME=getvar(raw_wrfout_file_nc, 'pres').coords['Time']) # add both XTIME and time coords
    timestamp = timestamp.drop('Time') # drop coord
    timestamp = timestamp.expand_dims(dim='Time') # add dim

    pres = getvar(raw_wrfout_file_nc, 'p')
    pres = pres.rename('pres')

    pres_sea_level = getvar(raw_wrfout_file_nc, 'slp')
    pres_sea_level = pres_sea_level.rename('p_sl')

    rel_humidity = getvar(raw_wrfout_file_nc, 'rh')

    rel_humidity_2m = getvar(raw_wrfout_file_nc, 'rh2')
    rel_humidity_2m = rel_humidity_2m.rename('rh_2m')

    temp_dew = getvar(raw_wrfout_file_nc, 'td')

    temp_dew_2m = getvar(raw_wrfout_file_nc, 'td2')
    temp_dew_2m = temp_dew_2m.rename('td_2m')

    temp = getvar(raw_wrfout_file_nc, 'tk')
    temp = temp.rename('tk')

    temp_potential = getvar(raw_wrfout_file_nc, 'th')
    temp_potential = temp_potential.rename('th')

    terrain = getvar(raw_wrfout_file_nc, 'ter')

    height = getvar(raw_wrfout_file_nc, 'z')
    height = height.rename('z')
    
    # convert dew temps to kelvin
    temp_dew = temp_dew + 273.15
    temp_dew.attrs = pres.attrs # copy attributes as removed when broadcasting
    temp_dew.attrs['units'] = 'K'
    temp_dew.attrs['description'] = 'dew point temperature'
    temp_dew_2m = temp_dew_2m + 273.15
    temp_dew_2m.attrs = pres.attrs # copy attributes as removed when broadcasting
    temp_dew_2m.attrs['units'] = 'K'
    temp_dew_2m.attrs['description'] = '2m dew point temperature'

    # rotate wind to Earth coordinates
    wind_u = getvar(raw_wrfout_file_nc, 'uvmet').isel(u_v=0)
    wind_u = wind_u.rename('u_ll')
    wind_v = getvar(raw_wrfout_file_nc, 'uvmet').isel(u_v=1)
    wind_v = wind_v.rename('v_ll')
    wind_u_10m = getvar(raw_wrfout_file_nc, 'uvmet10').isel(u_v=0)
    wind_u_10m = wind_u_10m.rename('u_ll_10m')
    wind_v_10m = getvar(raw_wrfout_file_nc, 'uvmet10').isel(u_v=1)
    wind_v_10m = wind_v_10m.rename('v_ll_10m')
    wind_w = getvar(raw_wrfout_file_nc, 'wa')
    wind_w = wind_w.rename('w_ll')
    
    # calculate layer thickness
    geopotential_perturbation = getvar(raw_wrfout_file_nc, 'PH')
    geopotential_base_state = getvar(raw_wrfout_file_nc, 'PHB')
    
    altitude = (geopotential_perturbation + geopotential_base_state) / 9.81
    altitude.loc[dict(bottom_top_stag=0)] = altitude.isel(bottom_top_stag=0) - terrain
    altitude.attrs = geopotential_perturbation.attrs # copy attributes
    altitude.attrs['units'] = 'm'
    altitude.attrs['description'] = 'altitude'
    altitude = altitude.rename('altitude')
    
    layer_thickness = altitude.copy()
    for layer in range(0, len(altitude.bottom_top_stag)):
        if layer == 0:
            pass
        else:
            layer_thickness.loc[dict(bottom_top_stag=layer)] = altitude.isel(bottom_top_stag=layer) - altitude.isel(bottom_top_stag=layer - 1)
    
    layer_thickness.attrs = altitude.attrs # copy attributes
    layer_thickness.attrs['units'] = 'm'
    layer_thickness = layer_thickness.rename('dz')

    # create destaggered version for use in conversions below
    layer_thickness_destaggered = xr.DataArray(
        destagger(layer_thickness, stagger_dim=0),
        dims=('bottom_top', 'south_north', 'west_east'),
        coords=layer_thickness.coords,
        attrs=layer_thickness.attrs
    )
    
    # inverse density
    inverse_density = getvar(raw_wrfout_file_nc, 'ALT') # m3 kg-1
    
    # cloud liquid water path
    cloud_liquid_water = getvar(raw_wrfout_file_nc, 'QCLOUD') # kg kg-1
    cloud_liquid_water_path = cloud_liquid_water / inverse_density / layer_thickness_destaggered * 1e3
    cloud_liquid_water_path = cloud_liquid_water_path.sum(dim='bottom_top')
    cloud_liquid_water_path.attrs = cloud_liquid_water.attrs
    cloud_liquid_water_path.attrs['units'] = 'g m-2'
    cloud_liquid_water_path.attrs['description'] = 'cloud liquid water path'
    cloud_liquid_water_path = cloud_liquid_water_path.rename('CLWP')

    # cloud ice path
    cloud_ice = getvar(raw_wrfout_file_nc, 'QICE') # kg kg-1
    cloud_ice_path = cloud_ice / inverse_density / layer_thickness_destaggered * 1e3
    cloud_ice_path = cloud_ice_path.sum(dim='bottom_top')
    cloud_ice_path.attrs = cloud_ice.attrs
    cloud_ice_path.attrs['units'] = 'g m-2'
    cloud_ice_path.attrs['description'] = 'cloud ice path'
    cloud_ice_path = cloud_ice_path.rename('CIP')
    
    # cloud water vapor columns
    cloud_water_vapor = getvar(raw_wrfout_file_nc, 'QVAPOR') # rho_water = 1000 kg m-3
    cloud_water_vapor_column = cloud_water_vapor / inverse_density / layer_thickness_destaggered / 1000.0 * 1e2
    cloud_water_vapor_column = cloud_water_vapor_column.sum(dim='bottom_top')
    cloud_water_vapor_column.attrs = cloud_water_vapor.attrs
    cloud_water_vapor_column.attrs['units'] = 'cm3 cm-2'
    cloud_water_vapor_column.attrs['description'] = 'cloud water vapor column'
    cloud_water_vapor_column = cloud_water_vapor_column.rename('H2O')
    
    # wind speed and direction
    wind_speed = np.sqrt((wind_u ** 2) + (wind_v ** 2))
    wind_speed.attrs = wind_u.attrs
    wind_speed.attrs['description'] = 'wind speed'
    wind_speed = wind_speed.rename('wspeed')
    wind_speed_10m = np.sqrt((wind_u_10m ** 2) + (wind_v_10m ** 2))
    wind_speed_10m.attrs = wind_u_10m.attrs
    wind_speed_10m.attrs['description'] = 'wind speed at 10m'
    wind_speed_10m = wind_speed_10m.rename('wspeed_10m')
    
    wind_direction = np.rad2deg(np.arctan2(wind_u, wind_v)) + 180.0
    wind_direction.attrs = wind_u.attrs
    wind_direction.attrs['units'] = 'degrees'
    wind_direction.attrs['description'] = 'wind direction'
    wind_direction = wind_direction.rename('wdir')
    
    wind_direction_10m = np.rad2deg(np.arctan2(wind_u_10m, wind_v_10m)) + 180.0
    wind_direction_10m.attrs = wind_u_10m.attrs
    wind_direction_10m.attrs['units'] = 'degrees'
    wind_direction_10m.attrs['description'] = 'wind direction at 10m'
    wind_direction_10m = wind_direction_10m.rename('wdir_10m')
    
    # aerosol optical depth, AOD, column and surface
    optical_thickness_a01 = getvar(raw_wrfout_file_nc, 'TAUAER1') # 300 nm
    optical_thickness_a02 = getvar(raw_wrfout_file_nc, 'TAUAER2') # 400 nm
    optical_thickness_a03 = getvar(raw_wrfout_file_nc, 'TAUAER3') # 600 nm
    optical_thickness_a04 = getvar(raw_wrfout_file_nc, 'TAUAER4') # 1000 nm
    
    # AOD at 470 nm
    angstrom_exponent = -1 * np.log(optical_thickness_a02 / optical_thickness_a03) / np.log(400.0 / 600.0)
    AOD470 = optical_thickness_a02 * (470.0 / 600.0) ** (-1 * angstrom_exponent)
    AOD470.attrs = optical_thickness_a01.attrs
    AOD470.attrs['units'] = ''
    AOD470.attrs['description'] = 'aerosol optical depth at 470 nm'
    AOD470 = AOD470.rename('AOD470')
    
    AOD470_sfc = AOD470.sum(dim='bottom_top') # sum up all the values for every level in the atmospheric column
    AOD470_sfc.attrs = optical_thickness_a01.attrs
    AOD470_sfc.attrs['units'] = ''
    AOD470_sfc.attrs['description'] = 'surface aerosol optical depth at 470 nm'
    AOD470_sfc = AOD470_sfc.rename('AOD470_sfc')
    
    # AOD at 550 nm
    angstrom_exponent = -1 * np.log(optical_thickness_a02 / optical_thickness_a03) / np.log(400.0 / 600.0)
    AOD550 = optical_thickness_a02 * (550.0 / 600.0) ** (-1 * angstrom_exponent)
    AOD550.attrs = pres.attrs
    AOD550.attrs['units'] = ''
    AOD550.attrs['description'] = 'aerosol optical depth at 550 nm'
    AOD550 = AOD550.rename('AOD550')
    
    AOD550_sfc = AOD550.sum(dim='bottom_top') # sum up all the values for every level in the atmospheric column
    AOD550_sfc.attrs = pres.attrs
    AOD550_sfc.attrs['units'] = ''
    AOD550_sfc.attrs['description'] = 'surface aerosol optical depth at 550 nm'
    AOD550_sfc = AOD550_sfc.rename('AOD550_sfc')
    
    # AOD at 675 nm
    angstrom_exponent = -1 * np.log(optical_thickness_a03 / optical_thickness_a04) / np.log(600.0 / 1000.0)
    AOD675 = optical_thickness_a03 * (675.0 / 1000.0) ** (-1 * angstrom_exponent)
    AOD675.attrs = pres.attrs
    AOD675.attrs['units'] = ''
    AOD675.attrs['description'] = 'aerosol optical depth at 675 nm'
    AOD675 = AOD675.rename('AOD675')
    
    AOD675_sfc = AOD675.sum(dim='bottom_top') # sum up all the values for every level in the atmospheric column
    AOD675_sfc.attrs = pres.attrs
    AOD675_sfc.attrs['units'] = ''
    AOD675_sfc.attrs['description'] = 'surface aerosol optical depth at 675 nm'
    AOD675_sfc = AOD675_sfc.rename('AOD675_sfc')
    
    # convert raw netCDF to xarray dataset
    raw_wrfout_file_xr = xr.open_dataset(xr.backends.NetCDF4DataStore(raw_wrfout_file_nc))

    # list of variables
    variables = [
        timestamp,
        pres,
        pres_sea_level,
        rel_humidity,
        rel_humidity_2m,
        temp_dew,
        temp_dew_2m,
        temp,
        temp_potential,
        terrain,
        height,
        wind_u,
        wind_v,
        wind_u_10m,
        wind_v_10m,
        wind_w,
        geopotential_perturbation,
        geopotential_base_state,
        layer_thickness,
        cloud_liquid_water_path,
        cloud_ice_path,
        cloud_water_vapor_column,
        wind_speed,
        wind_speed_10m,
        wind_direction,
        wind_direction_10m,
        AOD470,
        AOD470_sfc,
        AOD550,
        AOD550_sfc,
        AOD675,
        AOD675_sfc
    ]

    # correct coords and dims
    variables_with_time = []
    for variable in variables:
        if variable.name == 'timestamp':
            variable['XTIME'] = raw_wrfout_file_xr['XTIME']
        else:
            if 'u_v' in variable.coords:
                variable = variable.drop('u_v')

            variable = variable.drop('Time') # remove erroneous time coord
            variable = variable.expand_dims(dim='Time') # add time as a dim
            variable['XTIME'] = raw_wrfout_file_xr['XTIME'] # add time dim to time coord
            variable['XLAT'] = raw_wrfout_file_xr['XLAT'] # add time dim to lat coord
            variable['XLONG'] = raw_wrfout_file_xr['XLONG'] # add time dim to lon coord
            del variable.attrs['projection']
            del variable.attrs['coordinates']

            if '_FillValue' in variable.attrs:
                del variable.attrs['_FillValue']
            
            if 'missing_value' in variable.attrs:
                del variable.attrs['missing_value']

        variables_with_time.append(variable)

    # new xarray dataset with new variables
    new_wrfout_file_xr = xr.merge(
        variables_with_time, # combine raw with new
        compat='override' # skip comparing and pick variable from first dataset
    ) 
    
    # save new xarray dataset
    # base format on the WRFChem version
    wrfchem_version = re.findall(r'\d+[\.]?[\d+]?[\.]?\d+]?', sys.argv[3])[-1]
    if float(wrfchem_version[0:3]) < 4.0: # pre 4.0 use NETCDF3 CLASSIC
        new_wrfout_file_xr.to_netcdf(sys.argv[2], format='NETCDF3_CLASSIC')
    else: # post 4.0, use NETCDF4 / HDF5 (default)
        new_wrfout_file_xr.to_netcdf(sys.argv[2])

    # close file handles
    raw_wrfout_file_nc.close()
    new_wrfout_file_xr.close()
    

def main():
    create_variables(sys.argv[1])


if __name__ == '__main__':
    main()


