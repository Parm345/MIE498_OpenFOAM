#!/bin/bash
#SBATCH --job-name="openfoam_cube_td0001_reconstruct"      # job name

#SBATCH --ntasks=16                # number of processors
#SBATCH --nodes=1                # number of nodes
#SBATCH --mem-per-cpu=4g           # memory per cpu

#SBATCH --time=00-06:00             # walltime dd-hh-mm
#SBATCH --output=reconstruct%j.txt         # output file
#SBATCH --mail-user=email@mail.ca
#SBATCH --mail-type=ALL

module load openfoam

projectPath='/home/parmghai/links/scratch/MIE498/final_data/simulation/turbulence_model_1/initial_mesh/initial_mesh_ts0001'

reconstructPar