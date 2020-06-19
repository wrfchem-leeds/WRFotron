### WRFotron
#### Tools to automatise WRF-Chem runs with re-initialised meteorology  
- WRFotron created by Christoph Knote (christoph.knote@lmu.de).  
- [User guide](https://github.com/wrfchem-leeds/WRFotron/blob/master/WRFotron_user_guide.md) created by Luke Conibear (l.a.conibear@leeds.ac.uk)  
- Helpful additions from Helen Burns, Carly Reddington, Ben Silver, Laura Kiely, Thomas Thorp, Ailish Graham, Doug Lowe, Scott Archer-Nicholls, and Edward Butt.  

#### Versions  
- [0.0 15/10/2015](https://github.com/wrfchem-leeds/WRFotron/blob/master/WRFotron_user_guide.md#WRFotron0.0)
- [1.0 01/06/2018](https://github.com/wrfchem-leeds/WRFotron/blob/master/WRFotron_user_guide.md#WRFotron1.0)  
- [2.0 01/02/2019](https://github.com/wrfchem-leeds/WRFotron/blob/master/WRFotron_user_guide.md#WRFotron2.0)  
- 2.1 20/06/2020

#### License  
This code is currently licensed under the GPLv3 License, free of charge for non-commercial use. If you intend to publish something based on WRF simulations made using the WRFotron scripts, and you think this contributed substantially to you research, please consider offering co-authorship and referencing: [![DOI](https://zenodo.org/badge/234609545.svg)](https://zenodo.org/badge/latestdoi/234609545)

#### How to use
First, read the [user guide](https://github.com/wrfchem-leeds/WRFotron/blob/master/WRFotron_user_guide.md).
WRFotron uses pre-built executables on ARC4 from CEMAC. Everything required is loaded in `config.bash`, including Python, NCO, NCL, WPS, WRFMeteo, WRFChem, preprocessors, and ncview.  

1. Log onto ARC4 and clone a local copy of the WRFotron GitHub repo:  
```bash
ssh username@arc4.leeds.ac.uk
cd /nobackup/$USER/
git clone git@github.com:wrfchem-leeds/WRFotron.git
cd WRFotron
```

2. Load the availability of CEMAC modules:
```bash
. /nobackup/cemac/cemac.sh
```
    
3. Run WRFotron (using the test example), may first need to edit `config.bash` to change the paths to local WRFotron and project tag:  
```bash
. master.bash 2016 10 12 00 24 06
```

#### Misc.
- To always be able to view and use all the software CEMAC has built when you run `module avail`, add the following lines to `.bashrc`:   
```bash
if [ -r /nobackup/cemac/cemac.sh ] ; then
  . /nobackup/cemac/cemac.sh
fi
```

- WRFChem has been built with all compiler and MPI combinations on ARC4 listed in the directories:
```bash
/nobackup/cemac/software/build/WRFChem/
```
- The recommended compiler and MPI combination is:
```
compiler: intel
mpi: openmpi
```
- IntelMPI on ARC4 is not optimized and contains a bug. Run the following command to run smoothly with IntelMPI:  
```bash
export I_MPI_HYDRA_TOPOLIB=ipl
```
- To modify the makefile for the preprosesors if using bespoke altered preprocessors use:  
```
fix_makefile.sh
```
- To build your own versions set the environment variable `CEMAC_DIR` to your own directory within `build.sh`.
- The executables are found in these locations:
```
/nobackup/cemac/software/apps/WRFChem/
```
