### How to add the `bbinjectscheme` options to WRFChem

#### Steps
1. `Registry/registry.chem`  
    a. Include `bbinjectscheme` flag within `registry.chem` to enable injection scheme switching using this chemistry namelist flag. Add the following code within the chemistry scheme declaration section with the other namelist flags, previously used line 3825:  
    ```fortran
    rconfig   integer     bbinjectscheme      namelist,chem          max_domains    4       rh    "bbinjectscheme"      ""      ""
    ```

2. `chem/chem_driver.F`  
    a. Include `grid%kpbl` within the `emissions_driver` call to indicate the model level containing the top of boundary layer. Add the following code to line 879, underneath `grid%dust_flux, grid%seas_flux,`:  
    ```fortran
             ! bbinjectscheme requires record of layer which PBL goes up to
                  grid%kpbl,                                                                   & 
    ```

3. `chem/emissions_driver.F`  
    a. Insert `lpbl` to the interface for `emissions_driver` in the same position as `grid%kpbl` is in `chem_driver.F`. Add the following code to line 74, underneath `dust_flux, seas_flux,`:  
    ```fortran
         ! bbinjectscheme requires record of layer which PBL goes up to
         lpbl,                                                             &
    ```

    b. Declare `lpbl` as an integer. Add the following code to line 336, underneath `end stuff for lightning NOx`:  
    ```fortran
    ! bbinjectscheme requires record of boundary layer maximum level  
        INTEGER,  DIMENSION( ims:ime , jms:jme ) , INTENT(in) :: lpbl  
    ```

    c. Insert `lpbl` to `do_plumerisefire`. Add the following code to line 672, underneath `emis_ant,z_at_w,z,config_flags%scale_fire_emiss,`:  
    ```fortran
               lpbl,                                                           &
    ```

4. `chem/module_plumerise1.F`  
    a. Insert `lpbl` to the `plumerise_driver` in the same position as it is in `emissions_driver.F`. Add the following code to line 29, underneath `emis_ant,z_at_w,z,scale_fire_emiss,`:  
    ```fortran
               lpbl,                                              &           
    ```  

    b. Declare `lpbl` as an integer. Add the following code to line 53, underneath `its,ite, jts,jte, kts,kte`:  
    ```fortran
    ! bbinjectscheme requires record of boundary layer maximum level  
       INTEGER,  DIMENSION( ims:ime , jms:jme ) , INTENT(in) :: lpbl  
    ```

    c. Insert the conditionals which control the different injection options. Add the following code to line 251, underneath `if( maxval( eburn_in(:) ) == 0. ) cycle`:  
    ```fortran
    !++ SAN, 2015-04-08: adding namelist option to turn on/off plumerise calculations
               if(config_flags%bbinjectscheme > 0) then

                 ! If we are not using the plumerise routine then we need to make sure
                 ! we deal with all emissions, not just the smouldering emissions at 
                 ! level 1.

                 !!!!!! scale_fire_emiss = .false. !!!!!!!!
                 ! 3BEM emissions contain only the smouldering emissions, so we need to
                 ! determine the amount of flaming emissions, and distribute that as directed.

                 !!!!!! scale_fire_emiss = .true.  !!!!!!!!!
                 ! FINN (and other emissions?) contain the whole set of emissions, so
                 ! we already have the total emissions input. What we will do here is 
                 ! calculate what the flaming and smouldering emissions parts of this are,
                 ! separate them out, and then process the flaming emissions in the same
                 ! manner as above.
                 !
                 ! This will mean that we don't need to use the code after the plumerise
                 ! call which rescales the emissions once they have been generated.
                 if(scale_fire_emiss == .false.) then

                    ! calculate what the flaming emissions should be
                    do nv=1,num_ebu
                        ebu_sum(nv) = ebu(i,kts,j,nv) *     &
                                        (mean_fct(1) + mean_fct(2) + mean_fct(3) + mean_fct(4))
                    enddo

                 else  !! need to account for scaling of fire emissions

                    !! calculate the fraction of full emissions that should be flaming emissions
                    !! emiss_frac = (mean_fct(1) + mean_fct(2) + mean_fct(3) + mean_fct(4)) / & !*** CHANGE ****
                    !!						(1 + mean_fct(1) + mean_fct(2) + mean_fct(3) + mean_fct(4)) !*** CHANGE ****
                    emiss_frac = 1.0  !*** CHANGE ****
                    do nv=1,num_ebu
                        !! calculate the amount of flaming emissions, to use in calculations below
                        ebu_sum(nv) = ebu(i,kts,j,nv) * emiss_frac
                        !! replace emission amount at ground level with proper smouldering emissions
                        ebu(i,kts,j,nv) = ebu(i,kts,j,nv) * (1.0 - emiss_frac)
                    end do

                 end if ! check for scale_fire_emiss


                    !! DL (23/7/2015) Modify the biomass burning injection heights
                    !! DL (13/5/2016)  adding options 3 & 4
                    !!   bbinjectscheme:      
                    !!			1 = all emissions go in at ground level
                    !!			2 = flaming emissions are distributed evenly through the boundary layer
                    !!          3 = flaming emissions are injected at the top of the boundary layer
                    !!          4 = flaming emissions are injected at a predetermined height


                    !!! option 1
                    if(config_flags%bbinjectscheme == 1)then ! everything goes into the bottom level 
                        do nv=1,num_ebu
                            ebu(i,kts,j,nv) = ebu(i,kts,j,nv) + ebu_sum(nv)
                        enddo					

                    !!! option 2
                    else if(config_flags%bbinjectscheme == 2 .and. lpbl(i,j) == kts )then ! everything goes into the bottom level (as PBL very low)
                        do nv=1,num_ebu
                            ebu(i,kts,j,nv) = ebu(i,kts,j,nv) + ebu_sum(nv) !*** CHANGE ****
                                                    !!ebu(i,kts,j,nv) = ebu(i,kts,j,nv)                !*** CHANGE ****
                        enddo					
                    else if(config_flags%bbinjectscheme == 2 .and. lpbl(i,j) > kts )then ! distribute flaming emissions through the PBL
                        ! determine division of emissions through PBL
                        !   1) get full depth of PBL (minus the depth of lowest model layer)
                        !              z_at_w is the height of the lower boundary of a model layer,
                        !              so to get top of the PBL layer we have to use the bottom of the layer above
                        !! pbl_depth = z_at_w(i,lpbl(i,j)+1,j) - z_at_w(i,kts+1,j) !*** CHANGE ****
                                            pbl_depth = z_at_w(i,lpbl(i,j)+1,j) - z_at_w(i,kts,j)    !*** CHANGE **** To get full depth including depth of lowest layer, not minus lowest layer

                        ! loop through layers of the PBL
                        !! do k=kts+1,lpbl(i,j) !*** CHANGE ****
                                            do k=kts,lpbl(i,j)   !*** CHANGE **** include loop from lowest layer
                            !   2) calculate the fraction of this height that each layer is
                            flame_frac = (z_at_w(i,k+1,j) - z_at_w(i,k,j)) / pbl_depth


                            !   3) multiple flaming emission total by this fraction to get injection into layer
                            do nv=1,num_ebu
                                ebu(i,k,j,nv) = ebu_sum(nv) * flame_frac !*** CHANGE ****
                                                            !!ebu(i,k,j,nv) = ebu(i,k,j,nv) * flame_frac  !*** CHANGE ****
                            end do				
                        end do

                    !!! option 3
                    else if(config_flags%bbinjectscheme == 3 )then ! insert flaming emissions in the PBL model level (doesn't matter where this is)

                        do nv=1,num_ebu
                            ebu(i,lpbl(i,j),j,nv) = ebu(i,lpbl(i,j),j,nv) + ebu_sum(nv)
                        enddo					


                    !!! option 4
    !				else if(config_flags%bbinjectscheme == 4 )then ! insert flaming emissions at a predetermined height
    !
    !					do nv=1,num_ebu
    !						ebu(i,lpbl(i,j),j,nv) = ebu(i,lpbl(i,j),j,nv) + ebu_sum(nv)
    !					enddo					


                    else
                        call wrf_error_fatal("bbinjectscheme setting is unsupported - check your config file")
                    end if



               else 
    !-- SAN. Only do following calculations if plumerise is on:
    ```

    d. End the conditional. Add the following code to line 544, underneath `end if has_total_emissions`:  
    ```fortran
    !++ SAN, 2015-04-08
                endif ! plumerise_off
    !-- SAN
    ```

5. `WRFotron/namelist.chem/blueprint`  
    a. Define the `bbinjectscheme` setting in `namelist.chem.blueprint`. Add the following line to the bottom of the namelist:  
    ```fortran
     bbinjectscheme                      = 2, 2, 2,                   ! 0 = use plume rise under biomass_burn_opt, 1 = all ground level, 2 = flaming evenly in BL (recommened), 3 = flaming injected top of BL, 4 = flaming injected at specific height
    ```

6. [Recompile](https://github.com/wrfchem-leeds/WRFotron/blob/master/WRFotron_user_guide.md#compile)  

