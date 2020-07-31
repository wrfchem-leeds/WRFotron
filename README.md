### WRFotron
Tools to automatise WRF-Chem runs with re-initialised meteorology.  

WRFotron created by Christoph Knote (christoph.knote@lmu.de).  

[User guide](https://wrfotron.readthedocs.io/en/latest/) created by Luke Conibear (l.a.conibear@leeds.ac.uk).  

Helpful additions from Helen Burns, Carly Reddington, Ben Silver, Laura Kiely, Thomas Thorp, Ailish Graham, Doug Lowe, Scott Archer-Nicholls, Edward Butt, and Lauren Fleming.  

#### Quick start
WRFotron uses pre-built executables on ARC4 from CEMAC. Everything required is loaded in `config.bash`, including Python, NCO, NCL, WPS, WRFMeteo, WRFChem, preprocessors, and ncview.  

1. Log into ARC4 and clone the WRFotron repo:  
```bash
git clone git@github.com:wrfchem-leeds/WRFotron.git
```

2. Load the availability of CEMAC modules:
```bash
. /nobackup/cemac/cemac.sh
```
    
3. Run WRFotron:  
```bash
. master.bash 2016 10 12 00 24 06
```

#### License  
This code is currently licensed under the GPLv3 License, free of charge for non-commercial use. If you intend to publish something based on WRF simulations made using the WRFotron scripts, and you think this contributed substantially to you research, please consider offering co-authorship and referencing: [![DOI](https://zenodo.org/badge/234609545.svg)](https://zenodo.org/badge/latestdoi/234609545)
