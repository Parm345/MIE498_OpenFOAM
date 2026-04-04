#!/bin/bash
#SBATCH --job-name="openfoam_cube_med_ts0005"      # job name

#SBATCH --ntasks=16                # number of processors
#SBATCH --nodes=1                # number of nodes
#SBATCH --mem-per-cpu=4g           # memory per cpu

#SBATCH --time=1-00:00             # walltime dd-hh-mm
#SBATCH --output=cube_test_%j.txt         # output file
#SBATCH --mail-user=email@mail.ca
#SBATCH --mail-type=ALL

# Record the start time
start_time=$(date +%s)


module load openfoam

projectPath='/home/parmghai/links/scratch/MIE498/final_data/simulation/turbulence_model_1/medium_mesh/ts0005'

cd $projectPath
decomposePar -force | tee log.decompose
mpirun -np 16 foamRun -solver incompressibleFluid -parallel
reconstructPar
rm -r processor*

# Record the end time
end_time=$(date +%s)

# Calculate the runtime in seconds
runtime=$((end_time - start_time))

# Write the runtime to a file
echo "Job Runtime: $runtime seconds" >> job_runtime.txt
