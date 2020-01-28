# WRFotron CEMAC modules on ARC4

This in the adapted WRFortron code to work with pre built cemac executables on arc4.

Everything required is loaded in config.bash: this includes all python nco and ncl required as well as WRF WRFChem, Preprosesors etc.


`/nobackup/WRFChem/WRFotron2.0_WRFChem3.7.1`



Allow using cemac modules by:

`. /nobackup/cemac/cemac.sh`


From this WRFotron copy running:
```bash
 . master.bash 2014 01 12 00 24 06
```
should work with out any alteration


To always be able to view and use all the software CEMAC has built when you run module avail, add the following lines to `.bashrc`

```bash
if [ -r /nobackup/cemac/cemac.sh ] ; then
  . /nobackup/cemac/cemac.sh
fi
```

### Reccomendations

Although all WRFChems have been built the recommended compiler and mpi combination is:
 * compiler: intel
 * mpi: openmpi

### Other

`fix_makefile.sh` will modify the the makefile for the Preprosesors if using bespoke altered code

## Build locations

The build scripts and locations are found

```
```
