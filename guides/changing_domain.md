# Changing the WRF-Chem domain

### Viewing the current domain
WRFotron includes a script which makes a plot of the domain, `plotgrids.ncl`.
'ncl' stands for NCAR Command Language and is another programming language like python,
but hopefully you will never need to learn it.
1. On ARC4, load ncl by running `module load ncl`
2. Run the script: `ncl plotgrids.ncl`. This will create a file, `wps_show_dom.pdf`
3. Open the file. You can open files on linux with the default program by running
`xdg-open`. Try   
`xdg-open wps_show_dom.pdf`. You should see the default domain which includes
all of China.

### Changing the domains
To change the domain, we need to edit several variables in two of the namelist files,
`namelist.wps.blueprint` and `namelist.wrf.blueprint`.

`namelist.wps.blueprint` contains the following lines which define the domain:
```bash
&geogrid                                              ! geogrid
 parent_id         =   1, 1,                            ! domain number of the nest’s parent
 parent_grid_ratio =   1, 3,                            ! nesting ratio relative to the domain’s parent
 i_parent_start    =   1, 35,                           ! x coordinate of the lower-left corner
 j_parent_start    =   1, 10,                           ! y coordinate of the lower-left corner
 e_we              =  170, 220,                         ! westeast dimension
 e_sn              =  170, 120,                         ! southnorth dimension
 geog_data_res     = 'default', 'default',              ! resolution, or list of resolutions separated by + symbols, of source data to be used when interpolating static terrestrial data to the nest’s grid
 dx = 30000,                                            ! westeast resolution, in metres for 'polar', 'lambert', and 'mercator'
 dy = 30000,                                            ! westeast resolution, in metres for 'polar', 'lambert', and 'mercator'
 map_proj = 'lambert',                                  ! map projection
 ref_lat   =  33.0,                                     ! center latitude
 ref_lon   =  103.0,                                    ! centre longitude
 truelat1  =  23.0,                                     ! the first true latitude for the Lambert conformal projection, or the only true latitude for the Mercator and polar stereographic projections
 truelat2  =  43.0,                                     ! the second true latitude for the Lambert conformal conic projection. For all other projections, truelat2 is ignored
 stand_lon =  103.0,                                    ! the longitude that is parallel with the y-axis in the Lambert conformal and polar stereographic projections
 geog_data_path = '__geogDir__'                         ! path to the static geography files
/
```

The following variables should be modified when changing domain:  
1. Change `ref_lat` and `ref_lon` to move the centre of the domain.
2. Change the size of the domain by changing `dx` and `dy` as well as `e_we` and `e_sn`. `dx`
and `dy` change the size of grid cells in the x (longitude) and y (latitude) directions.
Changing them will change the model resolution, but will not affect the run time,
just how far apart the grid cells are spaced. `e_we` and `e_sn` change the number of grid cells
across the longitude and latitude of the domain, respectively.
Adding or removing gridcells can greatly increase/decrease the run time.
3. Change `truelat1` and `truelat2`. These should be equidistant to the centre
and top/bottom of the domain, respectively.
`stand_lon` should be the same as `ref_lon`
4. Finally, rerun `plotgrids.ncl` and check that the domain has been adjusted correctly.

`namelist.wrf.blueprint` also contains the variables
`e_we`, `e_sn`, `dx` and `dy`. The values need to be changed so they are the same as
in  `namelist.wps.blueprint`.
