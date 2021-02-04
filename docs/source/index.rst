**********
User Guide
**********
Tools to automatise WRF-Chem runs with re-initialised meteorology.

WRFotron created by Christoph Knote (christoph.knote@lmu.de).  

User guide created by Luke Conibear (l.a.conibear@leeds.ac.uk).  

Helpful additions from Helen Burns, Carly Reddington, Ben Silver, Laura Kiely, Thomas Thorp, Ailish Graham, Douglas Lowe, Scott Archer-Nicholls, Edward Butt, and Lauren Fleming.  

Contents
========

.. toctree::
   :maxdepth: 1

   background
   before_you_start
   compilation
   auto_simulation
   manual_simulation
   faqs
   versions
   license

Quick start
===========
WRFotron uses pre-built executables on ARC4 from CEMAC (for University of Leeds users). Everything required is loaded in :code:`config.bash`, including Python, NCO, NCL, WPS, WRFMeteo, WRFChem, preprocessors, and ncview.  

1. Log into ARC4, clone the WRFotron repo, and edit the :code:`chainDir` path within :code:`config.bash` if it is not :code:`/nobackup/${USER}/WRFotron`:  

.. code-block:: bash

  git clone https://github.com/wrfchem-leeds/WRFotron.git

2. Load the availability of CEMAC modules. If have other modules loaded then unload them (:code:`module purge`), and similarly deactivate conda (:code:`conda deactivate`), as both of these can cause conflits:

.. code-block:: bash

  . /nobackup/cemac/cemac.sh
    
3. From within the WRFotron folder run :code:`master.bash`:  

.. code-block:: bash

  . master.bash 2016 10 12 00 24 06

For users that require their own executables or that are from outside of the University of Leeds, you can manually compile them using the instructions `here <https://wrfotron.readthedocs.io/en/latest/compilation.html#manual-alternative>`_.  
