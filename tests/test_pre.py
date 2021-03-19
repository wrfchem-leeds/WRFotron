import os
import glob
import subprocess
import re

path = os.getcwd()
run_folders = glob.glob(f'{path[:-12]}/run/base/2*')


def test_ungrib():
    for run_folder in run_folders:
        filename = f'{run_folder}/ungrib.log'
        assert re.findall(r'success', str(subprocess.check_output(['tail', '-1', filename])), flags=re.IGNORECASE)


def test_geogrid():
    for run_folder in run_folders:
        filename = f'{run_folder}/geogrid.log'
        assert re.findall(r'success', str(subprocess.check_output(['tail', '-1', filename])), flags=re.IGNORECASE)


def test_metgrid():
    for run_folder in run_folders:
        filename = f'{run_folder}/metgrid.log'
        assert re.findall(r'success', str(subprocess.check_output(['tail', '-1', filename])), flags=re.IGNORECASE)


def test_first_real_out():
    for run_folder in run_folders:
        filename = f'{run_folder}/first_real_out/rsl.error.0000'
        assert re.findall(r'success', str(subprocess.check_output(['tail', '-1', filename])), flags=re.IGNORECASE)


def test_anthro_emis():
    for run_folder in run_folders:
        filename = f'{run_folder}/anthro_emis.out'
        assert re.findall(r'success', str(subprocess.check_output(['tail', '-2', filename])), flags=re.IGNORECASE)


def test_fire_emis():
    for run_folder in run_folders:
        filename = f'{run_folder}/fire_emis.out'
        assert re.findall(r'success', str(subprocess.check_output(['tail', '-2', filename])), flags=re.IGNORECASE)


def test_second_real_out():
    for run_folder in run_folders:
        filename = f'{run_folder}/second_real_out/rsl.error.0000'
        assert re.findall(r'success', str(subprocess.check_output(['tail', '-1', filename])), flags=re.IGNORECASE)


def test_mozbc():
    for run_folder in run_folders:
        filename = f'{run_folder}/mozbc_bc.log'
        assert re.findall(r'success', str(subprocess.check_output(['tail', '-1', filename])), flags=re.IGNORECASE)
    