**********
User Guide
**********
Tools to automatise WRF-Chem runs with re-initialised meteorology.

WRFotron created by Christoph Knote (christoph.knote@lmu.de).  

User guide created by Luke Conibear (l.a.conibear@leeds.ac.uk).  

Helpful additions from Helen Burns, Carly Reddington, Ben Silver, Laura Kiely, Thomas Thorp, Ailish Graham, Douglas Lowe, Scott Archer-Nicholls, and Edward Butt.  

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
WRFotron uses pre-built executables on ARC4 from CEMAC. Everything required is loaded in :code:`config.bash`, including Python, NCO, NCL, WPS, WRFMeteo, WRFChem, preprocessors, and ncview.  

1. Log into ARC4 and clone the WRFotron repo:  

.. code-block:: bash

  git clone https://github.com/wrfchem-leeds/WRFotron.git

2. Load the availability of CEMAC modules:

.. code-block:: bash

  . /nobackup/cemac/cemac.sh
    
3. Run WRFotron:  

.. code-block:: bash

  . master.bash 2016 10 12 00 24 06
