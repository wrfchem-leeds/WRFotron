### WRFotron
![GitHub release (latest by date)](https://img.shields.io/github/v/release/wrfchem-leeds/WRFotron)
![GitHub](https://img.shields.io/github/license/wrfchem-leeds/WRFotron?label=License)
[![DOI](https://zenodo.org/badge/234609545.svg)](https://zenodo.org/badge/latestdoi/234609545)  

Tools to automatise WRF-Chem runs with re-initialised meteorology.  

WRFotron created by Christoph Knote (christoph.knote@med.uni-augsburg.de).  

[User guide](https://wrfotron.readthedocs.io/en/latest/) created by Luke Conibear (l.a.conibear@leeds.ac.uk).  

Helpful additions from Helen Burns, Carly Reddington, Ben Silver, Laura Kiely, Thomas Thorp, Ailish Graham, Doug Lowe, Scott Archer-Nicholls, Edward Butt, and Lauren Fleming.  

#### Quick start
WRFotron uses pre-built executables on ARC4 from CEMAC (for University of Leeds users). Everything required is loaded in `config.bash`, including Python, NCO, NCL, WPS, WRFMeteo, WRFChem, preprocessors, and ncview.  

1. Log into ARC4, clone the WRFotron repo, and edit the `chainDir` path within `config.bash` if it is not `/nobackup/${USER}/WRFotron`:  
```bash
git clone https://github.com/wrfchem-leeds/WRFotron.git
```

2. Load the availability of CEMAC modules. If have other modules loaded then unload them (`module purge`), and similarly deactivate conda (`conda deactivate`), as both of these can cause conflits:
```bash
. /nobackup/cemac/cemac.sh
```
    
3. From within the WRFotron folder run `master.bash`:  
```bash
. master.bash 2015 10 12 00 24 06
```

For users that require their own executables or that are from outside of the University of Leeds, you can manually compile them using the instructions [here](https://wrfotron.readthedocs.io/en/latest/compilation.html#manual-alternative).
