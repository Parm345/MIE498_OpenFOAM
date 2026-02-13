#!/bin/bash
#SBATCH --job-name="convert_mesh"      # job name

#SBATCH --ntasks=64                # number of processors
#SBATCH --nodes=1                # number of nodes
#SBATCH --mem-per-cpu=4g           # memory per cpu

#SBATCH --time=0-00:05             # walltime dd-hh-mm
#SBATCH --output=job%j.txt         # output file
#SBATCH --mail-type=FAIL

module load openfoam

mesh_path='/home/parmghai/links/scratch/MIE498/first_attempt/mesh_2_imperfect/mesh3_imperfect_mesh.msh'

fluent3DMeshToFoam $mesh_path
