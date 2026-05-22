# MIE498 OpenFOAM

This undergraduate thesis simulates the turbulence around a cube. The final results of the simulation can be found on the [UofT Dataverse](https://borealisdata.ca/dataverse/mie498_urans_cube).

## Mesh
Use ANSYS meshing to generate meshes. Ideally on a HPC for high fidelity meshes. Export the mesh as a `.msh` file in the ASCII format.

You can find the geometry to generate meshes off of in `Geometry_Model`. `3D_v0` is the domain of the flow around the cube with no rotation. `cube` is imported into paraFoam to help better visualize the flow.

## OpenFOAM Simulation on HPC 
- Clone this repo onto the HPC (in the scratch folder if on DRA)
- Select the desired turbulence model in `constant/momentumTransport`
- Move desired mesh into main directory 
- Edit `Scripts/SLURM/convert_mesh_job.sh` to use correct mesh and other running paramters and then run via SLURM to generate mesh.
- Use `Scripts/Utils/clonecase.sh` to generate different timestep cases for your simulation
- Use `Scripts/SLURM/run.sh` to run a case

## Post Processing
- Download the data locally using `Scripts/Utils/download_postprocessing.sh`
- Run `plot_postprocessing.py` to generate graphical data of the simulations. The script will find data by recursively searching through folders so you can put the starting path at the highest level of data storage directory. 
- Run `postprocessing.py` on the data collected to collect data in spreadsheets and to summarize key findings. 
- To perform grid indepence calculations. Place the results of different mesh qualities in a folder and create a `gci_script_input.xlsx` following the example in `Scripts/Utils/Examples/gci_script_input.xlsx`. Then run `gci_v3.py` and make sure to update the initial arguments to match your file system.
