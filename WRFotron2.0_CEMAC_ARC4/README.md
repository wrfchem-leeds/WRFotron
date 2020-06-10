# WRFotron CEMAC modules on ARC4

This in the adapted WRFortron code to work with pre built cemac executables on arc4.

Everything required is loaded in config.bash: this includes all python nco and ncl required as well as WRF WRFChem, Preprosesors etc. ncview is also available via cemac modules


## How to use

1. Copy this code to your no back up space.

`cp -rp /nobackup/WRFChem/WRFotron2.0_WRFChem3.7.1 /nobackup/$USER/`


2. CEMAC modules are **required** to use them run:

`. /nobackup/cemac/cemac.sh`


3. Run the test case

```bash
cd /nobackup/$USER/WRFotron2.0_WRFChem3.7.1
. master.bash 2014 01 12 00 24 06
```
should work with out any alteration

## Optional

To always be able to view and use all the software CEMAC has built when you run module avail, add the following lines to `.bashrc`

```bash
if [ -r /nobackup/cemac/cemac.sh ] ; then
  . /nobackup/cemac/cemac.sh
fi
```

### Recommendations

WRFChem has been built with all compiler and mpi combinations on arc4 listed in the directories:

```bash
/nobackup/cemac/software/build/WRFChem/3.7.1/1
/nobackup/cemac/software/build/WRFChem/4.0.3/1
```

The recommended compiler and mpi combination is:
 * compiler: intel
 * mpi: openmpi

### Note on intelmpi

intelmpi on arc in not optimized and contains a bug...

```bash
export I_MPI_HYDRA_TOPOLIB=ipl
```

is required inorder to run smoothly with intelmpi


### Other

`fix_makefile.sh` will modify the the makefile for the preprosesors if using bespoke altered preprocessors.

## Data

## Build locations

The build scripts and locations are found

```
/nobackup/cemac/software/build/WRFChem/3.7.1/1
/nobackup/cemac/software/build/WRFChem/4.0.3/1
```

`build.sh` can be used to build your own versions by setting the environment variable CEMAC_DIR to your own directory

the executables are found in these locations:

```
/nobackup/cemac/software/apps/WRFChem/3.7.1/1
/nobackup/cemac/software/apps/WRFChem/4.0.3/1
```
