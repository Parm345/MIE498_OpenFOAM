#!/bin/bash


projectPath='/home/parmghai/links/scratch/MIE498/final_data/simulation/sst_kw/coarse_mesh/'
cd $projectPath

for dt in 0.001 0.0001 0.00001 0.0005 0.00005; do
    bash ts005/Scripts/Utils/clonecase.sh ts005 $dt
done