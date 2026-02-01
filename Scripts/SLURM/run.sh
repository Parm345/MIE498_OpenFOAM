#!/bin/bash
#SBATCH --job-name="openfoam_cube_test"      # job name

#SBATCH --ntasks=8                # number of processors
#SBATCH --nodes=1                # number of nodes
#SBATCH --mem-per-cpu=4g           # memory per cpu

#SBATCH --time=0-10:00             # walltime dd-hh-mm
#SBATCH --output=cube_test_%j.txt         # output file
#SBATCH --mail-type=FAIL

module load openfoam

projectPath='/home/parmghai/links/scratch/MIE498/first_attempt/MIE498_OpenFOAM'

cd $projectPath
decomposePar -force | tee log.decompose
mpirun -np 8 foamRun -solver incompressibleFluid -parallel
reconstructPar