# WRFotron

WRFotron automatises WRFChem simulations with reinitialised meteorology.

## Quick Start

WRFotron loads pre-built CEMAC modules for WRFChem, preprocessors, Python, NCO, NCL, and ncview. 

1. Clone WRFotron:
    ```bash
    git clone https://github.com/wrfchem-leeds/WRFotron.git
    ```
    ```{note}
    You will need to do this on your HPC (e.g. ARC4) and then check within `config.bash` that `chainDir` is set correctly.
    For users that require their own executables or that are from outside of the University of Leeds, you can manually compile them using the instructions [here](compilation.html#manual-alternative).
    ```
2. Make the CEMAC modules available:
    ```bash
    . /nobackup/cemac/cemac.sh
    ```
    ```{note}
    If have other modules loaded then unload them (`module purge`), and similarly deactivate conda (`conda deactivate`), as both of these can cause conflicts.
    ```
3. Submit a simulation:  
    ```bash
    . master.bash 2015 10 12 00 24 06
    ```  
