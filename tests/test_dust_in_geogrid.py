import os
import glob

path = os.getcwd()
run_folders = glob.glob(f'{path[:-12]}/run/base/2*')


def test_dust_in_geogrid():
    for run_folder in run_folders:
        with open(f'{run_folder}/config.bash') as lines:
            for line in lines:
                if 'WPSdir' in line:
                    wps_folder = line.split('=')[1].split('\n')[0]


        geogrid_table_file = f'{wps_folder}/geogrid/GEOGRID.TBL'
        found_dust = False
        with open(geogrid_table_file) as lines:
            for line in lines:
                if 'name = EROD' in line:
                    found_dust = True

        assert found_dust
    