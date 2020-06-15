;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; wrfout_to_cf.ncl
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; -NCL script to read an ARW wrfout NetCDF file on staggered model
;  grid and to output unstaggered values in NetCDF CF compliant format.
; -Extensive help in maintaining and adding to the script was provide by
;  Matt Higgins.
;
; command syntax:
;   ncl 'file_in="wrfout.nc"' 'file_out="wrfpost.nc"' wrfout_to_cf.ncl
;
; -The NCL script is executed by the above command syntax.  Alternatively,
;  the file_out and file_in can be set in the script and there is then no
;  need to specify it at the command prompt.
; -The values that are to be included in the output are determined by
;  setting several attribute variables to True (include) or False (skip).
;  These attribute variables are set at around line 160 in this script.
; -Setting the overall variable of a group of variables to false will exclude
;  all of the variables in that group from the output file.  For example, 
;  setting the variable out2dMet to False means that all 2dMet variables will 
;  not be included.  If out2dMet is set to true, all of the individual variable 
;  attributes (i.e. out2dMet@T_sfc, out2dMet@T_2m, etc.) that are also set to
;  true will be included in the output file.
;
; Support information:
;  This script is semi-supported on a time available basis.  If
;  you come across an error, or have an idea for an improvement, please send
;  an email.  I will update the script on a time when I have time.  Send all 
;  inquiries or questions to: Mark Seefeldt - mark.seefeldt@colorado.edu
;
; Release Notes:  v2.0.0
; -release notes for all versions can be found at:
;     http://foehn.colorado.edu/wrfout_to_cf/
; -v2.0.0
;   NOTE:  A significant change was made to re-name all mixing ratio
;          variables to 'r_' from 'q'.  Examples:
;          Before:  q_2m   Now:  r_v_2m
;                   q_e          r_v_e
;                   q_p          r_v_p
;                   q_cloud      r_cloud
;                   q_rain_p     r_rain_p
;          This change was made with the addition of specific humidty as a
;          moisture output option.  The decision was made to go with the more
;          community accepted variable of 'r' to represent mixing ratio.
;          The previous values of q_2m, q_e, and q_p now represent specific
;          humidity.
;
;  -Added specific humidity as an output at 2m, eta levels, and pressure levels.
;  -All measures of moisture (Td, RH, r_v, q) are available at 2m, eta levels,
;   and pressure levels.
;  -Added winds rotated to true earth coord. at 2m, eta, and pressure levels.
;  -Added wind direction (Earth) and wind speed at 2m, eta, and pressure levels.
;  -Added potential vorticity and absolute vorticity at eta and pressure levels. 
;  -Changed several variable names to more simples forms.
;    ex: SHFlx and LHFlx to SH and LH.
;  -Added a CLWRF section of a selection of CLWRF variables.
;  -Reorganized the code for a simpler and easy to follow layout.
;
; TODO:  In an upcoming release there will be an option to use CMIP variable
;        names in the output file.  There are placeholders for this option
;        that are included below, but this is not an active feature at this
;        point.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; load in the libraries
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; procedure to process the attributes in creating CF compliant WRF output
procedure assignVarAttCoord(x:numeric, time[*]:numeric, vert[*]:numeric,  \
                             fl_vert:numeric)
  ; x:numeric        -variable to process the attributes
  ; time[*]:numeric  -array with time values for adding coordinates
  ; vert[*]:numeric  -array with vertical values for adding coordinates
  ;                  Note: set to 0 if no vertical coordinate
  ; fl_vert:numeric  -flag indicating vertical coordinate type
  ;                   0 = no vertical coordinate (x,y only)
  ;                   1 = pressure
  ;                   2 = eta
  ;                   3 = soil
  ; MissingValue     -assigned missing value attribute
begin
  ; assign the default missing value
  MissingValue               = 1e20
  ; set time for all variables
  x!0 = "time"
  x&time = time
  ; set the vertical coordinate depending on fl_vert
  if (fl_vert .eq. 1) then             ;pressure as vertical coordinate
    x!1 = "pressure"
    x&pressure = vert
    ;x@missing_value = MissingValue
    x@_FillValue = MissingValue
  end if
  if (fl_vert .eq. 2) then             ;eta as vertical coordinate
    x!1 = "eta"
    x&eta = vert
    x@_FillValue = MissingValue
  end if
  if (fl_vert .eq. 3) then             ;soil as vertical coordinate
    x!1 = "soil"
    x&soil = vert
    x@_FillValue = MissingValue
  end if
  ; set the horizontal coordinates
  if (fl_vert .eq. 0) then             ;no vertical coordinate 
    x!1 = "south_north"
    x!2 = "west_east"
    ;x@missing_value = MissingValue
    x@_FillValue = MissingValue
  else                                 ;with vertical coordinate
    x!2 = "south_north"
    x!3 = "west_east"
    ;x@missing_value = MissingValue
    x@_FillValue = MissingValue
  end if
  ; set the mapping coordinates
  x@coordinates = "lon lat"
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; start the primary wrfout_to_cf.ncl program
begin
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; configuration settings
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; set the units for time
  TimeUnits = "days since 2000-01-01 00:00:00"
  ; set the values for pressure to be interpolated
  pressure = (/1000.,850.,700.,500.,300./)
  ; set the limits for the output range
  ;   0 = beginning of dataset
  ;   9999 = end of dataset
  ;   Note: remember that the array is zero-based
  limTime = (/0,9999/)
  limS_N = (/0,9999/)
  limW_E = (/0,9999/)
  limPres = (/0,9999/)
  limEta = (/0,9999/)
  limSoil = (/0,9999/)
  ; set default values for file_in, dir_in, and file_out, if not specified
  if (.not.isvar("file_in")) then
    file_in = "wrfout_d02_2005-11-19_00:00:00"
  end if
  if (.not.isvar("dir_in")) then
    dir_in = "./"
  end if
  if (.not.isvar("file_out")) then
    file_out = "wrfpost.nc"
  end if
  if (.not.isvar("dir_out")) then
    dir_out = "./"
  end if
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;; set the flags for selecting variables to be included ;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; Note:  Not all of the indicated values below can be extracted / 
  ;        converted from a given wrfout file.  Some of the fields are
  ;        included with only specific WRF physics options.
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; output settings
  axis                       = True      ;one-dimensional coordinate fields
  projection                 = False     ;CF projection info with fields
  outPtop                    = False     ;include Ptop in the output file
  ;outCMIP                   = False     ;use CMIP variable names in output
  ;MissingValue              = nan   ;missing value
  ; Note: MissingValue is currently assigned in the procedure assignVarAttCoord
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; set the netcdf file global attributes
  fileAtt                = True
  fileAtt@creation_date  =  systemfunc("date")
  fileAtt@institution    = "University of Leeds"
  fileAtt@created_by     = "Luke Conibear - pmlac@leeds.ac.uk"
  fileAtt@notes          = "Created with NCL script:  wrfout_to_cf.ncl v2.0"
  fileAtt@source         = file_in
  fileAtt@Conventions    = "CF 1.6, Standard Name Table v19"
  fileAtt@title          = file_out
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; time / date variables
  outDateTime                = True      ;include a yyyymmddhh field
  outUTCDate                 = True      ;include yr,mo,dy,hr,mn fields
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; two-dimensional near-surface / surface met variables
  out2dMet                   = True
  out2dMet@SST               = False      ;sea-surface temperature
  out2dMet@T_sfc             = False      ;temperature at the surface
  out2dMet@p_sfc             = True      ;pressure at the surface
  out2dMet@slp               = False      ;sea-level pressure - using WRF-NCL
  out2dMet@slp_b             = False      ;sea-level pressure - lowest eta level
  out2dMet@T_2m              = True      ;temperature at 2m
  out2dMet@theta_2m          = False      ;potential temperature at 2m
  out2dMet@Td_2m             = False      ;dewpoint temperature at 2m
  out2dMet@r_v_2m            = False      ;mixing ratio at 2m
  out2dMet@q_2m              = False      ;specific humidity at 2m
  out2dMet@rh_2m             = False      ;relative humidity at 2m
  out2dMet@u_10m_gr          = True      ;u wind - grid - at 10m
  out2dMet@v_10m_gr          = True      ;v wind - grid - at 10m
  out2dMet@u_10m_tr          = True      ;u wind - rotated to earth - at 10m
  out2dMet@v_10m_tr          = True      ;v wind - rotated to earth - at 10m
  out2dMet@ws_10m            = True      ;wind speed - at 10m
  out2dMet@wd_10m            = True      ;wind direction - earth - at 10m
  ;Warning:  When using u_10m_tr / v_10m_tr / wd_10m / wd_10m there appears
  ;          to be a warning error stating that the input field was not
  ;          unstaggered.  This appears to be an error in wrf_user_getvar
  ;          as it appears to be a bug in hadling the fact that the 10m winds
  ;          are already unstaggered.  This is uncomfirmed.  There appears to 
  ;          be no ill effects of the warning.
  out2dMet@precip_g          = True       ;total grid scale precipitation
  out2dMet@precip_c          = True       ;total cumulus precipitation
  out2dMet@precip_fr         = False      ;fraction of frozen nonconv. precip
  out2dMet@dryairmass        = False      ;total dry air mass in column
  out2dMet@pblh              = True       ;PBL height
  out2dMet@rho               = False      ;density at lowest eta level
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; three-dimensional upper-level (eta levels) meteorology variables
  outEta                     = True
  outEta@p_e                 = False      ;pressure - eta
  outEta@Z_e                 = False      ;geopotential height - eta
  outEta@T_e                 = False      ;temperature - eta
  outEta@theta_e             = False      ;potential temperature - eta
  outEta@Td_e                = False      ;dewpoint temperature - eta
  outEta@r_v_e               = False      ;mixing ratio - eta
  outEta@q_e                 = False      ;specific humidity - eta
  outEta@rh_e                = False      ;relative humidity - eta
  outEta@u_gr_e              = False      ;u wind - grid - eta
  outEta@v_gr_e              = False      ;v wind - grid - eta
  outEta@u_tr_e              = False      ;u wind - rotated to earth - eta
  outEta@v_tr_e              = False      ;v wind - rotated to earth - eta
  outEta@ws_e                = False      ;wind speed - eta
  outEta@wd_e                = False      ;wind direction - earth - eta
  outEta@w_e                 = False      ;w wind - eta
  outEta@pp_e                = False      ;pressure pert. - eta
  outEta@r_cloud             = False      ;cloud mixing ratio - eta
  outEta@r_rain              = False      ;rain mixing ratio - eta
  outEta@r_ice               = False      ;ice mixing ratio - eta
  outEta@r_snow              = False      ;snow mixing ratio - eta
  outEta@r_graup             = False      ;graupel mixing ratio - eta
  outEta@pvo_e               = False      ;potential vorticity - eta
  outEta@avo_e               = False      ;absolute vorticity - eta
  outEta@o3_e                = True       ;o3 - eta
  outEta@AOD470_e            = False       ; AOD at 470nm
  outEta@AOD550_e            = False       ; AOD at 550nm
  outEta@AOD675_e            = False       ; AOD at 675nm
  outEta@PM2_5_DRY_e         = True       ; PM2.5 aerosol dry mass
  outEta@PM10_e              = True       ; PM10 dry mass
  outEta@co_e                = True       ; CO mixing ratio
  outEta@no2_e               = True       ; NO2 mixing ratio
  outEta@so2_e               = True       ; SO2 mixing ratio
  outEta@bc_a01_e            = True       ; Black carbon, aerosol bin 01
  outEta@bc_a02_e            = True       ; Black carbon, aerosol bin 02
  outEta@bc_a03_e            = True       ; Black carbon, aerosol bin 03
  outEta@bc_a04_e            = True       ; Black carbon, aerosol bin 04
  outEta@oc_a01_e            = True       ; Organic carbon, aerosol bin 01
  outEta@oc_a02_e            = True       ; Organic carbon, aerosol bin 02
  outEta@oc_a03_e            = True       ; Organic carbon, aerosol bin 03
  outEta@oc_a04_e            = True       ; Organic carbon, aerosol bin 04
  outEta@num_a01_e           = True       ; Number, aerosol bin 01
  outEta@num_a02_e           = True       ; Number, aerosol bin 02
  outEta@num_a03_e           = True       ; Number, aerosol bin 03
  outEta@num_a04_e           = True       ; Number, aerosol bin 04
  outEta@water_a01_e         = True       ; water, aerosol bin 01
  outEta@water_a02_e         = True       ; water, aerosol bin 02
  outEta@water_a03_e         = True       ; water, aerosol bin 03
  outEta@water_a04_e         = True       ; water, aerosol bin 04
  outEta@so4_a01_e           = True       ; Sulphate, aerosol bin 01
  outEta@so4_a02_e           = True       ; Sulphate, aerosol bin 02
  outEta@so4_a03_e           = True       ; Sulphate, aerosol bin 03
  outEta@so4_a04_e           = True       ; Sulphate, aerosol bin 04
  outEta@no3_a01_e           = True       ; Nitrate, aerosol bin 01
  outEta@no3_a02_e           = True       ; Nitrate, aerosol bin 02
  outEta@no3_a03_e           = True       ; Nitrate, aerosol bin 03
  outEta@no3_a04_e           = True       ; Nitrate, aerosol bin 04
  outEta@nh4_a01_e           = True       ; Ammonium, aerosol bin 01
  outEta@nh4_a02_e           = True       ; Ammonium, aerosol bin 02
  outEta@nh4_a03_e           = True       ; Ammonium, aerosol bin 03
  outEta@nh4_a04_e           = True       ; Ammonium, aerosol bin 04
  outEta@asoaX_a01_e          = True       ; Simplified anthropogenic SOA, aerosol bin 01
  outEta@asoaX_a02_e          = True       ; Simplified anthropogenic SOA, aerosol bin 02
  outEta@asoaX_a03_e          = True       ; Simplified anthropogenic SOA, aerosol bin 03
  outEta@asoaX_a04_e          = True       ; Simplified anthropogenic SOA, aerosol bin 04
  outEta@bsoaX_a01_e         = True       ; Simplified biomass burning SOA, aerosol bin 01
  outEta@bsoaX_a02_e         = True       ; Simplified biomass burning SOA, aerosol bin 02
  outEta@bsoaX_a03_e         = True       ; Simplified biomass burning SOA, aerosol bin 03
  outEta@bsoaX_a04_e         = True       ; Simplified biomass burning SOA, aerosol bin 04
  outEta@glysoa_sfc_a01_e    = True       ; SOA from glyoxal, aerosol bin 01
  outEta@glysoa_sfc_a02_e    = True       ; SOA from glyoxal, aerosol bin 02
  outEta@glysoa_sfc_a03_e    = True       ; SOA from glyoxal, aerosol bin 03
  outEta@glysoa_sfc_a04_e    = True       ; SOA from glyoxal, aerosol bin 04
  outEta@na_a01_e            = True       ; Sodium, aerosol bin 01
  outEta@na_a02_e            = True       ; Sodium, aerosol bin 02
  outEta@na_a03_e            = True       ; Sodium, aerosol bin 03
  outEta@na_a04_e            = True       ; Sodium, aerosol bin 04
  outEta@biog1_o_a01_e       = False       ; Biogenic SOA from isoprene, aerosol bin 01
  outEta@biog1_o_a02_e       = False       ; Biogenic SOA from isoprene, aerosol bin 02
  outEta@biog1_o_a03_e       = False       ; Biogenic SOA from isoprene, aerosol bin 03
  outEta@biog1_o_a04_e       = False       ; Biogenic SOA from isoprene, aerosol bin 04
  outEta@biog1_c_a01_e       = False       ; Biogenic SOA from pinenes, aerosol bin 01
  outEta@biog1_c_a02_e       = False       ; Biogenic SOA from pinenes, aerosol bin 02
  outEta@biog1_c_a03_e       = False       ; Biogenic SOA from pinenes, aerosol bin 03
  outEta@biog1_c_a04_e       = False       ; Biogenic SOA from pinenes, aerosol bin 04
  outEta@oin_a01_e           = True       ; Other inorganics (including dust), aerosol bin 01
  outEta@oin_a02_e           = True       ; Other inorganics (including dust), aerosol bin 02
  outEta@oin_a03_e           = True       ; Other inorganics (including dust), aerosol bin 03
  outEta@oin_a04_e           = True       ; Other inorganics (including dust), aerosol bin 04
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; three-dimensional upper-level (pressure levels) meteorology variables
  outPressure                = False
  outPressure@Z_p            = False      ;geopotential height - pressure
  outPressure@T_p            = False      ;temperature - pressure
  outPressure@theta_p        = False      ;potential temperature - pressure
  outPressure@Td_p           = False      ;dewpoint temperature - pressure
  outPressure@r_v_p          = False      ;mixing ratio - pressure
  outPressure@q_p            = False      ;specific humidity - pressure
  outPressure@rh_p           = False      ;relative humidity - pressure
  outPressure@u_gr_p         = False      ;u wind - grid - pressure
  outPressure@v_gr_p         = False      ;v wind - grid - pressure
  outPressure@u_tr_p         = False      ;u wind - rotated to earth - pressure
  outPressure@v_tr_p         = False      ;v wind - rotated to earth - pressure
  outPressure@ws_p           = False      ;wind speed - pressure
  outPressure@wd_p           = False      ;wind direction - earth - pressure
  outPressure@w_p            = False      ;w wind - pressure
  outPressure@pp_p           = False      ;pressure pert. - pressure
  outPressure@r_cloud_p      = False      ;cloud mixing ratio - pressure
  outPressure@r_rain_p       = False      ;rain mixing ratio - pressure
  outPressure@r_ice_p        = False      ;ice mixing ratio - pressure
  outPressure@r_snow_p       = False      ;snow mixing ratio - pressure
  outPressure@r_graup_p      = False      ;graupel mixing ratio - pressure
  outPressure@pvo_p          = False      ;potential vorticity - pressure
  outPressure@avo_p          = False      ;absolute vorticity - pressure
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; two-dimensional surface energy budget / radiation variables
  out2dRadFlx                = True
  out2dRadFlx@SW_d           = True      ;SW flux - downward - sfc - instant
  out2dRadFlx@LW_d           = True      ;LW flux - downward - sfc - instant
  out2dRadFlx@SW_u           = True      ;SW flux - upward - sfc - instant
  out2dRadFlx@LW_u           = True      ;LW flux - upward - sfc - instant
  out2dRadFlx@LW_u_toa       = False     ;LW flux - upward - TOA - instant
  out2dRadFlx@SW_d_acc       = False      ;SW flux - downward - sfc - accum.
  out2dRadFlx@LW_d_acc       = False      ;LW flux - downward - sfc - accum.
  out2dRadFlx@SW_u_acc       = False      ;SW flux - upward - sfc - accum.
  out2dRadFlx@LW_u_acc       = False      ;LW flux - upward - sfc - accum.
  out2dRadFlx@SW_d_toa_acc   = False      ;SW flux - downward - TOA - accum.
  out2dRadFlx@LW_d_toa_acc   = False      ;LW flux - downward - TOA - accum.
  out2dRadFlx@SW_u_toa_acc   = False      ;SW flux - upward - TOA - accum.
  out2dRadFlx@LW_u_toa_acc   = False      ;LW flux - upward - TOA - accum.
  out2dRadFlx@albedo         = False      ;surface albedo
  out2dRadFlx@emiss_sfc      = False      ;surface emissivity
  out2dRadFlx@SH             = False      ;SH flux - upward - sfc - instant
  out2dRadFlx@LH             = False      ;LH flux - upward - sfc - instant
  out2dRadFlx@SH_acc         = False      ;SH flux - upward - sfc - accum.
  out2dRadFlx@LH_acc         = False      ;LH flux - upward - sfc - accum.
  out2dRadFlx@MH             = False      ;moisture heat flux - upward - sfc.
  out2dRadFlx@u_star         = False      ;friction velocity (u*)
  out2dRadFlx@LWP            = False      ;cloud liquid water path
  out2dRadFlx@IWP            = False      ;cloud ice water path
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; two-dimensional surface/soil variables
  out2dLandSoil              = True
  out2dLandSoil@LandMask     = False      ;land mask (1 - land, 0 - water)
  out2dLandSoil@LandUse      = False      ;land use category
  out2dLandSoil@SoilT_L      = False      ;soil temperature at lower boundary
  out2dLandSoil@SoilT_B      = False      ;bottom soil temperature
  out2dLandSoil@GroundFlx    = False      ;ground heat flux
  out2dLandSoil@SnowHgt      = False      ;snow depth
  out2dLandSoil@SnowWater    = False      ;snow water equivalent
  out2dLandSoil@SnowDens     = False      ;snow density
  out2dLandSoil@SnowFlx      = False      ;snow phase change heat flux
  out2dLandSoil@SnowMelt     = False      ;melted snow; accumulated
  out2dLandSoil@SeaIce       = False      ;sea ice flag
  out2dLandSoil@WaterFlx     = False      ;surface evaporation
  out2dLandSoil@SfcRunoff    = False      ;surface runoff flux
  out2dLandSoil@SubRunoff    = False      ;subsurface runoff flux
  out2dLandSoil@SoilMoist    = False      ;total soil moisture content
  out2dLandSoil@AOD470_sfc   = False       ; AOD at 470nm at the surface
  out2dLandSoil@AOD550_sfc   = True       ; AOD at 550nm at the surface
  out2dLandSoil@AOD675_sfc   = False       ; AOD at 675nm at the surface
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; three-dimensional soil variables
  outSoil                    = False
  outSoil@SoilTemp           = False      ;temperature - soil
  outSoil@SoilMoist          = False      ;moisture - soil
  outSoil@SoilWater          = False      ;water - soil
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; two-dimensional CLimate WRF (CLWRF) variables
  ;  (http://www.meteo.unican.es/en/software/clwrf)
  ; -The CLWRF variables are activated by compiler flags within configiure.wrf.
  ; -The variables are outputted to auxiliary history output file(s).
  outCLWRF                   = False
  outCLWRF@T_sfc_min         = False      ;temperature at sfc - min.
  outCLWRF@T_sfc_max         = False      ;temperature at sfc - max.
  outCLWRF@T_sfc_mean        = False      ;temperature at sfc - mean
  outCLWRF@T_sfc_std         = False      ;temperature at sfc - std. dev.
  outCLWRF@T_2m_min          = False      ;temperature at 2 m - min.
  outCLWRF@T_2m_max          = False      ;temperature at 2 m - max.
  outCLWRF@T_2m_mean         = False      ;temperature at 2 m - mean
  outCLWRF@T_2m_std          = False      ;temperature at 2 m - std. dev.
  outCLWRF@r_v_2m_min        = False      ;mixing ratio at 2 m - min.
  outCLWRF@r_v_2m_max        = False      ;mixing ratio at 2 m - max.
  outCLWRF@r_v_2m_mean       = False      ;mixing ratio at 2 m - mean
  outCLWRF@r_v_2m_std        = False      ;mixing ratio at 2 m - std. dev.
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; open the input netcdf file (wrfout file)
  wrfout = addfile(dir_in+file_in+".nc","r")
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; time coordinate
  ; -the time in wrfout is in an odd character format
  TimeChar = wrfout->Times 
  ; -determine the number of dimensions for time
  DimTimeChar = dimsizes(TimeChar)
  nTime = DimTimeChar(0)
  ; -convert the wrfout time to a CF compliant time
  ;  "hours since 1901-01-01 00:00:00"
  time_in = wrf_times_c(TimeChar, 1) 
  ; -create an array indicating the year, month, day, hour, minute, second
  utc_date = floattoint(ut_calendar(time_in, 0))
  ; -create the final variable for time with the units selected
  time = (/ut_inv_calendar(utc_date(:,0), utc_date(:,1), utc_date(:,2),  \
                          utc_date(:,3), utc_date(:,4), utc_date(:,5),  \
                          TimeUnits, 0)/)  ;time
    time@long_name = "Time"
    time@standard_name = "time"
    time@units = TimeUnits
    time@calendar = "standard"
    time!0 = "time"
    time&time = time
  utc_date!0 = "time"                  ;utc_date
    utc_date&time = time
  year = utc_date(:,0)
    year@long_name = "Year"
    year!0 = "time"
    year&time = time
  month = utc_date(:,1)
    month@long_name = "Month"
    month!0 = "time"
    month&time = time
  day = utc_date(:,2)
    day@long_name = "Day"
    day!0 = "time"
    day&time = time
  hour = utc_date(:,3)
    hour@long_name = "Hour"
    hour!0 = "time"
    hour&time = time
  minute = utc_date(:,4)
    minute@long_name = "Minutes"
    minute!0 = "time"
    minute&time = time
  ; -convert the wrfout time to a DateTime integer for easy reading
  if (outDateTime) then
    DateTime = (/wrf_times_c(TimeChar, 3)/) ;time
      DateTime@long_name = "Date and Time"
      DateTime!0   = "time"
      DateTime&time = time
  end if
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; vertical variables / coordinates
  ; Note:  pressure levels are assigned in the beginning section
  if (outPressure) then
    nPressure = dimsizes(pressure)       ;pressure vertical coordinate
      pressure@long_name = "Pressure Levels"
      pressure@standard_name = "air_pressure"
      pressure@units = "hPa"
      pressure@positive = "down"
      pressure!0 = "pressure"
      pressure&pressure = pressure
  end if
  if (outEta .or. outPressure)
    eta = (/wrfout->ZNU(0,:)/)           ;eta values on half-levels (mass)
      nEta = dimsizes(eta)
      eta@long_name = "Eta Levels (mass points)"
      eta@standard_name = "atmosphere_sigma_coordinate"
      eta@units = "1"
      eta@positive = "down"
      eta@formula_terms = "sigma: eta ps: p_sfc ptop: p_top"
      eta!0 = "eta"
      eta&eta = eta
  end if
  if (outSoil) then
    soil = (/wrfout->ZS(0,:)/)           ;depths of center of soil layers
      nSoil = dimsizes(soil)
      soil@long_name = "Soil Levels (depth)"
      soil@standard_name = "depth"
      soil@units = "m"
      soil@positive = "down"
      soil!0 = "soil"
      soil&soil = soil
  end if
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; one-dimensional general model variables
  if (outPtop .or. outEta) then
    p_top_in = (/wrfout->P_TOP/)/100.    ;pressure at top of model
    ;in some files P_TOP has two dimensions, in some it has one dimension
    if ((dimsizes(dimsizes(p_top_in))) .eq. 2) then
      p_top = p_top_in(0,0)
    else
      p_top = p_top_in(0)
    end if
    p_top@long_name = "Pressure at Top of the Model"
    p_top@standard_name = "air_pressure"
    p_top@units = "hPa"
  end if
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; two-dimensional mapping variables
  lat = (/wrfout->XLAT(0,:,:)/)        ;lat (mass)
    DimLat = dimsizes(lat)
    nS_N = DimLat(0)           ;S_N dimension
    nW_E = DimLat(1)           ;W_E dimension
    lat@long_name = "Latitude"
    lat@standard_name = "latitude"
    lat@units = "degrees_north"
    lat!0 = "south_north"
    lat!1 = "west_east"
  lon = (/wrfout->XLONG(0,:,:)/)       ;lon (mass)
    lon@long_name = "Longitude"
    lon@standard_name = "longitude"
    lon@units = "degrees_east"
    lon!0 = "south_north"
    lon!1 = "west_east"
  Z_sfc = (/wrfout->HGT(0,:,:)/)       ;Z_sfc
    Z_sfc@long_name = "Terrain Height"
    Z_sfc@standard_name = "height"
    Z_sfc@units = "m"
    Z_sfc@coordinates = "lon lat"
    Z_sfc!0 = "south_north"
    Z_sfc!1 = "west_east"
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; one-dimensional coordinate system
  if (axis) then
    south_north = ispan(0,nS_N-1,1)      ;south_north
      south_north@long_name = "y-coordinate in Cartesian system"
      south_north@axis = "Y"
      south_north@units = "m"
      south_north!0 = "south_north"
    west_east = ispan(0,nW_E-1,1)        ;west_east
      west_east@long_name = "x-coordinate in Cartesian system"
      west_east@axis = "X"
      west_east@units = "m"
      west_east!0 = "west_east"
  end if
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; two-dimensional near-surface / surface met variables
  ;   -retrieved directly from the wrfout file - or
  ;   -derived/diagnostic fields using wrf_user_getvar
  if (out2dMet) then
    if (out2dMet@SST) then
      SST = (/wrfout->SST/)                                        ;SST
        SST@long_name = "Sea-Surface Temperature"
        SST@standard_name = "sea_surface_temperature"
        SST@units = "K"
        assignVarAttCoord(SST,time,0,0)
    end if
    if (out2dMet@T_sfc) then
      T_sfc = (/wrfout->TSK/)                                      ;T_sfc
        T_sfc@long_name = "Temperature at the Surface"
        T_sfc@standard_name = "surface_temperature"
        T_sfc@units = "K"
        assignVarAttCoord(T_sfc,time,0,0)
    end if
    if (out2dMet@p_sfc) then
      p_sfc = (/wrfout->PSFC/)/100.                                ;p_sfc
        p_sfc@long_name = "Pressure at the Surface"
        p_sfc@standard_name = "surface_air_pressure"
        p_sfc@units = "hPa"
        assignVarAttCoord(p_sfc,time,0,0)
    end if
    if (out2dMet@slp) then                                         ;slp
      slp = (/wrf_user_getvar(wrfout,"slp",-1)/)
        slp@long_name = "Sea-Level Pressure"
        slp@standard_name = "air_pressure_at_sea_level"
        slp@units = "hPa"
        assignVarAttCoord(slp,time,0,0)
    end if
    if (out2dMet@T_2m) then
      T_2m = (/wrfout->T2/) - 273.15                               ;T_2m
        T_2m@long_name = "Temperature at 2 m"
        T_2m@standard_name = "air_temperature"
        T_2m@units = "degC"
        assignVarAttCoord(T_2m,time,0,0)
    end if
    if (out2dMet@theta_2m) then
      theta_2m = (/wrfout->TH2/)                                   ;theta_2m
        theta_2m@long_name = "Potential Temperature at 2 m"
        theta_2m@standard_name = "air_potential_temperature"
        theta_2m@units = "K"
        assignVarAttCoord(theta_2m,time,0,0)
    end if    
    if (out2dMet@Td_2m) then                                       ;Td_2m 
      Td_2m = (/wrf_user_getvar(wrfout,"td2",-1)/)
        Td_2m@long_name = "Dewpoint Temperature at 2 m"
        Td_2m@standard_name = "dew_point_temperature"
        Td_2m@units = "degC"
        assignVarAttCoord(Td_2m,time,0,0)     
    end if
    if (out2dMet@r_v_2m .or. out2dMet@q_2m) then
      r_v_2m = (/wrfout->Q2/)                                      ;r_v_2m
        r_v_2m@long_name = "Water Vapor Mixing Ratio at 2 m"
        r_v_2m@standard_name = "humidity_mixing_ratio"
        r_v_2m@units = "kg kg-1"
        assignVarAttCoord(r_v_2m,time,0,0)
      if (out2dMet@q_2m)
        q_2m = r_v_2m / (1 + r_v_2m)                               ; q_2m
        q_2m@long_name = "Specific Humidity at 2 m"
        q_2m@standard_name = "specific_humidity"
        q_2m@units = "kg kg-1"
        assignVarAttCoord(q_2m,time,0,0)
      end if
    end if
    if (out2dMet@rh_2m) then                                       ;rh_2m
      rh_2m = (/wrf_user_getvar(wrfout,"rh_2m",-1)/)
        rh_2m@long_name = "Relative Humidity at 2 m"
        rh_2m@standard_name = "relative_humidity"
        rh_2m@units = "percent"
        assignVarAttCoord(rh_2m,time,0,0)
    end if
    if (out2dMet@u_10m_gr) then
      u_10m_gr = (/wrfout->U10/)                                   ;u_10m_gr
        u_10m_gr@long_name = "u-Component of Wind at 10 m (grid)"
        u_10m_gr@standard_name = "eastward_wind"
        u_10m_gr@units = "m s-1"
        assignVarAttCoord(u_10m_gr,time,0,0)
    end if
    if (out2dMet@v_10m_gr) then
      v_10m_gr = (/wrfout->V10/)                                   ;v_10m_gr
        v_10m_gr@long_name = "v-Component of Wind at 10 m (grid)"
        v_10m_gr@standard_name = "northward_wind"
        v_10m_gr@units = "m s-1"
        assignVarAttCoord(v_10m_gr,time,0,0)
    end if
    ; - values for u_10m_tr, v_10m_tr, ws_10m, and/or wd_10m
    if (out2dMet@u_10m_tr .or. out2dMet@v_10m_tr .or.   \
        out2dMet@ws_10m .or. out2dMet@wd_10m) then
      uv_10m_tr = (/wrf_user_getvar(wrfout,"uvmet10",-1)/)
      u_10m_tr = (/uv_10m_tr(0,:,:,:)/)                            ;u_10m_tr
        u_10m_tr@long_name     = "u-Component of wind at 10 m (Earth)"
        u_10m_tr@standard_name = "eastward_wind"
        u_10m_tr@units         = "m s-1"
        assignVarAttCoord(u_10m_tr,time,0,0)
      v_10m_tr = (/uv_10m_tr(1,:,:,:)/)                            ;v_10m_tr
        v_10m_tr@long_name     = "v-Component of wind at 10 m (Earth)"
        v_10m_tr@standard_name = "northward_wind"
        v_10m_tr@units         = "m s-1"
        assignVarAttCoord(v_10m_tr,time,0,0)
      if (out2dMet@ws_10m)
        ws_10m = sqrt(u_10m_tr^2 + v_10m_tr^2)                     ;ws_10m
          ws_10m@long_name = "Wind Speed at 10 m"
          ws_10m@standard_name = "wind_speed"
          ws_10m@units = "m s-1"
          assignVarAttCoord(ws_10m,time,0,0)
      end if
      if (out2dMet@wd_10m)                                         ;wd_10m
        r2d = 45.0/atan(1.0)
        wd_10m = atan2(u_10m_tr, v_10m_tr) * r2d + 180.
          wd_10m@long_name = "Wind Direction at 10 m"
          wd_10m@standard_name = "wind_from_direction"
          wd_10m@units = "degree"
          assignVarAttCoord(wd_10m,time,0,0)
      end if
    end if
    if (out2dMet@precip_g) then
      precip_g = (/wrfout->RAINNC/)                                ;precip_g
        precip_g@long_name = "Accumulated Total Grid Scale Precipitation"
        precip_g@standard_name = "large_scale_precipitation_amount"
        precip_g@units = "mm"
        assignVarAttCoord(precip_g,time,0,0)
    end if
    if (out2dMet@precip_c) then
      precip_c = (/wrfout->RAINC/)                                 ;precip_c
        precip_c@long_name = "Accumulated Total Cumulus Precipitation"
        precip_c@standard_name = "convective_precipitation_amount"
        precip_c@units = "mm"
        assignVarAttCoord(precip_c,time,0,0)
    end if
    if (out2dMet@precip_fr) then
      precip_fr = (/wrfout->SR/)                                   ;precip_fr
      precip_fr@long_name = "Fraction of Frozen Non-convective Precipitation"
      precip_fr@standard_name = ""
      precip_fr@units = "1"
      assignVarAttCoord(precip_fr,time,0,0)
    end if
    if (out2dMet@dryairmass) then
      dryairmass = ((/wrfout->MU/)+(/wrfout->MUB/))/100.           ;dryairmass
      dryairmass@long_name = "Total Dry Air Mass in Column"
      dryairmass@standard_name = ""
      dryairmass@units = "hPa"
      assignVarAttCoord(dryairmass,time,0,0)
    end if
    if (out2dMet@pblh) then
      pblh = (/wrfout->PBLH/)                                      ;pblh
      pblh@long_name = "PBL Height"
      pblh@standard_name = "atmosphere_boundary_layer_thickness"
      pblh@units = "m"
      assignVarAttCoord(pblh,time,0,0)
    end if
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; two-dimensional near-surface / surface met variables (calculated)
    if (out2dMet@slp_b .or. out2dMet@rho) then
      ; Note: This is an alternative method to calculate slp based on 
      ;       the temperature, moisture, and height of the lowest model level.
      ;       There is no certainty that this is any better, and possibly 
      ;       worse than what is used in slp.
      ; -create the variable
      slp_b = new((/nTime,nS_N,nW_E/), double, "No_FillValue")    ;slp
      rho   = new((/nTime,nS_N,nW_E/), double, "No_FillValue")    ;rho
      ; -loop through the nTimes
      do n = 0, nTime-1
        ; -create new variables for what is needed to calculate slp
        T_eta = new((/nEta,nS_N,nW_E/), double, "No_FillValue")
        r_v_eta = new((/nEta,nS_N,nW_E/), double, "No_FillValue")
        p_eta = new((/nEta,nS_N,nW_E/), double, "No_FillValue")
        Z_eta = new((/nEta,nS_N,nW_E/), double, "No_FillValue")
        temp_v = new((/nS_N,nW_E/), double, "No_FillValue")
        ; -read in the values needed for calculations
        T_eta = (/wrf_user_getvar(wrfout,"tk",n)/)
        p_eta = (/wrf_user_getvar(wrfout,"pressure",n)/)
        Z_eta = (/wrf_user_getvar(wrfout,"z",n)/)
        r_v_eta = (/wrfout->QVAPOR(n,:,:,:)/)
        ; -calculate the virtual temperature
        temp_v = (1.+(0.622*r_v_eta(0,:,:)))*T_eta(0,:,:)
        ; -calculate the sea-level pressure using the virtual temperature of
        ;  the lowest model level
        slp_b(n,:,:) = p_eta(0,:,:)*exp((9.81*Z_eta(0,:,:))/(287.*temp_v))
        rho(n,:,:)   = p_eta(0,:,:)*100. / (287.*temp_v) 
        ; -multiply p_eta by 100 as p_eta is in hPa
      end do
      ; -set the attributes
      slp_b@long_name = "Sea-Level Pressure"
        slp_b@standard_name = "air_pressure_at_sea_level"
        slp_b@units = "hPa"
        assignVarAttCoord(slp_b,time,0,0)      ;slp
      rho@long_name = "Air Density at Lowest Model Level"
        rho@standard_name = "air_density"
        rho@units = "kg m-3"
        assignVarAttCoord(rho,time,0,0)      ;slp
    end if
  end if
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; three-dimensional upper-level (eta) metorology variables
  ;   -retrieved directly from the wrfout file - or
  ;   -derived/diagnostic fields using wrf_user_getvar
  if (outEta .or. outPressure)
;    if (outEta@p_e .or. outPressure) then
;      p_e = (/wrf_user_getvar(wrfout,"pres",-1)/)              ;p_e
;        p_e@long_name = "Pressure"
;        p_e@standard_name = "air_pressure"
;        p_e@units = "hPa"
;        assignVarAttCoord(p_e,time,eta,2)
;    end if
    if (outEta@Z_e .or. outPressure@Z_p) then
      Z_e = (/wrf_user_getvar(wrfout,"z",-1)/)                     ;Z_e
        Z_e@long_name = "Geopotential Height"
        Z_e@standard_name = "geopotential_height"
        Z_e@units = "m"
        assignVarAttCoord(Z_e,time,eta,2)
    end if
    if (outEta@T_e .or. outPressure@T_p) then
      T_e = (/wrf_user_getvar(wrfout,"tk",-1)/)                     ;T_e
        T_e@long_name = "Temperature"
        T_e@standard_name = "air_temperature"
        T_e@units = "K"
        assignVarAttCoord(T_e,time,eta,2)
    end if
    if (outEta@theta_e .or. outPressure@theta_p) then
      theta_e = (/wrf_user_getvar(wrfout,"th",-1)/)                ;theta_e
        theta_e@long_name = "Potential Temperature"
        theta_e@standard_name = "air_potential_temperature"
        theta_e@units = "K"
        assignVarAttCoord(theta_e,time,eta,2)
    end if
    if (outEta@Td_e .or. outPressure@Td_p) then
      Td_e = (/wrf_user_getvar(wrfout,"td",-1)/)                   ;Td_e
        Td_e@long_name = "Dewpoint Temperature"
        Td_e@standard_name = "dew_point_temperature"
        Td_e@units = "degC"
        assignVarAttCoord(Td_e,time,eta,2)
    end if
    ; mixing ratio and specific humidity both come from mixing ratio
;    if (outEta@r_v_e .or. outPressure@r_v_p .or.  \
;        outEta@q_e .or. outPressure@q_e) then
;      r_v_e = (/wrfout->QVAPOR/)                                   ;r_v_e
;        r_v_e@long_name = "Mixing Ratio - Water Vapor"
;        r_v_e@standard_name = "humidity_mixing_ratio"
;        r_v_e@units = "kg kg-1"
;        assignVarAttCoord(r_v_e,time,eta,2)
;      if (outEta@q_e .or. outPressure@q_p) then
;        q_e = r_v_e / (1 + r_v_e)                                  ;q_e
;          q_e@long_name     = "Specific Humidity"
;          q_e@standard_name = "specific_humidity"
;          q_e@units         = "kg kg-1"
;          assignVarAttCoord(q_e,time,eta,2)
;      end if   
;    end if
    if (outEta@rh_e .or. outPressure@rh_p) then
      rh_e = (/wrf_user_getvar(wrfout,"rh_2m",-1)/)                   ;rh_e
        rh_e@long_name = "Relative Humidity"
        rh_e@standard_name = "relative_humidity"
        rh_e@units = "percent"
        assignVarAttCoord(rh_e,time,eta,2)
    end if
    if (outEta@u_gr_e .or. outPressure@u_gr_p) then
      u_gr_e = (/wrf_user_getvar(wrfout,"ua",-1)/)                 ;u_gr_e
        u_gr_e@long_name = "u-Component of Wind (grid)"
        u_gr_e@standard_name = "eastward_wind"
        u_gr_e@units = "m s-1"
        assignVarAttCoord(u_gr_e,time,eta,2)
    end if
    if (outEta@v_gr_e .or. outPressure@v_gr_p) then
      v_gr_e = (/wrf_user_getvar(wrfout,"va",-1)/)                 ;v_gr_e
        v_gr_e@long_name = "v-Component of Wind (grid)"
        v_gr_e@standard_name = "northward_wind"
        v_gr_e@units = "m s-1"
        assignVarAttCoord(v_gr_e,time,eta,2)
    end if
    ; the wind is handled as a single variable for u and v, read for all
    if (outEta@u_tr_e .or. outPressure@u_tr_p .or.  \    
        outEta@v_tr_e .or. outPressure@v_tr_p .or.  \
        outEta@ws_e .or. outPressure@ws_p .or.  \
        outEta@wd_e .or. outPressure@wd_p) then
      uv_tr_e = (/wrf_user_getvar(wrfout,"uvmet",-1)/)           ;u_tr and v_tr
      u_tr_e = uv_tr_e(0,:,:,:,:)                                  ;u_tr_e
        u_tr_e@long_name     = "u-Component of Wind (Earth)"
        u_tr_e@standard_name = "eastward_wind"
        u_tr_e@units         = "m s-1"
        assignVarAttCoord(u_tr_e,time,eta,2)
      v_tr_e = uv_tr_e(1,:,:,:,:)                                  ;v_tr_e
        v_tr_e@long_name     = "v-Component of Wind (Earth)"
        v_tr_e@standard_name = "northward_wind"
        v_tr_e@units         = "m s-1"
        assignVarAttCoord(v_tr_e,time,eta,2)
      if (outEta@ws_e)
        ws_e = sqrt(u_tr_e^2 + v_tr_e^2)                           ;ws_e
          ws_e@long_name = "Wind Speed"
          ws_e@standard_name = "wind_speed"
          ws_e@units = "m s-1"
          assignVarAttCoord(ws_e,time,0,0)
      end if
      if (outEta@wd_e)
        r2d = 45.0/atan(1.0)                                       ;wd_e
 	    wd_e = atan2(u_tr_e, v_tr_e) * r2d + 180.
          wd_e@long_name = "Wind Direction"
          wd_e@standard_name = "wind_from_direction"
          wd_e@units = "degree"
          assignVarAttCoord(wd_e,time,0,0)
      end if
    end if
    if (outEta@w_e .or. outPressure@w_p) then
      w_e =(/wrf_user_getvar(wrfout,"wa",-1)/)                     ;w_e
        w_e@long_name = "w-Component of Wind"
        w_e@standard_name = "upward_wind"
        w_e@units = "m s-1"
        assignVarAttCoord(w_e,time,eta,2)
    end if
    if (outEta@pp_e .or. outPressure@pp_p) then
      pp_e = (/wrfout->P/)/100.                                    ;pp_e
        pp_e@long_name = "Pressure Perturbation"
        pp_e@standard_name = ""
        pp_e@units = "hPa"
        assignVarAttCoord(pp_e,time,eta,2)
    end if
    if (outEta@r_cloud .or. outPressure@r_cloud_p) then
      r_cloud = (/wrfout->QCLOUD/)                                 ;r_cloud
        r_cloud@long_name = "Mixing Ratio - Cloud"
        r_cloud@standard_name = "mass_fraction_of_cloud_condensed_water_in_air"
        r_cloud@units = "kg kg-1"
        assignVarAttCoord(r_cloud,time,eta,2)
    end if
    if (outEta@r_rain .or. outPressure@r_rain_p) then
      r_rain = (/wrfout->QRAIN/)                                   ;r_rain
        r_rain@long_name = "Mixing Ratio - Rain"
        r_rain@standard_name = "mass_fraction_of_rain_in_air"
        r_rain@units = "kg kg-1"
        assignVarAttCoord(r_rain,time,eta,2)
    end if
    if ((outEta@r_ice .or. outPressure@r_ice_p) .and.  \
         isfilevar(wrfout, "QICE")) then
      r_ice = (/wrfout->QICE/)                                     ;r_ice
        r_ice@long_name = "Mixing Ratio - Ice"
        r_ice@standard_name = "mass_fraction_of_ice_in_air"
        r_ice@units = "kg kg-1"
        assignVarAttCoord(r_ice,time,eta,2)
    end if
    if ((outEta@r_snow .or. outPressure@r_snow_p) .and.  \
         isfilevar(wrfout, "QSNOW")) then
      r_snow = (/wrfout->QSNOW/)                                   ;r_snow
        r_snow@long_name = "Mixing Ratio - Snow"
        r_snow@standard_name = "mass_fraction_of_snow_in_air"
        r_snow@units = "kg kg-1"
        assignVarAttCoord(r_snow,time,eta,2)
    end if
    if ((outEta@r_graup .or. outPressure@r_graup_p) .and.  \
         isfilevar(wrfout, "QGRAUP")) then
      r_graup = (/wrfout->QGRAUP/)                                 ;r_graupel
        r_graup@long_name = "Mixing Ratio - Graupel"
        r_graup@standard_name = "mass_fraction_of_graupel_in_air"
        r_graup@units = "kg kg-1"
        assignVarAttCoord(r_graup,time,eta,2)
    end if
    if (outEta@pvo_e .or. outPressure@pvo_p) then
      pvo_e = (/wrf_user_getvar(wrfout,"pvo",-1)/)                 ;pvo_e
        pvo_e@long_name = "Potential Vorticity"
        pvo_e@standard_name = "potential_vorticity_of_atmosphere_layer"
        pvo_e@units = "PVU"
        assignVarAttCoord(pvo_e,time,eta,2)
    end if
    if (outEta@avo_e .or. outPressure@avo_p) then
      avo_e = (/wrf_user_getvar(wrfout,"avo",-1)/)                 ;avo_e
        avo_e@long_name = "Absolute Vorticity"
        avo_e@standard_name = "atmosphere_absolute_vorticity"
        avo_e@units = "s-1"
        assignVarAttCoord(avo_e,time,eta,2)
    end if
    if (outEta@o3_e .or. outPressure@avo_p) then
      o3_e = (/wrf_user_getvar(wrfout,"o3",-1)/)                 ;o3_e
        o3_e@long_name = "o3 mixing ratio"
        o3_e@standard_name = "o3"
        o3_e@units = "ppmv"
        assignVarAttCoord(o3_e,time,eta,2)
    end if
    if (outEta@AOD470_e) then
      AOD470_e = (/wrf_user_getvar(wrfout,"AOD470",-1)/)             ;AOD470
        AOD470_e@long_name = "Aerosol Optical Depth at 470nm"
        AOD470_e@standard_name = "AOD470"
        AOD470_e@units = "km-1"
        assignVarAttCoord(AOD470_e,time,eta,2)
    end if                                                         ;AOD550
    if (outEta@AOD550_e) then
      AOD550_e = (/wrf_user_getvar(wrfout,"AOD550",-1)/)
        AOD550_e@long_name = "Aerosol Optical Depth at 550nm"
        AOD550_e@standard_name = "AOD550"
        AOD550_e@units = "km-1"
        assignVarAttCoord(AOD550_e,time,eta,2)
    end if                                                         ;AOD675
    if (outEta@AOD675_e) then
      AOD675_e = (/wrf_user_getvar(wrfout,"AOD675",-1)/)
        AOD675_e@long_name = "Aerosol Optical Depth at 675nm"
        AOD675_e@standard_name = "AOD675"
        AOD675_e@units = "km-1"
        assignVarAttCoord(AOD675_e,time,eta,2)
    end if                                                         ;PM2_5_DRY
    if (outEta@PM2_5_DRY_e) then
      PM2_5_DRY_e = (/wrf_user_getvar(wrfout,"PM2_5_DRY",-1)/)
        PM2_5_DRY_e@long_name = "PM2.5 aerosol dry mass"
        PM2_5_DRY_e@standard_name = "PM2_5_DRY"
        PM2_5_DRY_e@units = "ug m^-3"
        assignVarAttCoord(PM2_5_DRY_e,time,eta,2)
    end if                                                         ;PM10
    if (outEta@PM10_e) then
      PM10_e = (/wrf_user_getvar(wrfout,"PM10",-1)/)
        PM10_e@long_name = "PM10 aerosol dry mass"
        PM10_e@standard_name = "PM10"
        PM10_e@units = "ug m^-3"
        assignVarAttCoord(PM10_e,time,eta,2)
    end if                                                         ;o3
    if (outEta@co_e) then
      co_e = (/wrf_user_getvar(wrfout,"co",-1)/)
        co_e@long_name = "co Mixing Ratio"
        co_e@standard_name = "co"
        co_e@units = "ppmv"
        assignVarAttCoord(co_e,time,eta,2)
    end if
    if (outEta@no2_e) then
      no2_e = (/wrf_user_getvar(wrfout,"no2",-1)/)
        no2_e@long_name = "no2 Mixing Ratio"
        no2_e@standard_name = "no2"
        no2_e@units = "ppmv"
        assignVarAttCoord(no2_e,time,eta,2)
    end if
    if (outEta@so2_e) then
      so2_e = (/wrf_user_getvar(wrfout,"so2",-1)/)
        so2_e@long_name = "so2 Mixing Ratio"
        so2_e@standard_name = "so2"
        so2_e@units = "ppmv"
        assignVarAttCoord(so2_e,time,eta,2)
    end if                                                                       ;bc_a01
    if (outEta@bc_a01_e) then
      bc_a01_e = (/wrf_user_getvar(wrfout,"bc_a01",-1)/)
        bc_a01_e@long_name = "Black carbon, aerosol bin 01"
        bc_a01_e@standard_name = "bc_a01"
        bc_a01_e@units = "ug/kg-dryair"
        assignVarAttCoord(bc_a01_e,time,eta,2)
    end if                                                         ;bc_a02
    if (outEta@bc_a02_e) then
      bc_a02_e = (/wrf_user_getvar(wrfout,"bc_a02",-1)/)
        bc_a02_e@long_name = "Black carbon, aerosol bin 02"
        bc_a02_e@standard_name = "bc_a02"
        bc_a02_e@units = "ug/kg-dryair"
        assignVarAttCoord(bc_a02_e,time,eta,2)
    end if                                                         ;bc_a03
    if (outEta@bc_a03_e) then
      bc_a03_e = (/wrf_user_getvar(wrfout,"bc_a03",-1)/)
        bc_a03_e@long_name = "Black carbon, aerosol bin 03"
        bc_a03_e@standard_name = "bc_a03"
        bc_a03_e@units = "ug/kg-dryair"
        assignVarAttCoord(bc_a03_e,time,eta,2)
    end if                                                         ;bc_a04
    if (outEta@bc_a04_e) then
      bc_a04_e = (/wrf_user_getvar(wrfout,"bc_a04",-1)/)
        bc_a04_e@long_name = "Black carbon, aerosol bin 04"
        bc_a04_e@standard_name = "bc_a04"
        bc_a04_e@units = "ug/kg-dryair"
        assignVarAttCoord(bc_a04_e,time,eta,2)
    end if                                                         ;oc_a01
    if (outEta@oc_a01_e) then
      oc_a01_e = (/wrf_user_getvar(wrfout,"oc_a01",-1)/)
        oc_a01_e@long_name = "Organic carbon, aerosol bin 01"
        oc_a01_e@standard_name = "oc_a01"
        oc_a01_e@units = "ug/kg-dryair"
        assignVarAttCoord(oc_a01_e,time,eta,2)
    end if                                                         ;oc_a02
    if (outEta@oc_a02_e) then
      oc_a02_e = (/wrf_user_getvar(wrfout,"oc_a02",-1)/)
        oc_a02_e@long_name = "Organic carbon, aerosol bin 02"
        oc_a02_e@standard_name = "oc_a02"
        oc_a02_e@units = "ug/kg-dryair"
        assignVarAttCoord(oc_a02_e,time,eta,2)
    end if                                                         ;oc_a03
    if (outEta@oc_a03_e) then
      oc_a03_e = (/wrf_user_getvar(wrfout,"oc_a03",-1)/)
        oc_a03_e@long_name = "Organic carbon, aerosol bin 03"
        oc_a03_e@standard_name = "oc_a03"
        oc_a03_e@units = "ug/kg-dryair"
        assignVarAttCoord(oc_a03_e,time,eta,2)
    end if                                                         ;oc_a04
    if (outEta@oc_a04_e) then
      oc_a04_e = (/wrf_user_getvar(wrfout,"oc_a04",-1)/)
        oc_a04_e@long_name = "Organic carbon, aerosol bin 04"
        oc_a04_e@standard_name = "oc_a04"
        oc_a04_e@units = "ug/kg-dryair"
        assignVarAttCoord(oc_a04_e,time,eta,2)
    end if                                                         ;num_a01
    if (outEta@num_a01_e) then
      num_a01_e = (/wrf_user_getvar(wrfout,"num_a01",-1)/)
        num_a01_e@long_name = "Number, aerosol bin 01"
        num_a01_e@standard_name = "num_a01"
        num_a01_e@units = "/kg-dryair"
        assignVarAttCoord(num_a01_e,time,eta,2)
    end if                                                         ;num_a02
    if (outEta@num_a02_e) then
      num_a02_e = (/wrf_user_getvar(wrfout,"num_a02",-1)/)
        num_a02_e@long_name = "Number, aerosol bin 02"
        num_a02_e@standard_name = "num_a02"
        num_a02_e@units = "/kg-dryair"
        assignVarAttCoord(num_a02_e,time,eta,1)
    end if                                                         ;num_a03
    if (outEta@num_a03_e) then
      num_a03_e = (/wrf_user_getvar(wrfout,"num_a03",-1)/)
        num_a03_e@long_name = "Number, aerosol bin 03"
        num_a03_e@standard_name = "num_a03"
        num_a03_e@units = "/kg-dryair"
        assignVarAttCoord(num_a03_e,time,eta,2)
    end if                                                         ;num_a04
    if (outEta@num_a04_e) then
      num_a04_e = (/wrf_user_getvar(wrfout,"num_a04",-1)/)
        num_a04_e@long_name = "Number, aerosol bin 01"
        num_a04_e@standard_name = "num_a04"
        num_a04_e@units = "/kg-dryair"
        assignVarAttCoord(num_a04_e,time,eta,2)
    end if
    if (outEta@water_a01_e) then
      water_a01_e = (/wrf_user_getvar(wrfout,"water_a01",-1)/)
        water_a01_e@long_name = "Water, aerosol bin 02"
        water_a01_e@standard_name = "water_a01"
        water_a01_e@units = "/kg-dryair"
        assignVarAttCoord(water_a01_e,time,eta,2)
    end if
    if (outEta@water_a02_e) then
      water_a02_e = (/wrf_user_getvar(wrfout,"water_a02",-1)/)
        water_a02_e@long_name = "Water, aerosol bin 03"
        water_a02_e@standard_name = "water_a02"
        water_a02_e@units = "/kg-dryair"
        assignVarAttCoord(water_a02_e,time,eta,2)
    end if
    if (outEta@water_a03_e) then
      water_a03_e = (/wrf_user_getvar(wrfout,"water_a03",-1)/)
        water_a03_e@long_name = "Water, aerosol bin 03"
        water_a03_e@standard_name = "water_a03"
        water_a03_e@units = "/kg-dryair"
        assignVarAttCoord(water_a03_e,time,eta,2)
    end if
    if (outEta@water_a04_e) then
      water_a04_e = (/wrf_user_getvar(wrfout,"water_a04",-1)/)
        water_a04_e@long_name = "Water, aerosol bin 04"
        water_a04_e@standard_name = "water_a04"
        water_a04_e@units = "/kg-dryair"
        assignVarAttCoord(water_a04_e,time,eta,2)
    end if
    if (outEta@so4_a01_e) then
      so4_a01_e = (/wrf_user_getvar(wrfout,"so4_a01",-1)/)
        so4_a01_e@long_name = "Sulphate, aerosol bin 01"
        so4_a01_e@standard_name = "so4_a01"
        so4_a01_e@units = "ug/kg-dryair"
        assignVarAttCoord(so4_a01_e,time,eta,2)
    end if
    if (outEta@so4_a02_e) then
      so4_a02_e = (/wrf_user_getvar(wrfout,"so4_a02",-1)/)
        so4_a02_e@long_name = "Sulphate, aerosol bin 02"
        so4_a02_e@standard_name = "so4_a02"
        so4_a02_e@units = "ug/kg-dryair"
        assignVarAttCoord(so4_a02_e,time,eta,2)
    end if
    if (outEta@so4_a03_e) then
      so4_a03_e = (/wrf_user_getvar(wrfout,"so4_a03",-1)/)
        so4_a03_e@long_name = "Sulphate, aerosol bin 03"
        so4_a03_e@standard_name = "so4_a03"
        so4_a03_e@units = "ug/kg-dryair"
        assignVarAttCoord(so4_a03_e,time,eta,2)
    end if
    if (outEta@so4_a04_e) then
      so4_a04_e = (/wrf_user_getvar(wrfout,"so4_a04",-1)/)
        so4_a04_e@long_name = "Sulphate, aerosol bin 04"
        so4_a04_e@standard_name = "so4_a04"
        so4_a04_e@units = "ug/kg-dryair"
        assignVarAttCoord(so4_a04_e,time,eta,2)
    end if
    if (outEta@no3_a01_e) then
      no3_a01_e = (/wrf_user_getvar(wrfout,"no3_a01",-1)/)
        no3_a01_e@long_name = "Nitrate, aerosol bin 01"
        no3_a01_e@standard_name = "no3_a01"
        no3_a01_e@units = "ug/kg-dryair"
        assignVarAttCoord(no3_a01_e,time,eta,2)
    end if
    if (outEta@no3_a02_e) then
      no3_a02_e = (/wrf_user_getvar(wrfout,"no3_a02",-1)/)
        no3_a02_e@long_name = "Nitrate, aerosol bin 02"
        no3_a02_e@standard_name = "no3_a02"
        no3_a02_e@units = "ug/kg-dryair"
        assignVarAttCoord(no3_a02_e,time,eta,2)
    end if
    if (outEta@no3_a03_e) then
      no3_a03_e = (/wrf_user_getvar(wrfout,"no3_a03",-1)/)
        no3_a03_e@long_name = "Nitrate, aerosol bin 03"
        no3_a03_e@standard_name = "no3_a03"
        no3_a03_e@units = "ug/kg-dryair"
        assignVarAttCoord(no3_a03_e,time,eta,2)
    end if
    if (outEta@no3_a04_e) then
      no3_a04_e = (/wrf_user_getvar(wrfout,"no3_a04",-1)/)
        no3_a04_e@long_name = "Nitrate, aerosol bin 04"
        no3_a04_e@standard_name = "no3_a04"
        no3_a04_e@units = "ug/kg-dryair"
        assignVarAttCoord(no3_a04_e,time,eta,2)
    end if
    if (outEta@nh4_a01_e) then
      nh4_a01_e = (/wrf_user_getvar(wrfout,"nh4_a01",-1)/)
        nh4_a01_e@long_name = "Ammonium, aerosol bin 01"
        nh4_a01_e@standard_name = "nh4_a01"
        nh4_a01_e@units = "ug/kg-dryair"
        assignVarAttCoord(nh4_a01_e,time,eta,2)
    end if
    if (outEta@nh4_a02_e) then
      nh4_a02_e = (/wrf_user_getvar(wrfout,"nh4_a02",-1)/)
        nh4_a02_e@long_name = "Ammonium, aerosol bin 02"
        nh4_a02_e@standard_name = "nh4_a02"
        nh4_a02_e@units = "ug/kg-dryair"
        assignVarAttCoord(nh4_a02_e,time,eta,2)
    end if
    if (outEta@nh4_a03_e) then
      nh4_a03_e = (/wrf_user_getvar(wrfout,"nh4_a03",-1)/)
        nh4_a03_e@long_name = "Ammonium, aerosol bin 03"
        nh4_a03_e@standard_name = "nh4_a03"
        nh4_a03_e@units = "ug/kg-dryair"
        assignVarAttCoord(nh4_a03_e,time,eta,2)
    end if
    if (outEta@nh4_a04_e) then
      nh4_a04_e = (/wrf_user_getvar(wrfout,"nh4_a04",-1)/)
        nh4_a04_e@long_name = "Ammonium, aerosol bin 04"
        nh4_a04_e@standard_name = "nh4_a04"
        nh4_a04_e@units = "ug/kg-dryair"
        assignVarAttCoord(nh4_a04_e,time,eta,2)
    end if
    if (outEta@asoaX_a01_e) then
      asoaX_a01_e = (/wrf_user_getvar(wrfout,"asoaX_a01",-1)/)
        asoaX_a01_e@long_name = "Simplified anthropogenic SOA, aerosol bin 01"
        asoaX_a01_e@standard_name = "asoaX_a01"
        asoaX_a01_e@units = "ug/kg-dryair"
        assignVarAttCoord(asoaX_a01_e,time,eta,2)
    end if
    if (outEta@asoaX_a02_e) then
      asoaX_a02_e = (/wrf_user_getvar(wrfout,"asoaX_a02",-1)/)
        asoaX_a02_e@long_name = "Simplified anthropogenic SOA, aerosol bin 02"
        asoaX_a02_e@standard_name = "asoaX_a02"
        asoaX_a02_e@units = "ug/kg-dryair"
        assignVarAttCoord(asoaX_a02_e,time,eta,2)
    end if
    if (outEta@asoaX_a03_e) then
      asoaX_a03_e = (/wrf_user_getvar(wrfout,"asoaX_a03",-1)/)
        asoaX_a03_e@long_name = "Simplified anthropogenic SOA, aerosol bin 03"
        asoaX_a03_e@standard_name = "asoaX_a03"
        asoaX_a03_e@units = "ug/kg-dryair"
        assignVarAttCoord(asoaX_a03_e,time,eta,2)
    end if
    if (outEta@asoaX_a04_e) then
      asoaX_a04_e = (/wrf_user_getvar(wrfout,"asoaX_a04",-1)/)
        asoaX_a04_e@long_name = "Simplified anthropogenic SOA, aerosol bin 04"
        asoaX_a04_e@standard_name = "asoaX_a04"
        asoaX_a04_e@units = "ug/kg-dryair"
        assignVarAttCoord(asoaX_a04_e,time,eta,2)
    end if
    if (outEta@bsoaX_a01_e) then
      bsoaX_a01_e = (/wrf_user_getvar(wrfout,"bsoaX_a01",-1)/)
        bsoaX_a01_e@long_name = "Simplified biomass burning SOA, aerosol bin 01"
        bsoaX_a01_e@standard_name = "bsoaX_a01"
        bsoaX_a01_e@units = "ug/kg-dryair"
        assignVarAttCoord(bsoaX_a01_e,time,eta,2)
    end if
    if (outEta@bsoaX_a02_e) then
      bsoaX_a02_e = (/wrf_user_getvar(wrfout,"bsoaX_a02",-1)/)
        bsoaX_a02_e@long_name = "Simplified biomass burning SOA, aerosol bin 02"
        bsoaX_a02_e@standard_name = "bsoaX_a02"
        bsoaX_a02_e@units = "ug/kg-dryair"
        assignVarAttCoord(bsoaX_a02_e,time,eta,2)
    end if
    if (outEta@bsoaX_a03_e) then
      bsoaX_a03_e = (/wrf_user_getvar(wrfout,"bsoaX_a03",-1)/)
        bsoaX_a03_e@long_name = "Simplified biomass burning SOA, aerosol bin 03"
        bsoaX_a03_e@standard_name = "bsoaX_a03"
        bsoaX_a03_e@units = "ug/kg-dryair"
        assignVarAttCoord(bsoaX_a03_e,time,eta,2)
    end if
    if (outEta@bsoaX_a04_e) then
      bsoaX_a04_e = (/wrf_user_getvar(wrfout,"bsoaX_a04",-1)/)
        bsoaX_a04_e@long_name = "Simplified biomass burning SOA, aerosol bin 04"
        bsoaX_a04_e@standard_name = "bsoaX_a04"
        bsoaX_a04_e@units = "ug/kg-dryair"
        assignVarAttCoord(bsoaX_a04_e,time,eta,2)
    end if
    if (outEta@glysoa_sfc_a01_e) then
      glysoa_sfc_a01_e = (/wrf_user_getvar(wrfout,"glysoa_sfc_a01",-1)/)
        glysoa_sfc_a01_e@long_name = "SOA from glyoxal, aerosol bin 01"
        glysoa_sfc_a01_e@standard_name = "glysoa_sfc_a01"
        glysoa_sfc_a01_e@units = "ug/kg-dryair"
        assignVarAttCoord(glysoa_sfc_a01_e,time,eta,2)
    end if
    if (outEta@glysoa_sfc_a02_e) then
      glysoa_sfc_a02_e = (/wrf_user_getvar(wrfout,"glysoa_sfc_a02",-1)/)
        glysoa_sfc_a02_e@long_name = "SOA from glyoxal, aerosol bin 02"
        glysoa_sfc_a02_e@standard_name = "glysoa_sfc_a02"
        glysoa_sfc_a02_e@units = "ug/kg-dryair"
        assignVarAttCoord(glysoa_sfc_a02_e,time,eta,2)
    end if
    if (outEta@glysoa_sfc_a03_e) then
      glysoa_sfc_a03_e = (/wrf_user_getvar(wrfout,"glysoa_sfc_a03",-1)/)
        glysoa_sfc_a03_e@long_name = "SOA from glyoxal, aerosol bin 03"
        glysoa_sfc_a03_e@standard_name = "glysoa_sfc_a03"
        glysoa_sfc_a03_e@units = "ug/kg-dryair"
        assignVarAttCoord(glysoa_sfc_a03_e,time,eta,2)
    end if
    if (outEta@glysoa_sfc_a04_e) then
      glysoa_sfc_a04_e = (/wrf_user_getvar(wrfout,"glysoa_sfc_a04",-1)/)
        glysoa_sfc_a04_e@long_name = "SOA from glyoxal, aerosol bin 04"
        glysoa_sfc_a04_e@standard_name = "glysoa_sfc_a04"
        glysoa_sfc_a04_e@units = "ug/kg-dryair"
        assignVarAttCoord(glysoa_sfc_a04_e,time,eta,2)
    end if
    if (outEta@na_a01_e) then
      na_a01_e = (/wrf_user_getvar(wrfout,"na_a01",-1)/)
        na_a01_e@long_name = "Sodium, aerosol bin 01"
        na_a01_e@standard_name = "na_a01"
        na_a01_e@units = "ug/kg-dryair"
        assignVarAttCoord(na_a01_e,time,eta,2)
    end if
    if (outEta@na_a02_e) then
      na_a02_e = (/wrf_user_getvar(wrfout,"na_a02",-1)/)
        na_a02_e@long_name = "Sodium, aerosol bin 02"
        na_a02_e@standard_name = "na_a02"
        na_a02_e@units = "ug/kg-dryair"
        assignVarAttCoord(na_a02_e,time,eta,2)
    end if
    if (outEta@na_a03_e) then
      na_a03_e = (/wrf_user_getvar(wrfout,"na_a03",-1)/)
        na_a03_e@long_name = "Sodium, aerosol bin 03"
        na_a03_e@standard_name = "na_a03"
        na_a03_e@units = "ug/kg-dryair"
        assignVarAttCoord(na_a03_e,time,eta,2)
    end if
    if (outEta@na_a04_e) then
      na_a04_e = (/wrf_user_getvar(wrfout,"na_a04",-1)/)
        na_a04_e@long_name = "Sodium, aerosol bin 04"
        na_a04_e@standard_name = "na_a04"
        na_a04_e@units = "ug/kg-dryair"
        assignVarAttCoord(na_a04_e,time,eta,2)
    end if
    if (outEta@biog1_o_a01_e) then
      biog1_o_a01_e = (/wrf_user_getvar(wrfout,"biog1_o_a01",-1)/)
        biog1_o_a01_e@long_name = "Biogenic SOA from isoprene, aerosol bin 01"
        biog1_o_a01_e@standard_name = "biog1_o_a01"
        biog1_o_a01_e@units = "ug/kg-dryair"
        assignVarAttCoord(biog1_o_a01_e,time,eta,2)
    end if
    if (outEta@biog1_o_a02_e) then
      biog1_o_a02_e = (/wrf_user_getvar(wrfout,"biog1_o_a02",-1)/)
        biog1_o_a02_e@long_name = "Biogenic SOA from isoprene, aerosol bin 02"
        biog1_o_a02_e@standard_name = "biog1_o_a02"
        biog1_o_a02_e@units = "ug/kg-dryair"
        assignVarAttCoord(biog1_o_a02_e,time,eta,2)
    end if
    if (outEta@biog1_o_a03_e) then
      biog1_o_a03_e = (/wrf_user_getvar(wrfout,"biog1_o_a03",-1)/)
        biog1_o_a03_e@long_name = "Biogenic SOA from isoprene, aerosol bin 03"
        biog1_o_a03_e@standard_name = "biog1_o_a03"
        biog1_o_a03_e@units = "ug/kg-dryair"
        assignVarAttCoord(biog1_o_a03_e,time,eta,2)
    end if
    if (outEta@biog1_o_a04_e) then
      biog1_o_a04_e = (/wrf_user_getvar(wrfout,"biog1_o_a04",-1)/)
        biog1_o_a04_e@long_name = "Biogenic SOA from isoprene, aerosol bin 04"
        biog1_o_a04_e@standard_name = "biog1_o_a04"
        biog1_o_a04_e@units = "ug/kg-dryair"
        assignVarAttCoord(biog1_o_a04_e,time,eta,2)
    end if
    if (outEta@biog1_c_a01_e) then
      biog1_c_a01_e = (/wrf_user_getvar(wrfout,"biog1_c_a01",-1)/)
        biog1_c_a01_e@long_name = "Biogenic SOA from pinenes, aerosol bin 01"
        biog1_c_a01_e@standard_name = "biog1_c_a01"
        biog1_c_a01_e@units = "ug/kg-dryair"
        assignVarAttCoord(biog1_c_a01_e,time,eta,2)
    end if
    if (outEta@biog1_c_a02_e) then
      biog1_c_a02_e = (/wrf_user_getvar(wrfout,"biog1_c_a02",-1)/)
        biog1_c_a02_e@long_name = "Biogenic SOA from pinenes, aerosol bin 02"
        biog1_c_a02_e@standard_name = "biog1_c_a02"
        biog1_c_a02_e@units = "ug/kg-dryair"
        assignVarAttCoord(biog1_c_a02_e,time,eta,2)
    end if
    if (outEta@biog1_c_a03_e) then
      biog1_c_a03_e = (/wrf_user_getvar(wrfout,"biog1_c_a03",-1)/)
        biog1_c_a03_e@long_name = "Biogenic SOA from pinenes, aerosol bin 03"
        biog1_c_a03_e@standard_name = "biog1_c_a03"
        biog1_c_a03_e@units = "ug/kg-dryair"
        assignVarAttCoord(biog1_c_a03_e,time,eta,2)
    end if
    if (outEta@biog1_c_a04_e) then
      biog1_c_a04_e = (/wrf_user_getvar(wrfout,"biog1_c_a04",-1)/)
        biog1_c_a04_e@long_name = "Biogenic SOA from pinenes, aerosol bin 04"
        biog1_c_a04_e@standard_name = "biog1_c_a04"
        biog1_c_a04_e@units = "ug/kg-dryair"
        assignVarAttCoord(biog1_c_a04_e,time,eta,2)
    end if
    if (outEta@oin_a01_e) then
      oin_a01_e = (/wrf_user_getvar(wrfout,"oin_a01",-1)/)
        oin_a01_e@long_name = "Other inorganics (including dust), aerosol bin 01"
        oin_a01_e@standard_name = "oin_a01"
        oin_a01_e@units = "ug/kg-dryair"
        assignVarAttCoord(oin_a01_e,time,eta,2)
    end if
    if (outEta@oin_a02_e) then
      oin_a02_e = (/wrf_user_getvar(wrfout,"oin_a02",-1)/)
        oin_a02_e@long_name = "Other inorganics (including dust), aerosol bin 02"
        oin_a02_e@standard_name = "oin_a02"
        oin_a02_e@units = "ug/kg-dryair"
        assignVarAttCoord(oin_a02_e,time,eta,2)
    end if
    if (outEta@oin_a03_e) then
      oin_a03_e = (/wrf_user_getvar(wrfout,"oin_a03",-1)/)
        oin_a03_e@long_name = "Other inorganics (including dust), aerosol bin 03"
        oin_a03_e@standard_name = "oin_a03"
        oin_a03_e@units = "ug/kg-dryair"
        assignVarAttCoord(oin_a03_e,time,eta,2)
    end if
    if (outEta@oin_a04_e) then
      oin_a04_e = (/wrf_user_getvar(wrfout,"oin_a04",-1)/)
        oin_a04_e@long_name = "Other inorganics (including dust), aerosol bin 04"
        oin_a04_e@standard_name = "oin_a04"
        oin_a04_e@units = "ug/kg-dryair"
        assignVarAttCoord(oin_a04_e,time,eta,2)
    end if
  end if
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; three-dimensional upper-level (pressure) metorology variables
  ;   (variables on selected pressure levels)
  ;   -derived/diagnostic fields using wrf_user_getvar
  ; -create the variables
  if (outPressure) then
    if (outPressure@Z_p) then
      Z_p = new((/nTime,nPressure,nS_N,nW_E/), "float", "No_FillValue")   ;Z_p
    end if
    if (outPressure@T_p) then
      T_p = new((/nTime,nPressure,nS_N,nW_E/), "float", "No_FillValue")   ;T_p
    end if
    if (outPressure@theta_p) then
      theta_p = new((/nTime,nPressure,nS_N,nW_E/), "float", "No_FillValue");th_p
    end if
    if (outPressure@Td_p) then
      Td_p = new((/nTime,nPressure,nS_N,nW_E/), "float", "No_FillValue")  ;Td_p
    end if
    if (outPressure@r_v_p) then
      r_v_p = new((/nTime,nPressure,nS_N,nW_E/), "float", "No_FillValue") ;r_v_p
    end if
    if (outPressure@q_p) then
      q_p = new((/nTime,nPressure,nS_N,nW_E/), "float", "No_FillValue")   ;q_p
    end if
    if (outPressure@rh_p) then
      rh_p = new((/nTime,nPressure,nS_N,nW_E/), "float", "No_FillValue")  ;rh_p
    end if
    if (outPressure@u_gr_p) then
      u_gr_p = new((/nTime,nPressure,nS_N,nW_E/),"float","No_FillValue") ;u_gr_p
    end if
    if (outPressure@v_gr_p) then
      v_gr_p = new((/nTime,nPressure,nS_N,nW_E/),"float","No_FillValue") ;v_gr_p
    end if
    if (outPressure@u_tr_p) then
      u_tr_p = new((/nTime,nPressure,nS_N,nW_E/),"float","No_FillValue") ;u_tr_p
    end if
    if (outPressure@v_tr_p) then
      v_tr_p = new((/nTime,nPressure,nS_N,nW_E/),"float","No_FillValue") ;v_tr_p
    end if
    if (outPressure@ws_p) then
      ws_p = new((/nTime,nPressure,nS_N,nW_E/),"float","No_FillValue")    ;ws_p
    end if
    if (outPressure@wd_p) then
      wd_p = new((/nTime,nPressure,nS_N,nW_E/),"float","No_FillValue")    ;wd_p
    end if
    if (outPressure@w_p) then
      w_p = new((/nTime,nPressure,nS_N,nW_E/), "float", "No_FillValue")   ;w_p
    end if
    if (outPressure@pp_p) then
      pp_p = new((/nTime,nPressure,nS_N,nW_E/), "float", "No_FillValue")  ;pp_p
    end if
    if ((outPressure@r_cloud_p) .and. (isfilevar(wrfout, "QCLOUD"))) then ;r_cl
      r_cloud_p = new((/nTime,nPressure,nS_N,nW_E/),"float","No_FillValue")
    end if
    if ((outPressure@r_rain_p) .and. (isfilevar(wrfout, "QRAIN"))) then  ;r_rain
      r_rain_p = new((/nTime,nPressure,nS_N,nW_E/),"float","No_FillValue")
    end if
    if ((outPressure@r_ice_p) .and. (isfilevar(wrfout, "QICE"))) then    ;r_ice
      r_ice_p = new((/nTime,nPressure,nS_N,nW_E/),"float","No_FillValue")
    end if
    if ((outPressure@r_snow_p) .and. (isfilevar(wrfout, "QSNOW"))) then  ;r_snow
      r_snow_p = new((/nTime,nPressure,nS_N,nW_E/),"float","No_FillValue")
    end if
    if ((outPressure@r_graup_p) .and. (isfilevar(wrfout, "QGRAUP"))) then ;r_grp
      r_graup_p = new((/nTime,nPressure,nS_N,nW_E/),"float","No_FillValue")
    end if
    if (outPressure@pvo_p) then
      pvo_p = new((/nTime,nPressure,nS_N,nW_E/),"float","No_FillValue")   ;pvo_p
    end if
    if (outPressure@avo_p) then
      avo_p = new((/nTime,nPressure,nS_N,nW_E/),"float","No_FillValue")   ;avo_p
    end if
    ; use wrf_user_intrp3d to interpolate the model levels to a pressure level
    do n = 0, nTime-1  ; loop through the times in the wrfout file
      do p = 0, nPressure-1  ; loop through the selected pressure levels
        if (outPressure@Z_p) then                                  ;Z_p
          Z_p(n,p,:,:) = (/wrf_user_intrp3d(Z_e(n,:,:,:),p_e(n,:,:,:),  \
                                          "h",pressure(p),0,False)/)
        end if
        if (outPressure@T_p) then                                   ;T_p
          T_p(n,p,:,:) = (/wrf_user_intrp3d(T_e(n,:,:,:),p_e(n,:,:,:),  \
                                          "h",pressure(p),0,False)/)
        end if
        if (outPressure@theta_p) then                              ;theta_p
          theta_p(n,p,:,:) = (/wrf_user_intrp3d(theta_e(n,:,:,:),p_e(n,:,:,:), \
                                          "h",pressure(p),0,False)/)
        end if
        if (outPressure@Td_p) then                                 ;Td_p
          Td_p(n,p,:,:) = (/wrf_user_intrp3d(Td_e(n,:,:,:),p_e(n,:,:,:), \
                                             "h",pressure(p),0,False)/)
        end if
        if (outPressure@r_v_p) then                                ;r_v_p
          r_v_p(n,p,:,:) = (/wrf_user_intrp3d(r_v_e(n,:,:,:),p_e(n,:,:,:), \
                                          "h",pressure(p),0,False)/)
        end if
        if (outPressure@rh_p) then                                 ;rh_p
          rh_p(n,p,:,:) = (/wrf_user_intrp3d(rh_e(n,:,:,:),p_e(n,:,:,:), \
                                             "h",pressure(p),0,False)/)
        end if
        if (outPressure@u_gr_p) then                               ;u_gr_p
          u_gr_p(n,p,:,:) = (/wrf_user_intrp3d(u_gr_e(n,:,:,:),p_e(n,:,:,:), \
                                             "h",pressure(p),0,False)/)
        end if
        if (outPressure@v_gr_p) then                               ;v_gr_p
          v_gr_p(n,p,:,:) = (/wrf_user_intrp3d(v_gr_e(n,:,:,:),p_e(n,:,:,:), \
                                             "h",pressure(p),0,False)/)
        end if
        if (outPressure@u_tr_p .or. outPressure@ws_p .or. outPressure@wd_p) then
          u_tr_p(n,p,:,:) = (/wrf_user_intrp3d(u_tr_e(n,:,:,:),p_e(n,:,:,:), \;u
                                             "h",pressure(p),0,False)/)
        end if
        if (outPressure@v_tr_p .or. outPressure@ws_p .or. outPressure@wd_p) then
          v_tr_p(n,p,:,:) = (/wrf_user_intrp3d(v_tr_e(n,:,:,:),p_e(n,:,:,:), \;v
                                             "h",pressure(p),0,False)/)
        end if
        if (outPressure@ws_p)                                      ;ws_p
          ws_p(n,p,:,:) = sqrt(u_tr_p(n,p,:,:)^2 + v_tr_p(n,p,:,:)^2)
        end if
        if (outPressure@wd_p)                                      ;wd_p
          r2d = 45.0/atan(1.0)
          wd_p(n,p,:,:) = atan2(u_tr_p(n,p,:,:), v_tr_p(n,p,:,:)) * r2d + 180.
        end if
        if (outPressure@w_p) then                                  ;w_p
          w_p(n,p,:,:) = (/wrf_user_intrp3d(w_e(n,:,:,:),p_e(n,:,:,:),  \
                                          "h",pressure(p),0,False)/)
        end if
        if (outPressure@q_p) then                                  ;q_p
          q_p(n,p,:,:) = (/wrf_user_intrp3d(q_e(n,:,:,:),p_e(n,:,:,:),  \
                                          "h",pressure(p),0,False)/)
        end if
        if (outPressure@pp_p) then                                 ;pp_p
          pp_p(n,p,:,:) = (/wrf_user_intrp3d(pp_e(n,:,:,:),p_e(n,:,:,:), \
                                          "h",pressure(p),0,False)/)
        end if                                                     ;r_cloud_p
        if ((outPressure@r_cloud_p) .and. (isfilevar(wrfout, "QCLOUD"))) then
          r_cloud_p(n,p,:,:)=(/wrf_user_intrp3d(r_cloud(n,:,:,:),p_e(n,:,:,:), \
                                                "h",pressure(p),0,False)/)
        end if                                                     ;r_rain_p
        if ((outPressure@r_rain_p) .and. (isfilevar(wrfout, "QRAIN"))) then
          r_rain_p(n,p,:,:) = (/wrf_user_intrp3d(r_rain(n,:,:,:),p_e(n,:,:,:), \
                                               "h",pressure(p),0,False)/)
        end if                                                     ;r_ice_p
        if ((outPressure@r_ice_p) .and. (isfilevar(wrfout, "QICE"))) then
          r_ice_p(n,p,:,:) = (/wrf_user_intrp3d(r_ice(n,:,:,:),p_e(n,:,:,:), \
                                              "h",pressure(p),0,False)/)
        end if                                                     ;r_snow_p
        if ((outPressure@r_snow_p) .and. (isfilevar(wrfout, "QSNOW"))) then
          r_snow_p(n,p,:,:) = (/wrf_user_intrp3d(r_snow(n,:,:,:),p_e(n,:,:,:), \
                                              "h",pressure(p),0,False)/)
        end if                                                     ;r_graup_p
        if ((outPressure@r_graup_p) .and. (isfilevar(wrfout, "QGRAUP"))) then
          r_graup_p(n,p,:,:)=(/wrf_user_intrp3d(r_graup(n,:,:,:),p_e(n,:,:,:), \
                                                "h",pressure(p),0,False)/)
        end if
        if (outPressure@pvo_p) then                                ;pvo_p
          pvo_p(n,p,:,:)=(/wrf_user_intrp3d(pvo_e(n,:,:,:),p_e(n,:,:,:), \
                                                "h",pressure(p),0,False)/)
        end if
        if (outPressure@avo_p) then                                ;avo_p
          avo_p(n,p,:,:)=(/wrf_user_intrp3d(avo_e(n,:,:,:),p_e(n,:,:,:), \
                                                "h",pressure(p),0,False)/)
        end if
      end do 
    end do
    ;set the variable attributes
    if (outPressure@Z_p) then                                      ;Z_p
      Z_p@long_name = "Geopotential Height"
        Z_p@standard_name = "geopotential_height"
        Z_p@units = "m"
        assignVarAttCoord(Z_p,time,pressure,1)
    end if
    if (outPressure@T_p) then                                      ;T_p
      T_p@long_name = "Temperature"
        T_p@standard_name = "air_temperature"
        T_p@units = "K"
        assignVarAttCoord(T_p,time,pressure,1)
    end if
    if (outPressure@theta_p) then                                  ;theta_p
      theta_p@long_name = "Potential Temperature"
        theta_p@standard_name = "air_potential_temperature"
        theta_p@units = "K"
        assignVarAttCoord(theta_p,time,pressure,1)
    end if
    if (outPressure@Td_p) then                                     ;Td_p
      Td_p@long_name = "Dewpoint Temperature"
        Td_p@standard_name = "dew_point_temperature"
        Td_p@units = "degC"
        assignVarAttCoord(Td_p,time,pressure,1) 
    end if
    if (outPressure@r_v_p) then                                    ;r_v_p
      r_v_p@long_name = "Mixing Ratio"
        r_v_p@standard_name = "humidity_mixing_ratio"
        r_v_p@units = "kg kg-1"
        assignVarAttCoord(r_v_p,time,pressure,1)
    end if
    if (outPressure@q_p) then              	                       ;q_p
      q_p@long_name     = "Specific Humidity"
      q_p@standard_name = "specific_humidity"
      q_p@units         = "kg kg-1"
      assignVarAttCoord(q_p,time,pressure,1)
    end if
    if (outPressure@rh_p) then                                     ;rh_p
      rh_p@long_name = "Relative Humidity"
        rh_p@standard_name = "relative_humidity"
        rh_p@units = "percent"
        assignVarAttCoord(rh_p,time,pressure,1)
    end if
    if (outPressure@u_gr_p) then                                   ;u_gr_p
      u_gr_p@long_name = "u-Component of Wind (grid)"
        u_gr_p@standard_name = "eastward_wind"
        u_gr_p@units = "m s-1"
        assignVarAttCoord(u_gr_p,time,pressure,1)
    end if
    if (outPressure@v_gr_p) then                                   ;v_gr_p
      v_gr_p@long_name = "v-Component of Wind (grid)"
        v_gr_p@standard_name = "northward_wind"
        v_gr_p@units = "m s-1"
        assignVarAttCoord(v_gr_p,time,pressure,1)
    end if
    if (outPressure@u_tr_p) then                                   ;u_tr_p
      u_tr_p@long_name = "u-Component of Wind (Earth)"
      u_tr_p@standard_name = "eastward_wind"
      u_tr_p@units = "m s-1"
      assignVarAttCoord(u_tr_p,time,pressure,1)
    end if
    if (outPressure@v_tr_p) then                                   ;v_tr_p
      v_tr_p@long_name = "v-Component of Wind (Earth)"
      v_tr_p@standard_name = "northward_wind"
      v_tr_p@units = "m s-1"
      assignVarAttCoord(v_tr_p,time,pressure,1)
    end if
    if (outPressure@ws_p) then                                     ;ws_p
      ws_p@long_name = "Wind Speed"
        ws_p@standard_name = "wind_speed"
        ws_p@units = "m s-1"
        assignVarAttCoord(ws_p,time,pressure,1)
    end if
    if (outPressure@wd_p) then                                     ;wd_p
      wd_p@long_name = "Wind Direction (Earth)"
        wd_p@standard_name = "wind_from_direction"
        wd_p@units = "degree"
        assignVarAttCoord(wd_p,time,pressure,1)
    end if
    if (outPressure@w_p) then                                      ;w_p
      w_p@long_name = "w-Component of Wind"
        w_p@standard_name = "upward_wind"
        w_p@units = "m s-1"
        assignVarAttCoord(w_p,time,pressure,1)
    end if
    if (outPressure@pp_p) then                                     ;pp_p
      pp_p@long_name = "Pressure-Perturbation"
        pp_p@standard_name = ""
        pp_p@units = "hPa"
        assignVarAttCoord(pp_p,time,pressure,1)
    end if                                                         ;r_cloud_p
    if ((outPressure@r_cloud_p) .and. (isfilevar(wrfout, "QCLOUD"))) then
      r_cloud_p@long_name = "Mixing Ratio - Cloud"
        r_cloud_p@standard_name ="mass_fraction_of_cloud_liquid_water_in_air"
        r_cloud_p@units = "kg kg-1"
        assignVarAttCoord(r_cloud_p,time,pressure,1)
    end if                                                         ;r_rain_p
    if ((outPressure@r_rain_p) .and. (isfilevar(wrfout, "QRAIN"))) then
      r_rain_p@long_name = "Mixing Ratio - Rain"
        r_rain_p@standard_name = "mass_fraction_of_rain_in_air"
        r_rain_p@units = "kg kg-1"
        assignVarAttCoord(r_rain_p,time,pressure,1)
    end if                                                         ;r_ice_p
    if ((outPressure@r_ice_p) .and. (isfilevar(wrfout, "QICE"))) then
      r_ice_p@long_name = "Mixing Ratio - Ice"
        r_ice_p@standard_name = "mass_fraction_of_cloud_ice_in_air"
        r_ice_p@units = "kg kg-1"
        assignVarAttCoord(r_ice_p,time,pressure,1)
    end if                                                         ;r_snow_p
    if ((outPressure@r_snow_p) .and. (isfilevar(wrfout, "QSNOW"))) then
      r_snow_p@long_name = "Mixing Ratio - Snow"
        r_snow_p@standard_name = "mass_fraction_of_snow_in_air"
        r_snow_p@units = "kg kg-1"
        assignVarAttCoord(r_snow_p,time,pressure,1)
    end if                                                         ;r_graup_p
    if ((outPressure@r_graup_p) .and. (isfilevar(wrfout, "QGRAUP"))) then
      r_graup_p@long_name = "Mixing Ratio - Graupel"
        r_graup_p@standard_name = "mass_fraction_of_graupel_in_air"
        r_graup_p@units = "kg kg-1"
        assignVarAttCoord(r_graup_p,time,pressure,1)
    end if
    if (outPressure@pvo_p) then                                    ;pvo_p
      pvo_p@long_name = "Potential Vorticity"
        pvo_p@standard_name = "potential_vorticity_of_atmosphere_layer"
        pvo_p@units = "PVU"
        assignVarAttCoord(pvo_p,time,pressure,1)
    end if
    if (outPressure@avo_p) then                                    ;avo_p
      avo_p@long_name = "Absolute Vorticity"
        avo_p@standard_name = "atmosphere_absolute_vorticity"
        avo_p@units = "s-1"
        assignVarAttCoord(avo_p,time,pressure,1)
    end if
  end if
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; two-dimensional surface energy budget / radiation variables
  if (out2dRadFlx) then
    if (out2dRadFlx@SW_d) then
      SW_d = (/wrfout->SWDOWN/)            ;SW flux - downward - sfc - instant
        SW_d@long_name = "Shortwave Flux - Downward - at surface - instant"
        SW_d@standard_name = "surface_downwelling_shortwave_flux_in_air"
        SW_d@units = "W m-2"
        assignVarAttCoord(SW_d,time,0,0)
    end if
    if (out2dRadFlx@LW_d) then
      LW_d = (/wrfout->GLW/)               ;LW flux - downward - sfc - instant
        LW_d@long_name = "Longwave Flux - Downward - at surface - instant"
        LW_d@standard_name = "surface_downwelling_longwave_flux_in_air"
        LW_d@units = "W m-2"
        assignVarAttCoord(LW_d,time,0,0)
    end if
    if (out2dRadFlx@SW_u .and. isfilevar(wrfout, "SWUPB")) then
      SW_u = (/wrfout->SWUPB/)             ;SW flux - upward - sfc - instant
      SW_u@long_name = "Shortwave Flux - Upward - at surface - instant"
      SW_u@standard_name = "surface_upwelling_shortwave_flux_in_air"
      SW_u@units = "W m-2"
      assignVarAttCoord(SW_u,time,0,0)
    end if
    if (out2dRadFlx@LW_u .and. isfilevar(wrfout, "LWUPB")) then
      LW_u = (/wrfout->LWUPB/)             ;LW flux - upward - sfc - instant
      LW_u@long_name = "Longwave Flux - Upward - at surface - instant"
      LW_u@standard_name = "surface_upwelling_longwave_flux_in_air"
      LW_u@units = "W m-2"
      assignVarAttCoord(LW_u,time,0,0)
    end if
    if (out2dRadFlx@LW_u_toa .and. isfilevar(wrfout, "OLR")) then
      LW_u_toa = (/wrfout->OLR/)           ;LW flux - upward - toa - instant
        LW_u_toa@long_name = "Longwave Flux - Upward - TOA"
        LW_u_toa@standard_name = "toa_outgoing_longwave_flux"
        LW_u_toa@units = "W m-2"
        assignVarAttCoord(LW_u_toa,time,0,0)
    end if
    if (out2dRadFlx@SW_d_acc .and. isfilevar(wrfout, "ACSWDNB")) then
      SW_d_acc = (/wrfout->ACSWDNB/)       ;SW flux - downward - sfc - accum.
      SW_d_acc@long_name ="Shortwave Flux - Downward - at surface - accumulated"
      SW_d_acc@standard_name = "surface_downwelling_shortwave_flux_in_air"
      SW_d_acc@units = "J m-2"
      assignVarAttCoord(SW_d_acc,time,0,0)
    end if
    if (out2dRadFlx@LW_d_acc .and. isfilevar(wrfout, "ACLWDNB")) then
      LW_d_acc = (/wrfout->ACLWDNB/)       ;LW flux - downward - sfc - accum.
      LW_d_acc@long_name = "Longwave Flux - Downward - at surface - accumulated"
      LW_d_acc@standard_name = "surface_downwelling_longwave_flux_in_air"
      LW_d_acc@units = "J m-2"
      assignVarAttCoord(LW_d_acc,time,0,0)
    end if
    if (out2dRadFlx@SW_u_acc .and. isfilevar(wrfout, "ACSWUPB")) then
      SW_u_acc = (/wrfout->ACSWUPB/)       ;SW flux - upward - sfc - accum.
      SW_u_acc@long_name = "Shortwave Flux - Upward - at surface - accumulated"
      SW_u_acc@standard_name = "surface_upwelling_shortwave_flux_in_air"
      SW_u_acc@units = "J m-2"
      assignVarAttCoord(SW_u_acc,time,0,0)
    end if
    if (out2dRadFlx@LW_u_acc .and. isfilevar(wrfout, "ACLWUPB")) then
      LW_u_acc = (/wrfout->ACLWUPB/)       ;LW flux - upward - sfc - accum.
      LW_u_acc@long_name = "Longwave Flux - Upward - at surface - accumulated"
      LW_u_acc@standard_name = "surface_upwelling_longwave_flux_in_air"
      LW_u_acc@units = "J m-2"
      assignVarAttCoord(LW_u_acc,time,0,0)
    end if
    if (out2dRadFlx@SW_d_toa_acc .and. isfilevar(wrfout, "ACSWDNT")) then
      SW_d_toa_acc = (/wrfout->ACSWDNT/)   ;SW flux - downward - toa - accum.
      SW_d_toa_acc@long_name = "Shortwave Flux - Downward - TOA - accumulated"
      SW_d_toa_acc@standard_name = "toa_incoming_shortwave_flux"
      SW_d_toa_acc@units = "J m-2"
      assignVarAttCoord(SW_d_toa_acc,time,0,0)
    end if
    if (out2dRadFlx@LW_d_toa_acc .and. isfilevar(wrfout, "ACLWDNT")) then
      LW_d_toa_acc = (/wrfout->ACLWDNT/)   ;LW flux - downward - toa - accum.
      LW_d_toa_acc@long_name = "Longwave Flux - Downward - TOA - accumulated"
      LW_d_toa_acc@standard_name = "toa_incoming_longwave_flux"
      LW_d_toa_acc@units = "J m-2"
      assignVarAttCoord(LW_d_toa_acc,time,0,0)
    end if
    if (out2dRadFlx@SW_u_toa_acc .and. isfilevar(wrfout, "ACSWUPT")) then
      SW_u_toa_acc = (/wrfout->ACSWUPT/)   ;SW flux - upward - toa - accum.
      SW_u_toa_acc@long_name = "Shortwave Flux - Upward - TOA - accumulated"
      SW_u_toa_acc@standard_name = "toa_outgoing_shortwave_flux"
      SW_u_toa_acc@units = "J m-2"
      assignVarAttCoord(SW_u_toa_acc,time,0,0)
    end if
    if (out2dRadFlx@LW_u_toa_acc .and. isfilevar(wrfout, "ACLWUPT")) then
      LW_u_toa_acc = (/wrfout->ACLWUPT/)   ;LW flux - upward - toa - accum.
      LW_u_toa_acc@long_name = "Longwave Flux - Upward - TOA - accumulated"
      LW_u_toa_acc@standard_name = "toa_outgoing_longwave_flux"
      LW_u_toa_acc@units = "J m-2"
      assignVarAttCoord(LW_u_toa_acc,time,0,0)
    end if
    if (out2dRadFlx@albedo) then
      albedo = (/wrfout->ALBEDO/)          ;albedo
        albedo@long_name = "Surface Albedo"
        albedo@standard_name = "surface_albedo"
        albedo@units = ""
        assignVarAttCoord(albedo,time,0,0)
    end if
    if (out2dRadFlx@emiss_sfc) then
      emiss_sfc = (/wrfout->EMISS/)        ;surface emissivity
      emiss_sfc@long_name = "Surface Emissivity"
      emiss_sfc@standard_name = "surface_longwave_emissivity"
      emiss_sfc@units = ""
      assignVarAttCoord(emiss_sfc,time,0,0)
    end if
    if (out2dRadFlx@SH) then
      SH = (/wrfout->HFX/)                 ;SH flux - upward - sfc - instant
        SH@long_name = "Sensible Heat Flux - Upward - at surface - instant"
        SH@standard_name = "surface_upward_sensible_heat_flux"
        SH@units = "W m-2"
        assignVarAttCoord(SH,time,0,0)
    end if
    if (out2dRadFlx@LH) then
      LH = (/wrfout->LH/)                  ;LH flux - upward - sfc - instant
        LH@long_name = "Latent Heat Flux - Upward - at surface - instant"
        LH@standard_name = "surface_upward_latent_heat_flux"
        LH@units = "W m-2"
        assignVarAttCoord(LH,time,0,0)
    end if
    if (out2dRadFlx@SH_acc .and. (isfilevar(wrfout, "ACHFX"))) then
      SH_acc = (/wrfout->ACHFX/)           ;SH flux - upward - sfc - accum.
      SH_acc@long_name ="Sensible Heat Flux - Upward - at surface - accumulated"
      SH_acc@standard_name = "surface_upward_sensible_heat_flux"
      SH_acc@units = "J m-2"
      assignVarAttCoord(SH_acc,time,0,0)
    end if
    if (out2dRadFlx@LH_acc .and. (isfilevar(wrfout, "ACLHF"))) then
      LH_acc = (/wrfout->ACLHF/)           ;LH flux - upward - sfc - accum.
      LH_acc@long_name = "Latent Heat Flux - Upward - at surface - accumulated"
      LH_acc@standard_name = "surface_upward_latent_heat_flux"
      LH_acc@units = "J m-2"
      assignVarAttCoord(LH_acc,time,0,0)
    end if
    if (out2dRadFlx@MH) then
      MH = (/wrfout->QFX/)                 ;moisture heat flux at the surface
        MH@long_name = "Moisture Heat Flux - Upward - at surface"
        MH@standard_name = "surface_upward_water_flux"
        MH@units = "kg m-2 s-1"
        assignVarAttCoord(MH,time,0,0)
    end if
    if (out2dRadFlx@u_star .and. isfilevar(wrfout, "UST")) then
      u_star = (/wrfout->UST/)             ;friction velocity (similarity)
        u_star@long_name = "Friction Velocity (u*)"
        u_star@standard_name = ""
        u_star@units = "m s-1"
        assignVarAttCoord(u_star,time,0,0)
    end if
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; two-dimensional surface energy budget / radiation variables (calculated)
    ;  Note: process both IWP and LWP, even if only one is specified
    if (out2dRadFlx@LWP .or. out2dRadFlx@IWP) then
      ; -create the variable
      LWP = new((/nTime,nS_N,nW_E/), double, "No_FillValue")    ;LWP
      IWP = new((/nTime,nS_N,nW_E/), double, "No_FillValue")    ;IWP
      ; -loop through the nTimes
      do n = 0, nTime-1
        ; -create the variables (does not include time dimension)
        p_eta = new((/nEta,nS_N,nW_E/), double, "No_FillValue")
        p_int = new((/nEta+1,nS_N,nW_E/), double, "No_FillValue")
        p_surf = new((/nS_N,nW_E/), double, "No_FillValue")
        d_pres = new((/nS_N,nW_E/), double, "No_FillValue")
        r_v_eta = new((/nEta,nS_N,nW_E/), double)
        r_c_eta = new((/nEta,nS_N,nW_E/), double)
        r_r_eta = new((/nEta,nS_N,nW_E/), double)
        r_i_eta = new((/nEta,nS_N,nW_E/), double)
        r_i_eta = 0.d  ;set to 0 in case it is not in the wrfout file
        r_s_eta = new((/nEta,nS_N,nW_E/), double)
        r_s_eta = 0.d
        r_g_eta = new((/nEta,nS_N,nW_E/), double)
        r_g_eta = 0.d
        ; -read in the values needed for calculations
        p_eta = (/wrf_user_getvar(wrfout,"pressure",n)/)*100.
        p_surf = (/wrfout->PSFC(n,:,:)/)
        p_tp_in = (/wrfout->P_TOP/)     ;pressure at top of model
        ;in some files P_TOP has two dimensions, in some it has one dimension
        if ((dimsizes(dimsizes(p_tp_in))) .eq. 2) then
          p_tp = p_tp_in(0,0)
        else
          p_tp = p_tp_in(0)
        end if
        r_v_eta = (/wrfout->QVAPOR(n,:,:,:)/)
;        r_c_eta = (/wrfout->QCLOUD(n,:,:,:)/)
        r_r_eta = (/wrfout->QRAIN(n,:,:,:)/)
        if (isfilevar(wrfout, "QICE")) then  ;verify it is included in wrfout
          r_i_eta = (/wrfout->QICE(n,:,:,:)/)
        end if
        if (isfilevar(wrfout, "QSNOW")) then
          r_s_eta = (/wrfout->QSNOW(n,:,:,:)/)
        end if
        if (isfilevar(wrfout, "QGRAUP")) then
          r_g_eta = (/wrfout->QGRAUP(n,:,:,:)/)
        end if
        ; -calculate the pressure at the intersection between eta levels
        p_int(0,:,:) = p_surf
        p_int(nEta,:,:) = p_tp
        do k = 1, nEta-1
          p_int(k,:,:) = (p_eta(k-1,:,:)+p_eta(k,:,:))*0.5
        end do
        ; -loop through the nEta
        do k = 0, nEta-1
          ; -calculate the difference in pressure between eta levels
          d_pres = p_int(k,:,:) - p_int(k+1,:,:)
          ; -calculate the IWP and LWP
          LWP(n,:,:) = LWP(n,:,:) + (r_c_eta(k,:,:)*d_pres/9.81)
          IWP(n,:,:) = IWP(n,:,:) +  \
                      (r_i_eta(k,:,:)+r_s_eta(k,:,:)+r_g_eta(k,:,:))*d_pres/9.81
        end do
      end do
      ; -set the attributes
      LWP@long_name = "Liquid Water Path"
        LWP@standard_name = "atmosphere_cloud_liquid_water_content"
        LWP@units = "kg m-2"
        LWP@notes = "Column integrated cloud water."
        assignVarAttCoord(CLWP,time,0,0)      ;LWP
      IWP@long_name = "Ice Water Path"
        IWP@standard_name = "atmosphere_cloud_ice_content"
        IWP@units = "kg m-2"
        IWP@notes = "Column integrated cloud ice."
        assignVarAttCoord(CIWP,time,0,0)      ;IWP
    end if
  end if
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; two-dimensional surface/soil variables
  if (out2dLandSoil) then
    if (out2dLandSoil@LandMask) then
      LandMask = (/wrfout->LANDMASK/)      ;land mask (1 - land, 0 - water)
        LandMask@long_name = "Land Mask"
        LandMask@standard_name = "land_binary_mask"
        LandMask@units = ""
        LandMask@notes = "1=land, 0=water"
        assignVarAttCoord(LandMask,time,0,0)
    end if
    if (out2dLandSoil@LandUse) then
      LandUse = (/wrfout->LU_INDEX/)       ;land use category
        LandUse@long_name = "Land Use Category"
        LandUse@standard_name = "area_type"
        LandUse@units = ""
        LandUse@notes = "see WRF LANDUSE.TBL for category types"
        assignVarAttCoord(LandUse,time,0,0)
    end if
    if (out2dLandSoil@SoilT_L) then
      SoilT_L = (/wrfout->TMN/)            ;soil temperature at lower boundary
        SoilT_L@long_name = "Soil Temperature - at lower boundery"
        SoilT_L@standard_name = "soil_temperature"
        SoilT_L@units = "K"
        assignVarAttCoord(SoilT_L,time,0,0)
    end if
    if ((out2dLandSoil@SoilT_B) .and. isfilevar(wrfout, "SOILTB")) then
      SoilT_B = (/wrfout->SOILTB/)         ;bottom soil temperature
        SoilT_B@long_name = "Soil Temperature - bottom"
        SoilT_B@standard_name = "soil_temperature"
        SoilT_B@units = "K"
        assignVarAttCoord(SoilT_B,time,0,0)
    end if
    if (out2dLandSoil@GroundFlx) then
      GroundFlx = (/wrfout->GRDFLX/)       ;ground heat flux
        GroundFlx@long_name = "Ground Heat Flux"
        GroundFlx@standard_name = "upward_heat_flux_at_ground_level_in_soil"
        GroundFlx@units = "W m-2"
        assignVarAttCoord(GroundFlx,time,0,0)
    end if
    if (out2dLandSoil@SnowHgt) then
      SnowHgt = (/wrfout->SNOWH/)          ;snow height
        SnowHgt@long_name = "Physical Snow Depth"
        SnowHgt@standard_name = "surface_snow_thickness"
        SnowHgt@units = "m"
        assignVarAttCoord(SnowHgt,time,0,0)
    end if
    if (out2dLandSoil@SnowWater) then
      SnowWater = (/wrfout->SNOW/)         ;snow water equivalent
        SnowWater@long_name = "Snow Water Equivalent"
        SnowWater@standard_name = "surface_snow_amount"
        SnowWater@units = "kg m-2"
        assignVarAttCoord(SnowWater,time,0,0)
    end if
    if ((out2dLandSoil@SnowDens) .and. isfilevar(wrfout, "RHOSN")) then
      SnowDens = (/wrfout->RHOSN/)         ;snow density
        SnowDens@long_name = "Snow Density"
        SnowDens@standard_name = "snow_density"
        SnowDens@units = "kg m-3"
        assignVarAttCoord(SnowDens,time,0,0)
    end if
    if ((out2dLandSoil@SnowFlx) .and. isfilevar(wrfout, "SNOPCX")) then
      SnowFlx = (/wrfout->SNOPCX/)         ;snow phase change heat flux
        SnowFlx@long_name = "Snow Phase Change Heat Flux"
        SnowFlx@standard_name = "surface_snow_melt_and_sublimation_heat_flux"
        SnowFlx@units = "W m-2"
        assignVarAttCoord(SnowFlx,time,0,0)
    end if
    if ((out2dLandSoil@SnowMelt) .and. isfilevar(wrfout,"ACSNOM"))then
        SnowMelt = (/wrfout->ACSNOM/)      ; snow melt; accumulated
        SnowMelt@long_name     = "Snow Melt - accumulated"
        SnowMelt@standard_name = "surface_snow_melt_amount"
        SnowMelt@units         = "kg m-2"
        assignVarAttCoord(SnowMelt,time,0,0)
    end if
    if ((out2dLandSoil@SeaIce) .and. isfilevar(wrfout, "SEAICE")) then
      SeaIce = (/wrfout->SEAICE/)          ;sea ice flag
        SeaIce@long_name = "Sea Ice"
        SeaIce@standard_name = "sea_ice_area_fraction"
        SeaIce@units = ""
        SeaIce@notes = "1=seaice, 0=water"
        assignVarAttCoord(SeaIce,time,0,0)
    else
      if ((out2dLandSoil@SeaIce) .and. isfilevar(wrfout, "XICE")) then
        SeaIce = (/wrfout->XICE/)          ;sea ice flag
          SeaIce@long_name = "Sea Ice Flag"
          SeaIce@standard_name = "seaice_binary_mask"
          SeaIce@units = ""
          SeaIce@notes = "1=seaice, 0=water"
          assignVarAttCoord(SeaIce,time,0,0)
      end if
    end if
    if ((out2dLandSoil@WaterFlx) .and. isfilevar(wrfout, "SFCEVP")) then
      WaterFlx = (/wrfout->SFCEVP/)        ;WaterFlx
      WaterFlx@long_name = "Water Evaporation Flux - at surface"
      WaterFlx@standard_name = "water_evaporation"
      WaterFlx@units = "kg m-2"
      assignVarAttCoord(WaterFlx,time,0,0)
    end if
    if ((out2dLandSoil@SfcRunoff) .and. isfilevar(wrfout,"SFROFF")) then
      SfcRunoff = (/wrfout->SFROFF/)       ;SfcRunoff
      SfcRunoff@long_name = "Surface Runoff"
      SfcRunoff@standard_name = "surface_runoff_flux"
      SfcRunoff@units = "mm"
      assignVarAttCoord(SfcRunoff,time,0,0)
    end if
    if ((out2dLandSoil@SubRunoff) .and. isfilevar(wrfout,"UDROFF"))then
      SubRunoff = (/wrfout->UDROFF/)       ;SubRunoff
      SubRunoff@long_name     = "Subsurface Runoff"
      SubRunoff@standard_name = "runoff_flux"
      SubRunoff@units         = "mm"
      assignVarAttCoord(SubRunoff,time,0,0)
    end if
    if ((out2dLandSoil@SoilMoist) .and. isfilevar(wrfout,"SMSTOT"))then
      SoilMoist = (/wrfout->SMSTOT/)       ;SoilMoist
      SoilMoist@long_name     = "Soil Moisture Content - total"
      SoilMoist@standard_name = "soil_moisture_content"
      SoilMoist@units         = "kg m-2"
      assignVarAttCoord(SoilMoist,time,0,0)
    end if
    if ((out2dLandSoil@AOD470_sfc) .and. isfilevar(wrfout,"AOD470_sfc"))then
      AOD470_sfc = (/wrfout->AOD470_sfc/)       ;AOD470_sfc
      AOD470_sfc@long_name     = "Aerosol Optical Depth at 470nm - surface level"
      AOD470_sfc@standard_name = "AOD470_sfc"
      AOD470_sfc@units         = "km-1"
      assignVarAttCoord(AOD470_sfc,time,0,0)
    end if
    if ((out2dLandSoil@AOD550_sfc) .and. isfilevar(wrfout,"AOD550_sfc"))then
      AOD550_sfc = (/wrfout->AOD550_sfc/)       ;AOD550_sfc
      AOD550_sfc@long_name     = "Aerosol Optical Depth at 550nm - surface level"
      AOD550_sfc@standard_name = "AOD550_sfc"
      AOD550_sfc@units         = "km-1"
      assignVarAttCoord(AOD550_sfc,time,0,0)
    end if
    if ((out2dLandSoil@AOD675_sfc) .and. isfilevar(wrfout,"AOD675_sfc"))then
      AOD675_sfc = (/wrfout->AOD675_sfc/)       ;AOD675_sfc
      AOD675_sfc@long_name     = "Aerosol Optical Depth at 675nm - surface level"
      AOD675_sfc@standard_name = "AOD675_sfc"
      AOD675_sfc@units         = "km-1"
      assignVarAttCoord(AOD675_sfc,time,0,0)
    end if
  end if
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; three-dimensional soil variables
  ;   (variables on staggered soil levels)
  if (outSoil) then
    if (outSoil@SoilTemp) then
      SoilTemp = (/wrfout->TSLB/)          ;soil temperature
        SoilTemp@long_name = "Soil Temperature"
        SoilTemp@standard_name = "soil_temperature"
        SoilTemp@units = "K"
        assignVarAttCoord(SoilTemp,time,soil,3)
    end if
    if (outSoil@SoilMoist) then
      SoilMoist = (/wrfout->SMOIS/)        ;soil moisture
        SoilMoist@long_name = "Soil Moisture"
        SoilMoist@standard_name = "soil_moisture_content"
        SoilMoist@units = "m3 m-3"
        assignVarAttCoord(SoilMoist,time,soil,3)
    end if
    if ((outSoil@SoilWater) .and. isfilevar(wrfout, "SH20")) then
      SoilWater = (/wrfout->SH20/)         ;soil liquid water
        SoilWater@long_name = "Soil Liquid Water"
        SoilWater@standard_name = "liquid_water_content_of_soil_layer"
        SoilWater@units = "m3 m-3"
        assignVarAttCoord(SoilWater,time,soil,3)
    end if
  end if
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; two-dimensional CLimate WRF (CLWRF)
  if (outCLWRF) then
    if ((outCLWRF@T_sfc_min) .and. isfilevar(wrfout, "SKINTEMPMIN")) then
      T_sfc_min = (/wrfout->SKINTEMPMIN/)                          ;T_sfc_min
        T_sfc_min@long_name = "Temperature at the Surface - Minimum"
        T_sfc_min@standard_name = "surface_temperature"
        T_sfc_min@units = "K"
        assignVarAttCoord(T_sfc_min,time,0,0)
    end if
    if ((outCLWRF@T_sfc_max) .and. isfilevar(wrfout, "SKINTEMPMAX"))then
      T_sfc_max = (/wrfout->SKINTEMPMAX/)                          ;T_sfc_max
        T_sfc_max@long_name = "Temperature at the Surface - Maximum"
        T_sfc_max@standard_name = "surface_temperature"
        T_sfc_max@units = "K"
        assignVarAttCoord(T_sfc_max,time,0,0)
    end if
    if ((outCLWRF@T_sfc_mean) .and. isfilevar(wrfout, "SKINTEMPMEAN"))then
      T_sfc_mean = (/wrfout->SKINTEMPMEAN/)                        ;T_sfc_mean
        T_sfc_mean@long_name = "Temperature at the Surface - Mean"
        T_sfc_mean@standard_name = "surface_temperature"
        T_sfc_mean@units = "K"
        assignVarAttCoord(T_sfc_mean,time,0,0)
    end if
    if ((outCLWRF@T_sfc_std) .and. isfilevar(wrfout, "SKINTEMPSTD")) then
      T_sfc_std = (/wrfout->SKINTEMPSTD/)                          ;T_sfc_std
        T_sfc_std@long_name = "Temperature at the Surface - Standard Deviation"
        T_sfc_std@standard_name = "surface_temperature"
        T_sfc_std@units = "K"
        assignVarAttCoord(T_sfc_std,time,0,0)
    end if
    if ((outCLWRF@T_2m_min) .and. isfilevar(wrfout, "T2MIN")) then
      T_2m_min = (/wrfout->T2MIN/) - 273.15                        ;T_2m_min
        T_2m_min@long_name = "Temperature at 2 m - Minimum"
        T_2m_min@standard_name = "air_temperature"
        T_2m_min@units = "degC"
        assignVarAttCoord(T_2m_min,time,0,0)
    end if
    if ((outCLWRF@T_2m_max) .and. isfilevar(wrfout, "T2MAX"))then
      T_2m_max = (/wrfout->T2MAX/) - 273.15                        ;T_2m_max
        T_2m_max@long_name = "Temperature at 2 m - Maximum"
        T_2m_max@standard_name = "air_temperature"
        T_2m_max@units = "degC"
        assignVarAttCoord(T_2m_max,time,0,0)
    end if
    if ((outCLWRF@T_2m_mean) .and. isfilevar(wrfout, "T2MEAN"))then
      T_2m_mean = (/wrfout->T2MEAN/) - 273.15                      ;T_2m_mean
        T_2m_mean@long_name = "Temperature at 2 m - Mean"
        T_2m_mean@standard_name = "air_temperature"
        T_2m_mean@units = "degC"
        assignVarAttCoord(T_2m_mean,time,0,0)
    end if
    if ((outCLWRF@T_2m_std) .and. isfilevar(wrfout, "T2STD")) then
      T_2m_std = (/wrfout->T2STD/)                                 ;T_2m_std
        T_2m_std@long_name = "Temperature at 2 m - Standard Deviation"
        T_2m_std@standard_name = "air_temperature"
        T_2m_std@units = "degC"
        assignVarAttCoord(T_2m_std,time,0,0)
    end if
    if ((outCLWRF@q_2m_min) .and. isfilevar(wrfout, "Q2MIN")) then
      q_2m_min = (/wrfout->Q2MIN/)                                 ;q_2m_min
        q_2m_min@long_name = "Mixing Ratio at 2 m - Minimum"
        q_2m_min@standard_name = "humidity_mixing_ratio"
        q_2m_min@units = "kg kg-1"
        assignVarAttCoord(q_2m_min,time,0,0)
    end if
    if ((outCLWRF@q_2m_max) .and. isfilevar(wrfout, "Q2MAX"))then
      q_2m_max = (/wrfout->Q2MAX/)                                 ;q_2m_max
        q_2m_max@long_name = "Mixing Ratio at 2 m - Maximum"
        q_2m_max@standard_name = "humidity_mixing_ratio"
        q_2m_max@units = "kg kg-1"
        assignVarAttCoord(q_2m_max,time,0,0)
    end if
    if ((outCLWRF@q_2m_mean) .and. isfilevar(wrfout, "Q2MEAN"))then
      q_2m_mean = (/wrfout->Q2MEAN/)                               ;q_2m_mean
        q_2m_mean@long_name = "Mixing Ratio at 2 m - Mean"
        q_2m_mean@standard_name = "humidity_mixing_ratio"
        q_2m_mean@units = "kg kg-1"
        assignVarAttCoord(q_2m_mean,time,0,0)
    end if
    if ((outCLWRF@q_2m_std) .and. isfilevar(wrfout, "Q2STD")) then
      q_2m_std = (/wrfout->Q2STD/)                                 ;q_2m_std
        q_2m_std@long_name = "Mixing Ratio at 2 m - Standard Deviation"
        q_2m_std@standard_name = "humidity_mixing_ratio"
        q_2m_std@units = "kg kg-1"
        assignVarAttCoord(q_2m_std,time,0,0)
    end if
  end if
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;; remove the time attribute for all eta level variables ;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; -for some reason the time attribute is added to the eta levels during
  ;  the interpolation routines - delete these attributes
  if (isvar("pressure") .and. isatt(pressure, "pressure")) then
    delete(pressure@pressure)
  end if
  if (isvar("Z_e") .and. isatt(Z_e, "time")) then
    delete(Z_e@time)
  end if
  if (isvar("p_e") .and. isatt(p_e, "time")) then
    delete(p_e@time)
  end if
  if (isvar("T_e") .and. isatt(T_e, "time")) then
    delete(T_e@time)
  end if
  if (isvar("theta_e") .and. isatt(theta_e, "time")) then
    delete(theta_e@time)
  end if
  if (isvar("Td_e") .and. isatt(Td_e, "time")) then
    delete(Td_e@time)
  end if
  if (isvar("r_v_e") .and. isatt(r_v_e, "time")) then
    delete(r_v_e@time)
  end if
  if (isvar("q_e") .and. isatt(q_e, "time")) then
    delete(q_e@time)
  end if
  if (isvar("rh_e") .and. isatt(rh_e, "time")) then
    delete(rh_e@time)
  end if
  if (isvar("u_gr_e") .and. isatt(u_gr_e, "time")) then
    delete(u_gr_e@time)
  end if
  if (isvar("v_gr_e") .and. isatt(v_gr_e, "time")) then
    delete(v_gr_e@time)
  end if
  if (isvar("u_tr_e") .and. isatt(u_tr_e, "time")) then
    delete(u_tr_e@time)
  end if
  if (isvar("v_tr_e") .and. isatt(v_tr_e, "time")) then
    delete(v_tr_e@time)
  end if
  if (isvar("ws_e") .and. isatt(ws_e, "time")) then
    delete(ws_e@time)
  end if
  if (isvar("wd_e") .and. isatt(wd_e, "time")) then
    delete(wd_e@time)
  end if
  if (isvar("w_e") .and. isatt(w_e, "time")) then
    delete(w_e@time)
  end if
  if (isvar("pp_e") .and. isatt(pp_e, "time")) then
    delete(pp_e@time)
  end if
  if (isvar("r_cloud") .and. isatt(r_cloud, "time")) then
    delete(r_cloud@time)
  end if
  if (isvar("r_rain") .and. isatt(r_rain, "time")) then
    delete(r_rain@time)
  end if
  if (isvar("r_snow") .and. isatt(r_snow, "time")) then
    delete(r_snow@time)
  end if
  if (isvar("r_ice") .and. isatt(r_ice, "time")) then
    delete(r_ice@time)
  end if
  if (isvar("r_graup") .and. isatt(r_graup, "time")) then
    delete(r_graup@time)
  end if
  if (isvar("pvo_e") .and. isatt(pvo_e, "time")) then
    delete(pvo_e@time)
  end if
  if (isvar("avo_e") .and. isatt(avo_e, "time")) then
    delete(avo_e@time)
  end if
  if (isvar("o3_e") .and. isatt(o3_e, "time")) then
    delete(o3_e@time)
  end if
  if (isvar("AOD470_e") .and. isatt(AOD470_e, "time")) then
    delete(AOD470_e@time)
  end if
  if (isvar("AOD550_e") .and. isatt(AOD550_e, "time")) then
    delete(AOD550_e@time)
  end if
  if (isvar("AOD675_e") .and. isatt(AOD675_e, "time")) then
    delete(AOD675_e@time)
  end if
  if (isvar("PM2_5_DRY_e") .and. isatt(PM2_5_DRY_e, "time")) then
    delete(PM2_5_DRY_e@time)
  end if
  if (isvar("PM10_e") .and. isatt(PM10_e, "time")) then
    delete(PM10_e@time)
  end if
  if (isvar("co_e") .and. isatt(co_e, "time")) then
    delete(co_e@time)
  end if
  if (isvar("no2_e") .and. isatt(no2_e, "time")) then
    delete(no2_e@time)
  end if
  if (isvar("so2_e") .and. isatt(so2_e, "time")) then
    delete(so2_e@time)
  end if
  if (isvar("bc_a01_e") .and. isatt(bc_a01_e, "time")) then
    delete(bc_a01_e@time)
  end if
  if (isvar("bc_a02_e") .and. isatt(bc_a02_e, "time")) then
    delete(bc_a02_e@time)
  end if
  if (isvar("bc_a03_e") .and. isatt(bc_a03_e, "time")) then
    delete(bc_a03_e@time)
  end if
  if (isvar("bc_a04_e") .and. isatt(bc_a04_e, "time")) then
    delete(bc_a04_e@time)
  end if
  if (isvar("oc_a01_e") .and. isatt(oc_a01_e, "time")) then
    delete(oc_a01_e@time)
  end if
  if (isvar("oc_a02_e") .and. isatt(oc_a02_e, "time")) then
    delete(oc_a02_e@time)
  end if
  if (isvar("oc_a03_e") .and. isatt(oc_a03_e, "time")) then
    delete(oc_a03_e@time)
  end if
  if (isvar("oc_a04_e") .and. isatt(oc_a04_e, "time")) then
    delete(oc_a04_e@time)
  end if
  if (isvar("num_a01_e") .and. isatt(num_a01_e, "time")) then
    delete(num_a01_e@time)
  end if
  if (isvar("num_a02_e") .and. isatt(num_a02_e, "time")) then
    delete(num_a02_e@time)
  end if
  if (isvar("num_a03_e") .and. isatt(num_a03_e, "time")) then
    delete(num_a03_e@time)
  end if
  if (isvar("num_a04_e") .and. isatt(num_a04_e, "time")) then
    delete(num_a04_e@time)
  end if
  if (isvar("water_a01_e") .and. isatt(water_a01_e, "time")) then
    delete(water_a01_e@time)
  end if
  if (isvar("water_a02_e") .and. isatt(water_a02_e, "time")) then
    delete(water_a02_e@time)
  end if
  if (isvar("water_a03_e") .and. isatt(water_a03_e, "time")) then
    delete(water_a03_e@time)
  end if
  if (isvar("water_a04_e") .and. isatt(water_a04_e, "time")) then
    delete(water_a04_e@time)
  end if
  if (isvar("so4_a01_e") .and. isatt(so4_a01_e, "time")) then
    delete(so4_a01_e@time)
  end if
  if (isvar("so4_a02_e") .and. isatt(so4_a02_e, "time")) then
    delete(so4_a02_e@time)
  end if
  if (isvar("so4_a03_e") .and. isatt(so4_a03_e, "time")) then
    delete(so4_a03_e@time)
  end if
  if (isvar("so4_a04_e") .and. isatt(so4_a04_e, "time")) then
    delete(so4_a04_e@time)
  end if
  if (isvar("no3_a01_e") .and. isatt(no3_a01_e, "time")) then
    delete(no3_a01_e@time)
  end if
  if (isvar("no3_a02_e") .and. isatt(no3_a02_e, "time")) then
    delete(no3_a02_e@time)
  end if
  if (isvar("no3_a03_e") .and. isatt(no3_a03_e, "time")) then
    delete(no3_a03_e@time)
  end if
  if (isvar("no3_a04_e") .and. isatt(no3_a04_e, "time")) then
    delete(no3_a04_e@time)
  end if
  if (isvar("nh4_a01_e") .and. isatt(nh4_a01_e, "time")) then
    delete(nh4_a01_e@time)
  end if
  if (isvar("nh4_a02_e") .and. isatt(nh4_a02_e, "time")) then
    delete(nh4_a02_e@time)
  end if
  if (isvar("nh4_a03_e") .and. isatt(nh4_a03_e, "time")) then
    delete(nh4_a03_e@time)
  end if
  if (isvar("nh4_a04_e") .and. isatt(nh4_a04_e, "time")) then
    delete(nh4_a04_e@time)
  end if
  if (isvar("asoaX_a01_e") .and. isatt(asoaX_a01_e, "time")) then
    delete(asoaX_a01_e@time)
  end if
  if (isvar("asoaX_a02_e") .and. isatt(asoaX_a02_e, "time")) then
    delete(asoaX_a02_e@time)
  end if
  if (isvar("asoaX_a03_e") .and. isatt(asoaX_a03_e, "time")) then
    delete(asoaX_a03_e@time)
  end if
  if (isvar("asoaX_a04_e") .and. isatt(asoaX_a04_e, "time")) then
    delete(asoaX_a04_e@time)
  end if
  if (isvar("bsoaX_a01_e") .and. isatt(bsoaX_a01_e, "time")) then
    delete(bsoaX_a01_e@time)
  end if
  if (isvar("bsoaX_a02_e") .and. isatt(bsoaX_a02_e, "time")) then
    delete(bsoaX_a02_e@time)
  end if
  if (isvar("bsoaX_a03_e") .and. isatt(bsoaX_a03_e, "time")) then
    delete(bsoaX_a03_e@time)
  end if
  if (isvar("bsoaX_a04_e") .and. isatt(bsoaX_a04_e, "time")) then
    delete(bsoaX_a04_e@time)
  end if
  if (isvar("glysoa_sfc_a01_e") .and. isatt(glysoa_sfc_a01_e, "time")) then
    delete(glysoa_sfc_a01_e@time)
  end if
  if (isvar("glysoa_sfc_a02_e") .and. isatt(glysoa_sfc_a02_e, "time")) then
    delete(glysoa_sfc_a02_e@time)
  end if
  if (isvar("glysoa_sfc_a03_e") .and. isatt(glysoa_sfc_a03_e, "time")) then
    delete(glysoa_sfc_a03_e@time)
  end if
  if (isvar("glysoa_sfc_a04_e") .and. isatt(glysoa_sfc_a04_e, "time")) then
    delete(glysoa_sfc_a04_e@time)
  end if
  if (isvar("na_a01_e") .and. isatt(na_a01_e, "time")) then
    delete(na_a01_e@time)
  end if
  if (isvar("na_a02_e") .and. isatt(na_a02_e, "time")) then
    delete(na_a02_e@time)
  end if
  if (isvar("na_a03_e") .and. isatt(na_a03_e, "time")) then
    delete(na_a03_e@time)
  end if
  if (isvar("na_a04_e") .and. isatt(na_a04_e, "time")) then
    delete(na_a04_e@time)
  end if
  if (isvar("biog1_o_a01_e") .and. isatt(biog1_o_a01_e, "time")) then
    delete(biog1_o_a01_e@time)
  end if
  if (isvar("biog1_o_a02_e") .and. isatt(biog1_o_a02_e, "time")) then
    delete(biog1_o_a02_e@time)
  end if
  if (isvar("biog1_o_a03_e") .and. isatt(biog1_o_a03_e, "time")) then
    delete(biog1_o_a03_e@time)
  end if
  if (isvar("biog1_o_a04_e") .and. isatt(biog1_o_a04_e, "time")) then
    delete(biog1_o_a04_e@time)
  end if
  if (isvar("biog1_c_a01_e") .and. isatt(biog1_c_a01_e, "time")) then
    delete(biog1_c_a01_e@time)
  end if
  if (isvar("biog1_c_a02_e") .and. isatt(biog1_c_a02_e, "time")) then
    delete(biog1_c_a02_e@time)
  end if
  if (isvar("biog1_c_a03_e") .and. isatt(biog1_c_a03_e, "time")) then
    delete(biog1_c_a03_e@time)
  end if
  if (isvar("biog1_c_a04_e") .and. isatt(biog1_c_a04_e, "time")) then
    delete(biog1_c_a04_e@time)
  end if
  if (isvar("oin_a01_e") .and. isatt(oin_a01_e, "time")) then
    delete(oin_a01_e@time)
  end if
  if (isvar("oin_a02_e") .and. isatt(oin_a02_e, "time")) then
    delete(oin_a02_e@time)
  end if
  if (isvar("oin_a03_e") .and. isatt(oin_a03_e, "time")) then
    delete(oin_a03_e@time)
  end if
  if (isvar("oin_a04_e") .and. isatt(oin_a04_e, "time")) then
    delete(oin_a04_e@time)
  end if
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;check the limits for the output arrays, set 9999 to end of dataset
  if (limTime(1) .eq. 9999) then 
    limTime(1) = nTime-1
  end if
  if (limS_N(1) .eq. 9999) then 
    limS_N(1) = nS_N-1
  end if
  if (limW_E(1) .eq. 9999) then 
    limW_E(1) = nW_E-1
  end if
  if (outPressure) then
    if (limPres(1) .eq. 9999) then 
      limPres(1) = nPressure-1
    end if
  end if
  if (outEta) then
    if (limEta(1) .eq. 9999) then 
      limEta(1) = nEta-1
    end if
  end if
  if (outSoil) then
    if (limSoil(1) .eq. 9999) then 
      limSoil(1) = nSoil-1
    end if
  end if
  ;create filename and open post-processed netCDF file 
  if isfilepresent(dir_out+file_out) then
    system ("rm "+dir_out+file_out)             ;remove any pre-exisiting file
  end if
  wrfpost = addfile(dir_out+file_out,"c")    ;create new netCDF file
  filedimdef (wrfpost, "time", nTime, True)
  ; establish a variable for a new line in the attributes
  nl = integertochar(10)  ; newline character
  ; create the global attributes
  fileattdef(wrfpost, fileAtt)
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;; write post-processed WRF data to netCDF file ;;;;;;;;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  ; check to see if the output file is to follow CMIP guidelines
;  if (outCMIP .ne. True) then
    ;use standard wrfout_to_cf variable names in the wrfpost output file
    ; -date and time variables
    wrfpost->time=time(limTime(0):limTime(1))
    if (outDateTime) then
      wrfpost->DateTime=DateTime(limTime(0):limTime(1))
    end if
    if (outUTCDate) then
      wrfpost->year = year(limTime(0):limTime(1))
      wrfpost->month = month(limTime(0):limTime(1))
      wrfpost->day = day(limTime(0):limTime(1))
      wrfpost->hour = hour(limTime(0):limTime(1))
      wrfpost->minute = minute(limTime(0):limTime(1))
    end if
    ; -vertical coordinate variables
    if (outPressure) then
      wrfpost->pressure=pressure(limPres(0):limPres(1))
    end if
    if (outEta) then
      wrfpost->eta=eta(limEta(0):limEta(1))
    end if
    if (outSoil) then
      wrfpost->soil=soil(limSoil(0):limSoil(1))
    end if
    ; -one-dimensional coordinate variables
;   This inclusion of this section of output results in errors when using
;   NCL 6.0 and later.  Not certain as to why.
;    if (axis) then
;      wrfpost->south_north=south_north(limS_N(0):limS_N(1))
;      wrfpost->west_east=west_east(limW_E(0):limW_E(1))
;    end if
    ; -one-dimensional general model variables
    if (outPtop .or. outEta) then
      wrfpost->p_top=p_top
    end if
    ; -two-dimensional mapping variables
    wrfpost->lat=lat(limS_N(0):limS_N(1),limW_E(0):limW_E(1))
    wrfpost->lon=lon(limS_N(0):limS_N(1),limW_E(0):limW_E(1))
    wrfpost->Z_sfc=Z_sfc(limS_N(0):limS_N(1),limW_E(0):limW_E(1))
    ; -two-dimensional near-surface / surface met variables
    if (out2dMet) then
      if (isvar("SST")) then
        wrfpost->SST=SST(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                         limW_E(0):limW_E(1))
      end if
      if (isvar("T_sfc")) then
        wrfpost->T_sfc=T_sfc(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                             limW_E(0):limW_E(1))
      end if
      if (isvar("p_sfc")) then
        wrfpost->p_sfc=p_sfc(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                             limW_E(0):limW_E(1))
      end if
      if (isvar("slp") .and. isvar("slp_b")) then
        wrfpost->slp=slp(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                             limW_E(0):limW_E(1))
        wrfpost->slp_b=slp_b(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                             limW_E(0):limW_E(1))
      else
        if (isvar("slp")) then
          wrfpost->slp=slp(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                             limW_E(0):limW_E(1))
        end if
        if (isvar("slp_b")) then
          wrfpost->slp=slp_b(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                             limW_E(0):limW_E(1))
        end if
      end if
      if (isvar("T_2m")) then
        wrfpost->T_2m=T_2m(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
      if (isvar("theta_2m")) then
        wrfpost->theta_2m=theta_2m(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                             limW_E(0):limW_E(1))
      end if
      if (isvar("Td_2m")) then
        wrfpost->Td_2m=Td_2m(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                             limW_E(0):limW_E(1))
      end if
      if (isvar("r_v_2m")) then
        wrfpost->r_v_2m=r_v_2m(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
      if (isvar("q_2m")) then
        wrfpost->q_2m=q_2m(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
      if (isvar("rh_2m")) then
        wrfpost->rh_2m=rh_2m(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
      if (isvar("u_10m_gr")) then
        wrfpost->u_10m_gr=u_10m_gr(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                   limW_E(0):limW_E(1))
      end if
      if (isvar("v_10m_gr")) then
        wrfpost->v_10m_gr=v_10m_gr(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                   limW_E(0):limW_E(1))
      end if
      if (isvar("u_10m_tr")) then
        wrfpost->u_10m_tr=u_10m_tr(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                   limW_E(0):limW_E(1))
      end if
      if (isvar("v_10m_tr")) then
        wrfpost->v_10m_tr=v_10m_tr(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                   limW_E(0):limW_E(1))
      end if
      if (isvar("ws_10m")) then
        wrfpost->ws_10m=ws_10m(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                   limW_E(0):limW_E(1))
      end if
      if (isvar("wd_10m")) then
        wrfpost->wd_10m=wd_10m(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                   limW_E(0):limW_E(1))
      end if
      if (isvar("precip_g")) then
        wrfpost->precip_g=precip_g(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                   limW_E(0):limW_E(1))
      end if
      if (isvar("precip_c")) then
        wrfpost->precip_c=precip_c(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                   limW_E(0):limW_E(1))
      end if
      if (isvar("precip_fr")) then
        wrfpost->precip_fr=precip_fr(limTime(0):limTime(1),limS_N(0):limS_N(1),\
                           limW_E(0):limW_E(1))
      end if
      if (isvar("dryairmass")) then
        wrfpost->dryairmass=dryairmass(limTime(0):limTime(1), \
                                       limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("pblh")) then
        wrfpost->pblh=pblh(limTime(0):limTime(1),limS_N(0):limS_N(1), \
                           limW_E(0):limW_E(1))
      end if
      if (isvar("rho")) then
        wrfpost->rho=rho(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
    end if
    ; -three-dimensional upper-level (eta) meteorology variables
    if (outEta) then
      if (isvar("p_e") .and. (outEta@p_e)) then
        wrfpost->p_e=p_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("Z_e") .and. (outEta@Z_e)) then
        wrfpost->Z_e=Z_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("T_e") .and. (outEta@T_e)) then
        wrfpost->T_e=T_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("theta_e") .and. (outEta@theta_e)) then
        wrfpost->theta_e=theta_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("Td_e") .and. (outEta@Td_e)) then
        wrfpost->Td_e=Td_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                           limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("r_v_e") .and. (outEta@r_v_e)) then
        wrfpost->r_v_e=r_v_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                                 limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("q_e") .and. (outEta@q_e)) then
        wrfpost->q_e=q_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("rh_e") .and. (outEta@rh_e)) then
        wrfpost->rh_e=rh_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                           limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("u_gr_e") .and. (outEta@u_gr_e)) then
        wrfpost->u_gr_e=u_gr_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                               limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("v_gr_e") .and. (outEta@v_gr_e)) then
        wrfpost->v_gr_e=v_gr_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                               limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("u_tr_e") .and. (outEta@u_tr_e)) then
        wrfpost->u_tr_e=u_tr_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                               limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("v_tr_e") .and. (outEta@v_tr_e)) then
        wrfpost->v_tr_e=v_tr_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                               limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("ws_e") .and. (outEta@ws_e)) then
        wrfpost->ws_e=ws_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                               limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("wd_e") .and. (outEta@wd_e)) then
        wrfpost->wd_e=wd_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                               limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("w_e") .and. (outEta@w_e)) then
        wrfpost->w_e=w_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("pp_e") .and. (outEta@pp_e)) then
        wrfpost->pp_e=pp_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("r_cloud") .and. (outEta@r_cloud)) then
        wrfpost->r_cloud=r_cloud(limTime(0):limTime(1),limEta(0):limEta(1),  \
                                 limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("r_rain") .and. (outEta@r_rain)) then
        wrfpost->r_rain=r_rain(limTime(0):limTime(1),limEta(0):limEta(1),  \
                               limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("r_ice") .and. (outEta@r_ice)) then
        wrfpost->r_ice=r_ice(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("r_snow") .and. (outEta@r_snow)) then
        wrfpost->r_snow=r_snow(limTime(0):limTime(1),limEta(0):limEta(1),  \
                               limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("r_graup") .and. (outEta@r_graup)) then
        wrfpost->r_graup=r_graup(limTime(0):limTime(1),limEta(0):limEta(1),  \
                                 limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("pvo_e") .and. (outEta@pvo_e)) then
        wrfpost->pvo_e=pvo_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("avo_e") .and. (outEta@avo_e)) then
        wrfpost->avo_e=avo_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("o3_e") .and. (outEta@o3_e)) then
        wrfpost->o3_e=o3_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("AOD470_e") .and. (outEta@AOD470_e)) then
        wrfpost->AOD470_e=AOD470_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("AOD550_e") .and. (outEta@AOD550_e)) then
        wrfpost->AOD550_e=AOD550_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("AOD675_e") .and. (outEta@AOD675_e)) then
        wrfpost->AOD675_e=AOD675_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("PM2_5_DRY_e") .and. (outEta@PM2_5_DRY_e)) then
        wrfpost->PM2_5_DRY_e=PM2_5_DRY_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("PM10_e") .and. (outEta@PM10_e)) then
        wrfpost->PM10_e=PM10_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("co_e") .and. (outEta@co_e)) then
        wrfpost->co_e=co_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("no2_e") .and. (outEta@no2_e)) then
        wrfpost->no2_e=no2_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("so2_e") .and. (outEta@so2_e)) then
        wrfpost->so2_e=so2_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if            
      if (isvar("bc_a01_e") .and. (outEta@bc_a01_e)) then
        wrfpost->bc_a01_e=bc_a01_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("bc_a02_e") .and. (outEta@bc_a02_e)) then
        wrfpost->bc_a02_e=bc_a02_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("bc_a03_e") .and. (outEta@bc_a03_e)) then
        wrfpost->bc_a03_e=bc_a03_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("bc_a04_e") .and. (outEta@bc_a04_e)) then
        wrfpost->bc_a04_e=bc_a04_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("oc_a01_e") .and. (outEta@oc_a01_e)) then
        wrfpost->oc_a01_e=oc_a01_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("oc_a02_e") .and. (outEta@oc_a02_e)) then
        wrfpost->oc_a02_e=oc_a02_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("oc_a03_e") .and. (outEta@oc_a03_e)) then
        wrfpost->oc_a03_e=oc_a03_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("oc_a04_e") .and. (outEta@oc_a04_e)) then
        wrfpost->oc_a04_e=oc_a04_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("num_a01_e") .and. (outEta@num_a01_e)) then
        wrfpost->num_a01_e=num_a01_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("num_a02_e") .and. (outEta@num_a02_e)) then
        wrfpost->num_a02_e=num_a02_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("num_a03_e") .and. (outEta@num_a03_e)) then
        wrfpost->num_a03_e=num_a03_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("num_a04_e") .and. (outEta@num_a04_e)) then
        wrfpost->num_a04_e=num_a04_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("water_a01_e") .and. (outEta@water_a01_e)) then
        wrfpost->water_a01_e=water_a01_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("water_a02_e") .and. (outEta@water_a02_e)) then
        wrfpost->water_a02_e=water_a02_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("water_a03_e") .and. (outEta@water_a03_e)) then
        wrfpost->water_a03_e=water_a03_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("water_a04_e") .and. (outEta@water_a04_e)) then
        wrfpost->water_a04_e=water_a04_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("so4_a01_e") .and. (outEta@so4_a01_e)) then
        wrfpost->so4_a01_e=so4_a01_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("so4_a02_e") .and. (outEta@so4_a02_e)) then
        wrfpost->so4_a02_e=so4_a02_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("so4_a03_e") .and. (outEta@so4_a03_e)) then
        wrfpost->so4_a03_e=so4_a03_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("so4_a04_e") .and. (outEta@so4_a04_e)) then
        wrfpost->so4_a04_e=so4_a04_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("no3_a01_e") .and. (outEta@no3_a01_e)) then
        wrfpost->no3_a01_e=no3_a01_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("no3_a02_e") .and. (outEta@no3_a02_e)) then
        wrfpost->no3_a02_e=no3_a02_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("no3_a03_e") .and. (outEta@no3_a03_e)) then
        wrfpost->no3_a03_e=no3_a03_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("no3_a04_e") .and. (outEta@no3_a04_e)) then
        wrfpost->no3_a04_e=no3_a04_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("nh4_a01_e") .and. (outEta@nh4_a01_e)) then
        wrfpost->nh4_a01_e=nh4_a01_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("nh4_a02_e") .and. (outEta@nh4_a02_e)) then
        wrfpost->nh4_a02_e=nh4_a02_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("nh4_a03_e") .and. (outEta@nh4_a03_e)) then
        wrfpost->nh4_a03_e=nh4_a03_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("nh4_a04_e") .and. (outEta@nh4_a04_e)) then
        wrfpost->nh4_a04_e=nh4_a04_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("asoaX_a01_e") .and. (outEta@asoaX_a01_e)) then
        wrfpost->asoaX_a01_e=asoaX_a01_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("asoaX_a02_e") .and. (outEta@asoaX_a02_e)) then
        wrfpost->asoaX_a02_e=asoaX_a02_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("asoaX_a03_e") .and. (outEta@asoaX_a03_e)) then
        wrfpost->asoaX_a03_e=asoaX_a03_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("asoaX_a04_e") .and. (outEta@asoaX_a04_e)) then
        wrfpost->asoaX_a04_e=asoaX_a04_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("bsoaX_a01_e") .and. (outEta@bsoaX_a01_e)) then
        wrfpost->bsoaX_a01_e=bsoaX_a01_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("bsoaX_a02_e") .and. (outEta@bsoaX_a02_e)) then
        wrfpost->bsoaX_a02_e=bsoaX_a02_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("bsoaX_a03_e") .and. (outEta@bsoaX_a03_e)) then
        wrfpost->bsoaX_a03_e=bsoaX_a03_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("bsoaX_a04_e") .and. (outEta@bsoaX_a04_e)) then
        wrfpost->bsoaX_a04_e=bsoaX_a04_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("glysoa_sfc_a01_e") .and. (outEta@glysoa_sfc_a01_e)) then
        wrfpost->glysoa_sfc_a01_e=glysoa_sfc_a01_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("glysoa_sfc_a02_e") .and. (outEta@glysoa_sfc_a02_e)) then
        wrfpost->glysoa_sfc_a02_e=glysoa_sfc_a02_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("glysoa_sfc_a03_e") .and. (outEta@glysoa_sfc_a03_e)) then
        wrfpost->glysoa_sfc_a03_e=glysoa_sfc_a03_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("glysoa_sfc_a04_e") .and. (outEta@glysoa_sfc_a04_e)) then
        wrfpost->glysoa_sfc_a04_e=glysoa_sfc_a04_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("na_a01_e") .and. (outEta@na_a01_e)) then
        wrfpost->na_a01_e=na_a01_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("na_a02_e") .and. (outEta@na_a02_e)) then
        wrfpost->na_a02_e=na_a02_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("na_a03_e") .and. (outEta@na_a03_e)) then
        wrfpost->na_a03_e=na_a03_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("na_a04_e") .and. (outEta@na_a04_e)) then
        wrfpost->na_a04_e=na_a04_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("biog1_o_a01_e") .and. (outEta@biog1_o_a01_e)) then
        wrfpost->biog1_o_a01_e=biog1_o_a01_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("biog1_o_a02_e") .and. (outEta@biog1_o_a02_e)) then
        wrfpost->biog1_o_a02_e=biog1_o_a02_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("biog1_o_a03_e") .and. (outEta@biog1_o_a03_e)) then
        wrfpost->biog1_o_a03_e=biog1_o_a03_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("biog1_o_a04_e") .and. (outEta@biog1_o_a04_e)) then
        wrfpost->biog1_o_a04_e=biog1_o_a04_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("biog1_c_a01_e") .and. (outEta@biog1_c_a01_e)) then
        wrfpost->biog1_c_a01_e=biog1_c_a01_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("biog1_c_a02_e") .and. (outEta@biog1_c_a02_e)) then
        wrfpost->biog1_c_a02_e=biog1_c_a02_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("biog1_c_a03_e") .and. (outEta@biog1_c_a03_e)) then
        wrfpost->biog1_c_a03_e=biog1_c_a03_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("biog1_c_a04_e") .and. (outEta@biog1_c_a04_e)) then
        wrfpost->biog1_c_a04_e=biog1_c_a04_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("oin_a01_e") .and. (outEta@oin_a01_e)) then
        wrfpost->oin_a01_e=oin_a01_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("oin_a02_e") .and. (outEta@oin_a02_e)) then
        wrfpost->oin_a02_e=oin_a02_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("oin_a03_e") .and. (outEta@oin_a03_e)) then
        wrfpost->oin_a03_e=oin_a03_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("oin_a04_e") .and. (outEta@oin_a04_e)) then
        wrfpost->oin_a04_e=oin_a04_e(limTime(0):limTime(1),limEta(0):limEta(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
    end if
    ; -three-dimensional upper-level (pressure) meteorology variables
    if (outPressure) then
      if (isvar("Z_p")) then
        wrfpost->Z_p=Z_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("T_p")) then
        wrfpost->T_p=T_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("theta_p")) then
        wrfpost->theta_p=theta_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("Td_p")) then
        wrfpost->Td_p=Td_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                           limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("r_v_p")) then
        wrfpost->r_v_p=r_v_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("q_p")) then
        wrfpost->q_p=q_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("rh_p")) then
        wrfpost->rh_p=rh_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                           limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("u_gr_p")) then
        wrfpost->u_gr_p=u_gr_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                               limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("v_gr_p")) then
        wrfpost->v_gr_p=v_gr_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                               limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("u_tr_p")) then
        wrfpost->u_tr_p=u_tr_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                               limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("v_tr_p")) then
        wrfpost->v_tr_p=v_tr_p(limTime(0):limTime(1),limPres(0):limPres(1),   \
                               limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("ws_p")) then
        wrfpost->ws_p=ws_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                               limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("wd_p")) then
        wrfpost->wd_p=wd_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                               limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("w_p")) then
        wrfpost->w_p=w_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("pp_p")) then
        wrfpost->pp_p=pp_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                           limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("r_cloud_p")) then
        wrfpost->r_cloud_p=r_cloud_p(limTime(0):limTime(1),  \
                                     limPres(0):limPres(1),  \
                                     limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("r_rain_p")) then
        wrfpost->r_rain_p=r_rain_p(limTime(0):limTime(1),limPres(0):limPres(1),\
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("r_ice_p")) then
        wrfpost->r_ice_p=r_ice_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("r_snow_p")) then
        wrfpost->r_snow_p=r_snow_p(limTime(0):limTime(1),limPres(0):limPres(1),\
                         limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("r_graupel_p")) then
        wrfpost->r_graupel_p=r_graupel_p(limTime(0):limTime(1),  \
                                       limPres(0):limPres(1),  \
                                       limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("pvo_p")) then
        wrfpost->pvo_p=pvo_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("avo_p")) then
        wrfpost->avo_p=avo_p(limTime(0):limTime(1),limPres(0):limPres(1),  \
                             limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
    end if
    ; -two-dimensional surface energy budget / radiation variables
    if (out2dRadFlx) then
      if (isvar("SW_d")) then
        wrfpost->SW_d=SW_d(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
      if (isvar("LW_d")) then
        wrfpost->LW_d=LW_d(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
      if (isvar("SW_u")) then
        wrfpost->SW_u=SW_u(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
      if (isvar("LW_u")) then
        wrfpost->LW_u=LW_u(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
      if isvar("LW_u_toa") then
        wrfpost->LW_u_toa=LW_u_toa(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                               limW_E(0):limW_E(1))
      end if
      if (isvar("SW_d_acc")) then
        wrfpost->SW_d_acc=SW_d_acc(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
      if (isvar("LW_d_acc")) then
        wrfpost->LW_d_acc=LW_d_acc(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
      if (isvar("SW_u_acc")) then
        wrfpost->SW_u_acc=SW_u_acc(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
      if (isvar("LW_u_acc")) then
        wrfpost->LW_u_acc=LW_u_acc(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
      if (isvar("SW_d_toa_acc")) then
        wrfpost->SW_d_toa_acc=SW_d_toa_acc(limTime(0):limTime(1),  \
                           limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("LW_d_toa_acc")) then
        wrfpost->LW_d_toa_acc=LW_d_toa_acc(limTime(0):limTime(1),  \
                           limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("SW_u_toa_acc")) then
        wrfpost->SW_u_toa_acc=SW_u_toa_acc(limTime(0):limTime(1),  \
                           limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("LW_u_toa_acc")) then
        wrfpost->LW_u_toa_acc=LW_u_toa_acc(limTime(0):limTime(1),  \
                           limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("albedo")) then
        wrfpost->albedo=albedo(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                               limW_E(0):limW_E(1))
      end if
      if (isvar("emiss_sfc")) then
        wrfpost->emiss_sfc=emiss_sfc(limTime(0):limTime(1),limS_N(0):limS_N(1),\
                                     limW_E(0):limW_E(1))
      end if
      if (isvar("SH")) then
        wrfpost->SH=SH(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                             limW_E(0):limW_E(1))
      end if
      if (isvar("LH")) then
        wrfpost->LH=LH(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                             limW_E(0):limW_E(1))
      end if
      if (isvar("SH_acc")) then
        wrfpost->SH_acc=SH_acc(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                             limW_E(0):limW_E(1))
      end if
      if (isvar("LH_acc")) then
        wrfpost->LH_acc=LH_acc(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                             limW_E(0):limW_E(1))
      end if
      if (isvar("MH")) then
        wrfpost->MH=MH(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
      if isvar("u_star") then
        wrfpost->u_star=u_star(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                               limW_E(0):limW_E(1))
      end if
      if (isvar("LWP") .and. (out2dRadFlx@LWP)) then
        wrfpost->LWP=LWP(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
      if (isvar("IWP") .and. (out2dRadFlx@IWP)) then
        wrfpost->IWP=IWP(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                           limW_E(0):limW_E(1))
      end if
    end if
    ; -two-dimensional surface / soil variables
    if (out2dLandSoil) then
      if (isvar("LandMask")) then
        wrfpost->LandMask=LandMask(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                   limW_E(0):limW_E(1))
      end if
      if (isvar("LandUse")) then
        wrfpost->LandUse=LandUse(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                 limW_E(0):limW_E(1))
      end if
      if (isvar("SoilT_L")) then
        wrfpost->SoilT_L=SoilT_L(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                 limW_E(0):limW_E(1))
      end if
      if isvar("SoilT_B") then
        wrfpost->SoilT_B=SoilT_B(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                 limW_E(0):limW_E(1))
      end if
      if (isvar("GroundFlx")) then
        wrfpost->GroundFlx=GroundFlx(limTime(0):limTime(1),limS_N(0):limS_N(1),\
                                     limW_E(0):limW_E(1))
      end if
      if (isvar("SnowHgt")) then
        wrfpost->SnowHgt=SnowHgt(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                 limW_E(0):limW_E(1))
      end if
      if (isvar("SnowWater")) then
        wrfpost->SnowWater=SnowWater(limTime(0):limTime(1),limS_N(0):limS_N(1),\
                                     limW_E(0):limW_E(1))
      end if
      if isvar("SnowDens") then
        wrfpost->SnowDens=SnowDens(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                   limW_E(0):limW_E(1))
      end if
      if isvar("SnowFlx") then
        wrfpost->SnowFlx=SnowFlx(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                                 limW_E(0):limW_E(1))
      end if
      if (isvar("SnowMelt")) then
        wrfpost->SnowMelt=SnowMelt(limTime(0):limTime(1),limS_N(0):limS_N(1), \
                           limW_E(0):limW_E(1))
      end if
      if isvar("SeaIce") then
        wrfpost->SeaIce=SeaIce(limTime(0):limTime(1),limS_N(0):limS_N(1),  \
                               limW_E(0):limW_E(1))
      end if
      if (isvar("WaterFlx")) then
        wrfpost->WaterFlx=WaterFlx(limTime(0):limTime(1),limS_N(0):limS_N(1), \
                           limW_E(0):limW_E(1))
      end if
      if (isvar("SfcRunoff")) then
        wrfpost->SfcRunoff=SfcRunoff(limTime(0):limTime(1),limS_N(0):limS_N(1),\
                           limW_E(0):limW_E(1))
      end if  
      if (isvar("SubRunoff")) then
        wrfpost->SubRunoff=SubRunoff(limTime(0):limTime(1),limS_N(0):limS_N(1),\
                           limW_E(0):limW_E(1))
      end if
      if (isvar("SoilMoist")) then
        wrfpost->SoilMoist=SoilMoist(limTime(0):limTime(1),limS_N(0):limS_N(1),\
                           limW_E(0):limW_E(1))
      end if
      if (isvar("AOD470_sfc")) then
        wrfpost->AOD470_sfc=AOD470_sfc(limTime(0):limTime(1),limS_N(0):limS_N(1),\
                           limW_E(0):limW_E(1))
      end if
      if (isvar("AOD550_sfc")) then
        wrfpost->AOD550_sfc=AOD550_sfc(limTime(0):limTime(1),limS_N(0):limS_N(1),\
                           limW_E(0):limW_E(1))
      end if
      if (isvar("AOD675_sfc")) then
        wrfpost->AOD675_sfc=AOD675_sfc(limTime(0):limTime(1),limS_N(0):limS_N(1),\
                           limW_E(0):limW_E(1))
      end if
    end if
    ; -three-dimensional soil variables
    if (outSoil) then
      if (isvar("SoilTemp")) then
        wrfpost->SoilTemp=SoilTemp(limTime(0):limTime(1),  \
                                   limSoil(0):limSoil(1),  \
                                   limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("SoilMoist")) then
       wrfpost->SoilMoist=SoilMoist(limTime(0):limTime(1),  \
                                    limSoil(0):limSoil(1),  \
                                    limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if isvar("SoilWater") then
       wrfpost->SoilWater=SoilWater(limTime(0):limTime(1),  \
                                    limSoil(0):limSoil(1),  \
                                    limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
    end if
    ; -two-dimensional CLimate WRF (CLWRF)
    if (outCLWRF) then
      if (isvar("T_sfc_min")) then
        wrfpost->T_sfc_min=T_sfc_min(limTime(0):limTime(1),  \
                                     limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("T_sfc_max")) then
        wrfpost->T_sfc_max=T_sfc_max(limTime(0):limTime(1),  \
                                     limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if    
      if (isvar("T_sfc_mean")) then
        wrfpost->T_sfc_mean=T_sfc_mean(limTime(0):limTime(1),  \
                                       limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if    
      if (isvar("T_sfc_std")) then
        wrfpost->T_sfc_std=T_sfc_std(limTime(0):limTime(1),  \
                                     limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("T_2m_min")) then
        wrfpost->T_2m_min=T_2m_min(limTime(0):limTime(1),  \
                                   limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("T_2m_max")) then
        wrfpost->T_2m_max=T_2m_max(limTime(0):limTime(1),  \
                                   limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if    
      if (isvar("T_2m_mean")) then
        wrfpost->T_2m_mean=T_2m_mean(limTime(0):limTime(1),  \
                                     limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if    
      if (isvar("T_2m_std")) then
        wrfpost->T_2m_std=T_2m_std(limTime(0):limTime(1),  \
                                   limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("q_2m_min")) then
        wrfpost->q_2m_min=q_2m_min(limTime(0):limTime(1),  \
                                   limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
      if (isvar("q_2m_max")) then
        wrfpost->q_2m_max=q_2m_max(limTime(0):limTime(1),  \
                                   limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if    
      if (isvar("q_2m_mean")) then
        wrfpost->q_2m_mean=q_2m_mean(limTime(0):limTime(1),  \
                                     limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if    
      if (isvar("T_2m_std")) then
        wrfpost->q_2m_std=q_2m_std(limTime(0):limTime(1),  \
                                   limS_N(0):limS_N(1),limW_E(0):limW_E(1))
      end if
    end if
;  end if
;  ; check to see if the output file is to follow CMIP guidelines
;  if (outCMIP .eq. True) then
;
;  end if
end 
