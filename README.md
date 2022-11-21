### WRFotron
![GitHub release (latest by date)](https://img.shields.io/github/v/release/wrfchem-leeds/WRFotron)
![GitHub](https://img.shields.io/github/license/wrfchem-leeds/WRFotron?label=License)
[![DOI](https://zenodo.org/badge/234609545.svg)](https://zenodo.org/badge/latestdoi/234609545)  

![logo](https://user-images.githubusercontent.com/19871268/122675619-23ddae00-d1d2-11eb-81ab-f8ca50c7746f.png)

Tools to automatise WRF-Chem runs with re-initialised meteorology.  

WRFotron created by Christoph Knote (christoph.knote@med.uni-augsburg.de).  

[User guide](https://wrfchem-leeds.github.io/WRFotron/) created by Luke Conibear (l.a.conibear@leeds.ac.uk).  

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

#### Documentation

1. Clone the repository and create a branch to work on the docs:

```bash
git clone https://github.com/wrfchem-leeds/WRFotron.git
cd WRFotron
git checkout -b update-docs
```

2. Edit the markdown files e.g., `docs/faqs.md`. 
3. Create a conda environment with jupyter-book installed e.g.:

```bash
conda env create -f environment.yml
conda activate wrfotron
```

4. Build the docs locally using:

```bash
jupyter-book build docs
```

5. View the docs locally by opening `docs/_build/html/index.html` in a browser.
6. If you're happy with the changes, open a [pull request](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request) to merge your branch. Tag `lukeconibear` as a reviewer.  
