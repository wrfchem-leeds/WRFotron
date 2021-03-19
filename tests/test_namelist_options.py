import os
import glob
import re

path = os.getcwd()
run_folders = glob.glob(f'{path[:-12]}/run/base/2*')


def test_cldchem_chemopt202():
    for run_folder in run_folders:
        with open(f'{run_folder}/config.bash') as lines:
            for line in lines:
                if 'WRFdir' in line:
                    wrfchem_folder = line.split('=')[1].split('\n')[0]

        cldchem_conditional_set_correctly = False
        with open(f'{wrfchem_folder}/chem/chemics_init.F') as lines:
            for line_number, line in enumerate(lines):
                if 'config_flags%cldchem_onoff == 1' in line:
                    min_line_number_to_search = line_number
                    max_line_number_to_search = line_number + 10

                try:
                    if line_number >= min_line_number_to_search and line_number <= max_line_number_to_search:
                        if 'config_flags%chem_opt == 202' in line or 'config_flags%chem_opt == MOZART_MOSAIC_4BIN_AQ_KPP' in line:
                            cldchem_conditional_set_correctly = True
                except:
                    UnboundLocalError()

        assert cldchem_conditional_set_correctly


def test_n2o5_hetchem_chemopt202():
    for run_folder in run_folders:
        with open(f'{run_folder}/config.bash') as lines:
            for line in lines:
                if 'WRFdir' in line:
                    wrfchem_folder = line.split('=')[1].split('\n')[0]

        n2o5_hetchem_conditional_set_correctly = False
        with open(f'{wrfchem_folder}/chem/chemics_init.F') as lines:
            for line_number, line in enumerate(lines):
                if 'config_flags%n2o5_hetchem == 1' in line:
                    min_line_number_to_search = line_number
                    max_line_number_to_search = line_number + 10

                try:
                    if line_number >= min_line_number_to_search and line_number <= max_line_number_to_search:
                        if 'config_flags%chem_opt == 202' in line or 'config_flags%chem_opt == MOZART_MOSAIC_4BIN_AQ_KPP' in line:
                            n2o5_hetchem_conditional_set_correctly = True
                except:
                    UnboundLocalError()

        assert n2o5_hetchem_conditional_set_correctly


def test_equal_timesteps():
    for run_folder in run_folders:
        with open(f'{run_folder}/namelist.input') as lines:
            for line in lines:
                if 'time_step' in line and 'meteorology' in line:
                    timestep_meteo = float(re.findall(r"\d+", line)[0])
                elif 'chemdt' in line:
                    timestep_chem = float(re.findall(r"\d+", line)[0])
                elif 'bioemdt' in line:
                    timestep_bio = float(re.findall(r"\d+", line)[0])

        # change units of timestep_meteo to minutes
        timestep_meteo = timestep_meteo / 60.0
        assert timestep_meteo == timestep_chem == timestep_bio


def test_chem_patch_in_namelist():
    for run_folder in run_folders:
        chem_patch_in_namelist = False
        with open(f'{run_folder}/namelist.input') as lines:
            for line in lines:
                if '! CHEM' in line:
                    chem_patch_in_namelist = True

        assert chem_patch_in_namelist
        