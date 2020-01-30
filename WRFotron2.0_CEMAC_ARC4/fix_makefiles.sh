#!/bin/bash

module purge
module load licenses sge intel openmpi netcdf hdf5
NETCDF=$(nc-config --prefix)
NETCDF_DIR=$NETCDF
export NETCDF NETCDF_DIR

function fix_MakeFile() {
  # File possible wrong entries and swap!
  sed -i "s|LIBS   = -L\$(NETCDF)/lib -lnetcdf -lnetcdff|LIBS   = -lnetcdf -lnetcdff|g" Makefile
  sed -i "s|INCLUDE_MODULES = -I\$(NETCDF)/include|INCLUDE_MODULES = |g" Makefile
  sed -i "s|INCLUDE_MODULES = -I\$(NETCDF_DIR)/include|INCLUDE_MODULES = |g" Makefile
  sed -i "s|LIBS   = -L\$(NETCDF)/lib -lnetcdf -lnetcdff|LIBS   = -lnetcdf -lnetcdff|g" Makefile
  sed -i "s|LIBS   = -L\$(NETCDF_DIR)/lib \$(AR_LIBS)|LIBS   = -lnetcdf -lnetcdff|g" Makefile
  sed -i "s|LIBS   = -L\$(NETCDF_DIR)/lib \$(AR_FILES)|LIBS   = -lnetcdf -lnetcdff|g" Makefile
}
