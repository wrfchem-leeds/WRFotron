#!/bin/bash
# ------------------------------------------------------------------------------
# WRFOTRON
# ------------------------------------------------------------------------------

ncksBin=$(which ncks)
ncattedBin=$(which ncatted)
nccopyBin=$(which nccopy)
nclBin=$(which ncl)

function msg {
  echo ""
  echo "---"
  echo $1
  echo "---"
  echo ""
}
