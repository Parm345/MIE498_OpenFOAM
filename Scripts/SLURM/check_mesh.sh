#!/bin/bash
#SBATCH --job-name="mesh_check"      # job name

#SBATCH --ntasks=16                # number of processors
#SBATCH --nodes=1                # number of nodes
#SBATCH --mem-per-cpu=4g           # memory per cpu

#SBATCH --time=0-01:00             # walltime dd-hh-mm
#SBATCH --output=mesh_check_%j.txt         # output file
#SBATCH --mail-type=FAIL

module load openfoam

projectPath='/home/parmghai/links/scratch/MIE498/first_attempt/mesh_2_imperfect'

decomposePar -force | tee log.decompose
mpirun -np 16 checkMesh -parallel